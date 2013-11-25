package Anorman::Data::Map;

# A pure perl hash table implementation using 
# extendible open addressing with double hashing
# Is more memory efficient than chaining hashes 
# at a reasonable cost in performance
#
# This module was mostly written as an excersize
# in learning about hash tables, but turned out
# to be pretty useful too
#
# Anders Norman, July 2013, lordnorman@gmail.com


use strict;

use Anorman::Data::Map::PrimeFinder;
use Anorman::Common qw(trace_error);
use List::Util qw(min max);

# hash table states
use constant {
	FREE => undef,
	FULL => 1,
     REMOVED => 2
};

# default
my $DEFAULT_CAPACITY        = 227;
my $DEFAULT_MIN_LOAD_FACTOR = 0.2;
my $DEFAULT_MAX_LOAD_FACTOR = 0.5;

sub new {
	my $class = shift;

	# set default values if none were provided by the user
	my $init_capacity   = defined $_[0] ? $_[0] : $DEFAULT_CAPACITY;
	my $min_load_factor = defined $_[1] ? $_[1] : $DEFAULT_MIN_LOAD_FACTOR;
	my $max_load_factor = defined $_[2] ? $_[2] : $DEFAULT_MAX_LOAD_FACTOR;
	

	# basic object hash
	my $self  = bless ( { '_table' => [],
                             '_values' => [],
                             '_state'  => []
                            }, $class );

	$self->_setup( $init_capacity, $min_load_factor, $max_load_factor );
	
	return $self;
}

sub clear {
	# marks all slots as FREE, but doesn't actually
	# alter the values themselves, just marks them
	# so they can be overwritten
	my $self = shift;
	my $stat = $self->{'_state'};

	foreach my $i(0..$#{ $stat }) {
		$stat->[ $i ] = FREE;
	}
	
}

sub is_empty {
	return $_[0]->{'_distinct'} == 0;
}

sub size {
	# size of the hash in terms of the data it contains
	# (not the actual capacity, which is substantially 
	# larger)
	return $_[0]->{'_distinct'};
}

sub put {
	my $self = shift;

	# fetch index of a sutable slot 
	my $i    = $self->_index_of_insertion( $_[0] );

	if ($i < 0) {
		$i = -$i - 1;
		$self->{'_values'}->[ $i ] = $_[ 1 ];
		return undef;
	}

	# check if its time to grow the hash
	if ($self->{'_distinct'} > $self->{'_high_watermark'}) {
		my $new_capacity = $self->_choose_grow_capacity( $self->{'_distinct'} + 1, 
								 $self->{'_min_load_factor'},
								 $self->{'_max_load_factor'} );
		$self->_rehash( $new_capacity );
		return $self->put( $_[0], $_[1] );	
	}

	$self->{'_table'}->[ $i ]  = $_[0];
	$self->{'_values'}->[ $i ] = $_[1];
	$self->{'_free_entries'}-- if ($self->{'_state'}->[ $i ] == FREE);
	$self->{'_state'}->[ $i ] = FULL;
	$self->{'_distinct'}++;

	if ($self->{'_free_entries'} < 1) {
		my $new_capacity = $self->_choose_grow_capacity( $self->{'_distinct'} + 1, 
								 $self->{'_min_load_factor'},
								 $self->{'_max_load_factor'} );
		
		$self->_error("Time to grow! I want to be this big: $new_capacity" );
	}

	return 1;
}

sub get {
	my $self = shift;
	my $i    = $self->_index_of_key( $_[0] );
	return undef if ($i < 0);
	return $self->{'_values'}->[ $i ];	
}

sub key_exists {
	my $self = shift;
	return $self->_index_of_key( $_[0] ) >= 0;
}

sub remove {
	my $self = shift;
	my $i    = $self->_index_of_key( $_[0] );
	return undef if ($i < 0);

	$self->{'_state'}->[ $i ] = REMOVED;
	$self->{'_distinct'}--;

	if ($self->{'_distinct'} < $self->{'_low_watermark'}) {
		my $new_capacity = $self->_choose_shrink_capacity( $self->{'_distinct'},
								   $self->{'_min_load_factor'},
								   $self->{'_max_load_factor'} );

		$self->_rehash( $new_capacity )
	}

	return 1;
}

sub keys {
	my $self = shift;

	my $new_array = [];
	my $tab       = $self->{'_table'};
	my $stat      = $self->{'_state'};
	
	my $i = @{ $tab };
	
	$new_array->[ $self->{'_distinct'} - 1 ] = undef;	

	my $j = 0;

	while ( $i-- > 0 ) {
		$new_array->[ $j++ ] = $tab->[ $i ] if ($stat->[ $i ] == FULL);
	}
	return $new_array;
}

sub each {
	# TODO: an iterator for traversing key/value-pairs in the hash
}

sub _rehash {
	# alter the size of the hash table and re-insert all hash keys
	my $self         = shift;

	my $old_capacity = @{ $self->{'_table'} };
	my $old_table    = $self->{'_table'};
	my $old_state    = $self->{'_state'};
	my $old_values   = $self->{'_values'};

	my $new_table  = [];
	my $new_values = [];
	my $new_state  = [];

	my $new_last = $_[0] - 1;

	$new_table->[ $new_last ]  = undef;
	$new_values->[ $new_last ] = undef;
	$new_state->[ $new_last ]  = undef;

	$self->{'_low_watermark'} = $self->_choose_low_watermark( $_[0], $self->{'_min_load_factor'} );
	$self->{'_high_watermark'} = $self->_choose_high_watermark( $_[0], $self->{'_max_load_factor'} );

	$self->{'_table'} = $new_table;
	$self->{'_values'} = $new_values;
	$self->{'_state'} = $new_state;
	$self->{'_free_entries'} = $_[0] - $self->{'_distinct'};

	my $i = $old_capacity;

	while ($i-- > 0) {
		if ($old_state->[ $i ] == FULL) {
			my $element = $old_table->[ $i ];
			my $index   = $self->_index_of_insertion( $element );

			$new_table->[ $index ]  = $element;
			$new_values->[ $index ] = $old_values->[ $i ];
			$new_state->[ $index ]  = FULL;
		}
	}

	undef $old_table;
	undef $old_values;
	undef $old_state;
}

sub _setup {
	my $self = shift;
	my ($init_capacity, $min_load_factor, $max_load_factor) = @_;

	$self->_error("Illegal min_load_factor: $min_load_factor") 
		if ($min_load_factor <= 0 || $max_load_factor >= 1);
	$self->_error("Illegal max_load_factor: $max_load_factor")
		if ($max_load_factor <=0 || $max_load_factor >= 1);
	$self->_error("min_load_factor ($min_load_factor) must be smaller than max_load_factor( $max_load_factor")
		if ($min_load_factor >= $max_load_factor);

	my $capacity = Anorman::Data::Map::PrimeFinder::next_prime( $init_capacity );

	$capacity = 1 unless $capacity;

	$self->{'_table'}->[ $capacity - 1 ]  = undef;
	$self->{'_values'}->[ $capacity - 1 ] = undef;
	$self->{'_state'}->[ $capacity - 1 ]  = undef;
	
	$self->{'_min_load_factor'} = $min_load_factor;
	$self->{'_max_load_factor'} = $max_load_factor;

	$self->{'_distinct'}        = 0;
	$self->{'_free_entries'}    = $capacity;
	$self->{'_low_watermark'}   = 0;
	$self->{'_high_watermark'}  = $self->_choose_high_watermark( $capacity, $self->{'_max_load_factor'} );
}

sub _choose_low_watermark {
	my $self = shift;
	return int( $_[0] * $_[1] );
}

sub _choose_high_watermark {
	my $self = shift;
	return min( $_[0] - 2, int( $_[0] * $_[1] ) );
}

sub _choose_shrink_capacity {
	my $self = shift;
	my $new_size = max( $_[0] + 1, int( 4 * $_[0] / ( $_[1] + 3 * $_[2] ) ) );

	return Anorman::Data::Map::PrimeFinder::next_prime( $new_size );
}

sub _choose_grow_capacity {
	my $self     = shift;
	my $new_size = max( $_[0] + 1,  int ( (4 * $_[0]) / (3 * $_[1] + $_[2]) ));

	return Anorman::Data::Map::PrimeFinder::next_prime( $new_size );
}

# TODO: consider an inline C of these two functions for speed
sub _index_of_key {
	my $self   = shift;
	my $tab    = $self->{'_table'};
	my $stat   = $self->{'_state'};
	my $length = @{ $tab };

	my $hash   = $_[0] & 0x7FFFFFFF;
	my $i      = $hash % $length;
	my $decr   = $hash % ($length - 2);

	$decr = 1 unless $decr;
	
	while( $stat->[ $i ] != FREE && ($stat->[ $i ] == REMOVED || $tab->[ $i ] != $_[0])) {
		$i -= $decr;
		
		$i += $length if ($i < 0);
	}

	return -1 if ($stat->[ $i ] == FREE);	
	return $i;

}

sub _index_of_insertion {
	my $self   = shift;
	my $tab    = $self->{'_table'};
	my $stat   = $self->{'_state'};
	my $length = @{ $tab };

	# double hash function
	my $hash   = $_[0] & 0x7FFFFFFF;
	my $i      = $hash % $length;
	my $decr   = $hash % ($length - 2);

	$decr = 1 unless $decr;
	
	# traverse hash until an empty slot or the key is found
	while ($stat->[ $i ] == FULL && $tab->[ $i ] != $_[0]) {
		$i -= $decr;
		$i += $length if ($i < 0);
	}

	if ($stat->[ $i ] == REMOVED) {
		my $j = $i;

		while( $stat->[ $i ] != FREE && ($stat->[ $i ] == REMOVED || $tab->[ $i ] != $_[0])) {
			$i -= $decr;
			$i += $length if ($i < 0);
		}
		$i = $j if ($stat->[ $i ] == FREE);
	}

	if ($stat->[ $i ] == FULL) {
		return -$i - 1;
	}	
	return $i;
}

sub _error {
	shift;
	trace_error(@_);
}

1;
