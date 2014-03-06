package Anorman::Math::Subset;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data;
use Anorman::Data::LinAlg::Property qw ( :matrix );


sub new {
	my $that = shift;
	my $class = ref $that || $that;

	my ($matrix, $keys, $percentage) = @_;

	check_matrix($matrix);

	my $self = {
		'data'       => $matrix->copy,
		'norm_data'  => $matrix->copy,
		'percentage' => $percentage,
		'keys'       => $keys
	};

	$self->{'norm_data'}->normalize;

	return bless( $self, $class );
}

sub percentage {
	my $self = shift;
	$self->{'percentage'} = $_[0];
}

1;

package Anorman::Math::Subset::Random;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data::List;
use Anorman::Data::LinAlg::Property qw( :matrix );
use POSIX qw(floor);

use parent -norequire, 'Anorman::Math::Subset';

sub get_subset {
	my $self = shift;
	my $data = $self->{'data'};
	my $keys = $self->{'keys'};

	warn "Generating subset...\n" if $VERBOSE;

	my $subset = is_packed($data) ? Anorman::Data->packed_matrix($data->rows, $data->columns) : Anorman::Data->matrix($data->rows,$data->columns);

	my $count    = 0;
	my $new_keys = Anorman::Data::List->new;
	while ( $new_keys->size < floor((($keys->size / 100) * $self->{'percentage'}) + 0.5) ) {
		my $random = int rand( $keys->size - 1 );

		unless ($new_keys->contains($keys->get($random))) {
			$new_keys->add($keys->get($random));
			$subset->view_row($count)->assign($data->view_row($random));
			$count++;
		}
	}

	return $subset->view_part(0,0,$count, $data->columns), $new_keys;
}

1;

package Anorman::Math::Subset::LSH;

use Anorman::Common;
use Anorman::Data::List;
use Anorman::Data;
use Anorman::Data::LinAlg::Property qw( :matrix );
use List::Util qw(min);
use POSIX qw(floor);

use parent -norequire,'Anorman::Math::Subset';

sub new {
	my $that = shift;
	my $class = ref $that || $that;

	my $self = $class->SUPER::new(@_);

	$self->{'max_mapping'}   = 10;
	$self->{'hashs'}         = 1;
	$self->{'bits_for_hash'} = min( $self->{'data'}->columns * $self->{'max_mapping'}, 63);

	return $self;
}

sub init {
	my $self = shift;
	
	if (!defined $self->{'randoms'}) {
		warn "Generating random subspaces...\n" if $VERBOSE;
		my $randoms = Anorman::Data::List->new;

		while ( $randoms->size < ($self->{'hashs'} * $self->{'bits_for_hash'})) {
			my $rand = int rand($self->{'hashs'} * $self->{'bits_for_hash'});
			$randoms->add($rand);
		}

		$self->{'randoms'} = $randoms;	
	}

	$self->{'maps'} = [];
	my $i = -1;
	while ( ++$i < $self->{'hashs'} ) {
		push @{ $self->{'maps'} }, {};
	}
	
	my $unary_vector = [];

	$i = -1;
	while ( ++$i < $self->{'data'}->rows ) {
		my $j = -1;
		while ( ++$j < $self->{'data'}->columns ) {
			$self->neuron2unary( $unary_vector, $i, $j );
		}

		$j = -1;
		while ( ++$j < $self->{'hashs'} ) {
			my $hash = $self->unary2hash( $unary_vector, $j);
			$self->hash_neuron( $self->{'maps'}->[ $j ], $i, $hash);
		}
	}
}

sub hash_neuron {
	my $self = shift;
	my ($map, $pos, $hash) = @_;

	if (exists $map->{ $hash }) {
		push @{ $map->{ $hash } }, $pos;
	} else {
		$map->{ $hash } = [ $pos ];
	}
}

sub unary2hash {
	my $self = shift;
	my ($hash_unary, $j) = @_;
	my $hash = 0;

	my $k = -1;
	while ( ++$k < $self->{'bits_for_hash'} ) {
		my $i = $self->{'randoms'}->[ ($j * $self->{'bits_for_hash'}) + $k ];
		if ($hash_unary->[ $i ]) {
			$hash += 2**$k;
		}
	}

	return int $hash;
}

sub neuron2unary {
	my $self = shift;
	my ($unary, $pos, $dim) = @_;
	
	my $map = int( floor( 0.5 + $self->{'norm_data'}->get($pos, $dim) * $self->{'max_mapping'}) );
	my $max_mapping = $self->{'max_mapping'};
	
	my $k = $dim * $max_mapping - 1;

	warn "K: $k DIM: $dim MAP: $map LIM: " . ($max_mapping * $dim + $map) . "\n";
	while ( ++$k < $max_mapping * $dim + $map) {
		$unary->[ $k ] = 1 if $k < $self->{'bits_for_hash'};
	}

	my $l = $max_mapping * $dim + $map - 1;
	while ( ++$l < $max_mapping * ($dim + 1) ) {
		$unary->[ $l ] = 0 if $l < $self->{'bits_for_hash'};
	}
}

sub get_subset {
	my $self = shift;

	warn "Generating subset...\n" if $VERBOSE;

	my $data = $self->{'data'};
	my $keys = $self->{'keys'};

	my $subset = is_packed($data) ? Anorman::Data->packed_matrix($data->rows, $data->columns ) : Anorman::Data->matrix( $data->rows, $data->columns);

	my $count = 0;
	my $new_keys = Anorman::Data::List->new;
	
	foreach my $hash(@{ $self->{'maps'} }) {
		foreach my $indexes( values %{ $hash } ) {

			my $size = floor( 0.5 + ((scalar @{ $indexes } * $self->{'percentage'}) / 100) );

			if ($size == 0) {
				my $index_size = scalar @{ $indexes };
				my $j = -1;
				while ( ++$j < $index_size ) {
					my $random = int rand(scalar @{ $indexes });

					my $d = -1;
					while ( ++$d < $data->columns ) {
						$subset->set($count, $d, $data->view_row( $indexes->[ $random ])->get( $d ));
					}

					$new_keys->add( $keys->get( $indexes->[ $random ] ) );
					splice @{ $indexes }, $random, 1;
					$count++;
				}
			} else {
			
				my $j = -1;
				while ( ++$j < $size ) {
					my $index_size = scalar @{ $indexes };
					my $random = int rand($index_size);

					my $d = -1;
					while ( ++$d < $data->columns ) {
						$subset->set($count, $d, $data->view_row( $indexes->[ $random ])->get( $d ));
					}

					$new_keys->add( $keys->get( $indexes->[ $random ] ) );
					splice @{ $indexes }, $random, 1;
					$count++;
				}

			}

		}
	}
	return ($subset->view_part(0,0, $count, $data->columns), $new_keys);
}

1;
