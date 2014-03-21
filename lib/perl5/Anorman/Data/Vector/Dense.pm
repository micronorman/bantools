package Anorman::Data::Vector::Dense;

use strict;

use parent qw(Anorman::Data::Vector::Abstract Anorman::Data::Vector);

use Anorman::Data::LinAlg::Property qw( :vector );
use Anorman::Common qw(sniff_scalar trace_error);

my %ASSIGN_DISPATCH = (
	'NUMBER'      => \&_assign_DenseVector_from_NUMBER,
	'ARRAY'       => \&_assign_DenseVector_from_ARRAY,
	'OBJECT'      => \&_assign_DenseVector_from_OBJECT,
	'OBJECT+CODE' => \&_assign_DenseVector_from_OBJECT_and_CODE,	
	'CODE'        => \&_assign_DenseVector_from_CODE
);

sub new {
	my $that  = shift;
	my $class = ref $that || $that;
	my $self  = $class->SUPER::new();

	if (@_ != 1 && @_ != 4) {
		trace_error("Wrong number of arguments");
	}

	my $self = $class->SUPER::new();

	if (ref $_[0] eq 'ARRAY') {
		$self->_new_from_array(@_);
	} else {
		$self->_new_from_dims(@_);
	}

	return $self;
}

sub _new_from_array {
	my $self = shift;
	my $size = @{ $_[0] };

	$self->_new_from_dims( $size );
	$self->_assign_DenseVector_from_ARRAY( $_[0] );

	return $self;
}

sub _new_from_dims {
	my $self = shift;

	my ($size, $elements, $zero, $stride) = @_;

	if (@_ == 1) {
		$self->_setup( $size );
		$self->{'_ELEMS'} = [ (0) x $_[0] ];
	} else {
		$self->_setup( $size, $zero, $stride );
		
		trace_error("Invalid data elements. Must be an ARRAY reference")
			unless ref($elements) eq 'ARRAY';

		$self->{'_ELEMS'} = $elements;
		$self->{'_VIEW'}  = 1;
	}

	return $self;
}

sub assign {
	my $self = shift;
	my $type = sniff_scalar($_[0]);

	# determine type of data passed
	if (@_ == 2) {
		my $arg2_type = sniff_scalar( $_[1] );
		unless ($type eq 'OBJECT' && $arg2_type eq 'CODE') {
			trace_error("Invalid arguments. Argument 2 is not a CODE block ($type,$arg2_type)");
		}
		$type = 'OBJECT+CODE';
	}

	# execute from dispatch table
	$ASSIGN_DISPATCH{ $type }->( $self, @_ );

	return $self;
}


# quick get/set routines
sub get_quick { $_[0]->{'_ELEMS'}->[ $_[0]->{'zero'} + $_[1] * $_[0]->{'stride'} ] };
sub set_quick { $_[0]->{'_ELEMS'}->[ $_[0]->{'zero'} + $_[1] * $_[0]->{'stride'} ] = $_[2] };

sub _index    { $_[0]->{'zero'} + $_[1] * $_[0]->{'stride'} };

sub like {
	my $self  = shift;
	return defined $_[0] ? $self->new( $_[0] ) : $self->new( $self->size );
}

sub dot_product {
	my ($self,$other, $from, $length) = @_;

	check_vector($other);

	unless ($other->isa('Anorman::Data::Vector::Dense')) {
		return $self->SUPER::dot_product($other, $from, $length);
	}

	$from = 0 if !defined $from;
	$length = $self->{'size'} if !defined $length;

	my $tail = $from + $length;
	return 0 if ($from < 0 || $length <= 0);

	my $size = $self->{'size'};

	$tail = $size if ($size < $tail);
	$tail = $other->{'size'} if ($other->{'size'} < $tail);

	my $min = $tail - $from;
	
	my $i = $self->_index($from);
	my $j = $other->_index($from);

	my $a_str = $self->{'stride'};
	my $b_str = $other->{'stride'};

	my $a_elems = $self->{'_ELEMS'};
	my $b_elems = $other->{'_ELEMS'};

	my $sum = 0;

	# unrolled loop optimization
	$i -= $a_str;
	$j -= $b_str;

	my $k = $min / 4;
	while ( --$k >= 0) {
		$sum += $a_elems->[ $i += $a_str ] * $b_elems->[ $j += $b_str ];
                $sum += $a_elems->[ $i += $a_str ] * $b_elems->[ $j += $b_str ];
                $sum += $a_elems->[ $i += $a_str ] * $b_elems->[ $j += $b_str ];
                $sum += $a_elems->[ $i += $a_str ] * $b_elems->[ $j += $b_str ];
	}

	$k = $min % 4;
	while ( --$k >= 0) {
		$sum +=  $a_elems->[ $i += $a_str ] * $b_elems->[ $j += $b_str ]; 
	}	

	return $sum;
}


# Optimized operations

sub swap {
	my ($self, $other) = @_;
	
	check_vector( $other );
	return if ($self == $other);
	$self->_check_size( $other );

	$self->SUPER::swap( $other ) unless $other->isa('Anorman::Data::Vector::Dense');

	# optimized element swapping
	my $A_elems =  $self->{'_ELEMS'};
	my $B_elems = $other->{'_ELEMS'};
	my $A_str   =  $self->{'stride'};
	my $B_str   = $other->{'stride'};
		
	my $i = $self->_index( 0 );
	my $j = $other->_index( 0 );

	my $k = $self->size;

	while (--$k >= 0) {
		($A_elems->[ $i ], $B_elems->[ $j ]) = ( $B_elems->[ $j ], $A_elems->[ $i ]);
		$i += $A_str;
		$j += $B_str;
	}

	1;
}

sub sum {
	my $self = shift;
	
	my $sum = 0;
	
	my $s = $self->{'stride'};
	my $i = $self->_index(0);

	my $elems = $self->{'_ELEMS'};
	my $k = $self->size;
	while ( --$k >= 0 ) {
		$sum += $elems->[ $i ];
		$i += $s;
	}
	return $sum;
}


# Assignment functions

sub _assign_DenseVector_from_ARRAY {
	my ($self,$V) = @_;

	if ($self->_is_no_view) {
		trace_error("Cannot assign values to vector object. Must have " . $self->{'size'} . " elements but has " . @{ $V })
			if (@{ $V } != $self->{'size'});
		# direct array copy
		@{ $self->{'_ELEMS'} } = @{ $V };
	} else {
		$self->SUPER::_assign_Vector_from_ARRAY( $V );		
	}

	1;
}

sub _assign_DenseVector_from_OBJECT {
	my ($self,$other) = @_;

	if (ref $other ne 'Anorman::Data::Vector::Dense') {
		return $self->SUPER::_assign_Vector_from_OBJECT( $other );	
	}
	
	return 1 if ($self == $other);

	$self->_check_size( $other );

	# optimized element copying
	if ($self->_is_no_view && $other->_is_no_view) {
		@{ $self->{'_ELEMS'} } = @{ $other->{'_ELEMS'} };	
	}

	my $A_elems =  $self->{'_ELEMS'};
	my $B_elems = $other->{'_ELEMS'};
	my $A_str   =  $self->{'stride'};
	my $B_str   = $other->{'stride'};
		
	my $i = $self->_index( 0 );
	my $j = $other->_index( 0 );

	my $k = $self->size;

	while (--$k >= 0) {
		$A_elems->[ $i ] = $B_elems->[ $j ];
		$i += $A_str;
		$j += $B_str;
	}

	1;
}

sub _assign_DenseVector_from_OBJECT_and_CODE {
	my ($self, $other, $CODE) = @_;
	
	if (ref ($other) ne 'Anorman::Data::Vector::Dense') {
		return $self->SUPER::_assign_Vector_from_OBJECT_and_CODE( $other, $CODE );
	}

	$self->_check_size( $other );

	my $A_elems  =  $self->{'_ELEMS'};
	my $B_elems  = $other->{'_ELEMS'};
	my $A_stride =  $self->{'stride'};
	my $B_stride = $other->{'stride'};

	my $i   =  $self->_index(0);
	my $j   = $other->_index(0);
	
	my $k = $self->{'size'};
	while ( --$k >= 0) {
		$A_elems->[ $i ] = $CODE->( $A_elems->[ $i ], $B_elems->[ $j ] );
		$i += $A_stride;
		$j += $B_stride;
	}

	1;
}

sub _assign_DenseVector_from_NUMBER {
	my ($self, $value) = @_;

	my $elems  = $self->{'_ELEMS'};
	my $i      = $self->_index(0);
	my $stride = $self->{'stride'};

	my $k = $self->{'size'};

	while ( --$k >= 0) {
		$elems->[ $i ] = $value;
		$i += $stride;
	}

	1;
}

sub _assign_DenseVector_from_CODE {
	my ($self, $CODE) = @_;

	my $elems  = $self->{'_ELEMS'};
	my $i      = $self->_index(0);
	my $stride = $self->{'stride'};

	my $k = $self->{'size'};

	while ( --$k >= 0 ) {
		$elems->[ $i ] = $CODE->( $elems->[ $i ] );
		$i += $stride;
	}

	1;
}


sub _have_shared_cells_raw {
	my ($self, $other) = @_;

	if ($other->isa('Anorman::Data::Vector::Dense') or $other->isa('Anorman::Data::Vector::SelectedDense')) {
		return ($self->{'_ELEMS'} == $other->{'_ELEMS'})
	}

	return undef;	
}

# Dumper the internal hash. Good for debugging
sub _dump {
	my $elems = defined $_[0]->{'_ELEMS'} ? $_[0]->{'_ELEMS'} : 'NULL';
	my ($type)  = ref ($_[0]) =~ /\:\:(\w+)$/;
	printf STDERR ("%s Vector dump: HASH(0x%p)\n", $type, $_[0]);
	printf STDERR ("\tsize\t\t: %lu\n",    $_[0]->{'size'}   );
    	printf STDERR ("\tzeo\t\t: %lu\n",     $_[0]->{'zero'}   );
    	printf STDERR ("\trstride\t\t: %lu\n", $_[0]->{'stride'} );
	printf STDERR ("\telements\t: %s\n",   $elems            );
    	printf STDERR ("\tview\t\t: %i\n\n",   $_[0]->{'_VIEW'}  );

}

1;

