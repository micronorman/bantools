package Anorman::Math::LSH;

use strict;
use warnings;

use Anorman::Common;

use Anorman::Data;
use Anorman::Data::List;
use Anorman::Data::LinAlg::Property qw( :matrix );
use Anorman::Math::DistanceFactory;
use Anorman::ESOM::BMSearch qw(bm_brute_force_search bm_indexed_search);
use List::Util qw(min);
use POSIX qw(floor);

sub new {
	my $that = shift;
	my $class = ref $that || $that;

	my ($t, $s, $d, $data, $keys, $matrix, $permutation) = @_;

	if (@_ == 0) {
		($t,$s,$d) = (10, 1, 24);
	}

	my $self = {
		'max_mapping'   => $t,
		'hashs'         => $s,
		'bits_for_hash' => $d
	};

	if (@_ == 7) {
		check_matrix( $data );
		check_matrix( $matrix );

		$self->{'lrndata'} = $data->copy;
		$self->{'keys'}    = $keys;
		$self->{'matrix'}  = $matrix->copy;
		$self->{'permutation'} = $permutation;
		$self->{'distance_function'} = Anorman::Math::DistanceFactory->get_function();
	}

	return bless ( $self, $class );
}

sub find_bestmatch {
	my $self  = shift;
	my $index = shift;

	$index--;

	my $bm = -1;
	my $bm_candidates = $self->hash_data( $index );

	if (@{ $bm_candidates } == 0) {
		$bm = bm_brute_force_search( $self->{'lrndata'}->view_row( $index ), $self->{'matrix'} );
	} else {
		$bm = bm_indexed_search( $self->{'lrndata'}->view_row( $index ), $self->{'matrix'}, $bm_candidates );
	}

	return $bm;
}

sub init {
	my $self = shift;

	my $matrix  = $self->{'matrix'};
	my $lrndata = $self->{'lrndata'};

	my $temp_data = Anorman::Data->packed_matrix( $matrix->rows + $lrndata->rows, $matrix->columns );

	$temp_data->view_part(0,0,$matrix->rows,$matrix->columns)->assign($matrix);
	$temp_data->view_part($matrix->rows,0, $temp_data->rows - $matrix->rows, $matrix->columns)->assign($lrndata);

	$temp_data->normalize;

	$self->{'norm_data'}   = $temp_data->view_part($matrix->rows,0,$temp_data->rows - $matrix->rows, $matrix->columns );
	$self->{'norm_matrix'} = $temp_data->view_part(0,0, $matrix->rows, $matrix->columns );

	
	if (!defined $self->{'randoms'}) {
		warn "Generating random subspaces...\n" if $VERBOSE;
		my $randoms = Anorman::Data::List->new;

		while ( $randoms->size < ($self->{'hashs'} * $self->{'bits_for_hash'})) {
			my $rand = int rand($self->{'max_mapping'} * $matrix->columns);
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

	warn "Building LSH...\n" if $VERBOSE;

	$i = -1;
	while ( ++$i < $matrix->rows ) {
		my $j = -1;
		while ( ++$j < $matrix->columns ) {
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
	
	my $max_mapping = $self->{'max_mapping'};
	my $map = int( floor( 0.5 + ($self->{'norm_matrix'}->get($pos, $dim) * $max_mapping)) );

	
	my $k = $dim * $max_mapping - 1;

	while ( ++$k < $max_mapping * $dim + $map) {
		$unary->[ $k ] = 1;
	}

	my $l = $max_mapping * $dim + $map - 1;
	while ( ++$l < $max_mapping * ($dim + 1) ) {
		$unary->[ $l ] = 0;
	}
}

sub vector2unary {
	my $self = shift;
	my $vector = shift;
	
	my $unary = [];
	my $j = -1;
	while ( ++$j < $self->{'matrix'}->columns ) {
		my $max_mapping = $self->{'max_mapping'};
		my $map = int( floor( 0.5 + ($vector->get( $j ) * $max_mapping) ) );
	
		my $k = $j * $max_mapping - 1;

		while ( ++$k < $max_mapping * $j + $map) {
			$unary->[ $k ] = 1;
		}

		my $l = $max_mapping * $j + $map - 1;
		while ( ++$l < $max_mapping * ($j + 1) ) {
			$unary->[ $l ] = 0;
		}
	}

	return $unary;
}

sub hash_data {
	my $self = shift;
	my $i    = shift; 

	my %hitmap = ();

	my $max = 1;
	my $j = -1;
	while ( ++$j < $self->{'hashs'} ) {
		my $hash = $self->unary2hash( $self->vector2unary( $self->{'norm_data'}->view_row($i)), $j);

		if (exists $self->{'maps'}->[$j]->{ $hash }) {
			my $indexes = $self->{'maps'}->[$j]->{ $hash };

			if ($j == 0) {
				my $m = -1;
				while ( ++$m < scalar @{ $indexes }) {
					$hitmap{ $indexes->[ $m ] } = 1;
				}
			} else {
				die "Shouldn't happen";
			}
		}
	}

	return [ keys %hitmap ];
}

1;
