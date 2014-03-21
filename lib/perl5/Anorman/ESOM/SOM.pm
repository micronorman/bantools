package Anorman::ESOM::SOM;

use strict;

use Anorman::Common;
use Anorman::Data;
use Anorman::Data::LinAlg::Property qw( :matrix );
use Anorman::ESOM::Grid;
use Anorman::ESOM::BMSearch;
use Anorman::ESOM::Neighborhood;
use Anorman::ESOM::Cooling;
use Anorman::ESOM::Descriptives;
use Anorman::Math::DistanceFactory;

use List::Util qw(shuffle);
use Time::HiRes qw(time);

my $TRAIN_BEG;
my $TRAIN_END;

my %DEFAULTS = (
	'epochs'          => 20,
	'permute'         => 1,
	'neighborhood'    => 'gauss',
	'bmsearch'        => 'standard',
	'bmconstant'      => 8,
	'init_method'     => 'norm_mean_2std',
	'neuron_distance' => 'euc',
	'cool-radius'     => 'lin',
	'start-radius'    => 24,
	'end-radius'      => 1,
	'cool-learn'      => 'lin',
	'start-learn'     => 0.5,
	'end-learn'       => 0.1,
);

sub new {
	my $that  = shift;
	my $class = ref $that || $that;

	my $self  = {};

	my %user_opt = @_;

	# Check user sanity
	do { trace_error("Illegal argument $_") unless exists $DEFAULTS{ $_ } } for keys %user_opt;
	my %opt = (%DEFAULTS, %user_opt);


	# Set neighborhood type
	if ($opt{'neighborhood'} eq 'gauss') {
		$self->{'_neighborhood'} = Anorman::ESOM::Neighborhood::Gaussian->new;
	} elsif ($opt{'neighborhood'} eq 'mexhat') {
		$self->{'_neighborhood'} = Anorman::ESOM::Neighborhood::MexicanHat->new;
	} elsif ($opt{'neighborhood'} eq 'bubble') {
		$self->{'_neighborhood'} = Anorman::ESOM::Neighborhood::Bubble->new;
	} elsif ($opt{'neighborhood'} eq 'cone') {
		$self->{'_neighborhood'} = Anorman::ESOM::Neighborhood::Cone->new;
	} elsif ($opt{'neighborhood'} eq 'epan') {
		$self->{'_neighborhood'} = Anorman::ESOM::Neighborhood::Epanechnikov->new;
	}

	# Set radius cooling type and limits
	if ($opt{'cool-radius'} eq 'lin') {
		$self->{'_radius_cooling'} = Anorman::ESOM::Cooling::Linear->new( $opt{'start-radius'},
										  $opt{'epochs'},
										  $opt{'end-radius'});
	} elsif ($opt{'cool-radius'} eq 'exp') {
		$self->{'_radius_cooling'} = Anorman::ESOM::Cooling::Exponential->new( $opt{'start-radius'},
										       $opt{'epochs'},
										       $opt{'end-radius'});
	}

	# Set learning rate cooling type and limits
	if ($opt{'cool-learn'} eq 'lin') {
		$self->{'_rate_cooling'}   = Anorman::ESOM::Cooling::Linear->new( $opt{'start-learn'},
										  $opt{'epochs'},
										  $opt{'end-learn'});
	} elsif ($opt{'cool-learn'} eq 'exp') {
		$self->{'_rate_cooling'}   = Anorman::ESOM::Cooling::Exponential->new( $opt{'start-learn'},
										       $opt{'end-learn'});
	}

	# Set the bestmatch search strategy
	if ($opt{'bmsearch'} eq 'standard') {
		$self->{'_bmsearch'} = Anorman::ESOM::BMSearch::Simple->new;
	} elsif ($opt{'bmsearch'} eq 'quick') {
		$self->{'_bmsearch'} = Anorman::ESOM::BMSearch::Local::QuickLearning->new;
	} elsif ($opt{'bmsearch'} eq 'faster') {
		$self->{'_bmsearch'} = Anorman::ESOM::BMSearch::Local::MuchFasterLearning->new;
	} elsif ($opt{'constant'} eq 'constant') {
		$self->{'_bmsearch'} = Anorman::ESOM::BMSearch::Local::Constant->new;
	}

	$self->{'_distance_func'}  = Anorman::Math::DistanceFactory->get_function( SPACE => 'euclidean', THRESHOLD => 1 );
	$self->{'_epochs'}         = $opt{'epochs'};
	$self->{'_init_method'}    = $opt{'init_method'};
	$self->{'_permute'}        = $opt{'permute'};

	$self->{'_bmsearch'}->constant( $opt{'bmconstant'} );

	return bless ( $self, $class );
}

sub init {
	my $self   = shift;

	trace_error("Cannot initialize trainer with no grid loaded") unless $self->{'_grid'};

	if ($VERBOSE) {	
		printf STDERR ("Initializing [ %d x %d ] grid...\n", $self->grid->rows, $self->grid->columns );
	}

	# Initialize the grid using the selected method
	$self->grid->init( $self->{'_descriptives'}, $self->{'_init_method'} );

}

#===========================  MAIN TRAINING ROUTINE ===========================

sub train {
	$TRAIN_BEG = time ();

	my $self    = shift;
	my $weights = $self->grid->get_weights;
	
	$self->{'_epoch'} = 0;
	$self->{'_bmsearch'}->som( $self );

	warn "[ ", sprintf("%.2f", $TRAIN_BEG - $TIME) , "s ] Training begin\n";

	until ( $self->stop ) {
		
		# tasks to perform before each epoch
		$self->before_epoch;
		
		warn "\tTraining...\n" if $VERBOSE;

		my $pos = 0;

		my $i = -1;
		while ( ++$i < $self->data->rows ) {

			# Retrive row index from the current permutation
			my $index = $self->{'_permutation'}->[ $i ];

			# Retrieve data vector
			my $vector = $self->get_pattern( $index );

			# Locate the bestmatch neuron
			my ($bm, $dist) = $self->{'_bmsearch'}->find_bestmatch( $index,
			                                                        $vector, 
                                                                                $weights,
                                                                                $self->{'_epoch'}
                                                                              ); 
			
			# Store the best match
			$self->{'_bestmatches'}->[ $index ] = $bm;

			# Store the distance
			$self->{'_distances'}->set( $i, $dist );

			# online update ( disabled when batch training )
			$self->update( $vector, $bm, $pos );

			# stuff to do after neuron has been updated
			$self->after_update( $bm, $index );
		
			$pos++;

		}

		# after epoch stuff
		$self->after_epoch;
		$self->{'_epoch'}++;
	}

	my $TRAIN_END = time();
	my $DURATION  = sprintf("%.2f",$TRAIN_END - $TRAIN_BEG);

	warn "[ ", sprintf("%.2f", $TRAIN_END - $TIME) ," ] Total training time: ", $DURATION, "\n";

	# Final round of bestmatch searching (Always uses brute force search)
	my $i  = -1;
	while ( ++$i < $self->data->rows ) {
		my $index = $self->{'_permutation'}->[ $i ];
		my $vector = $self->get_pattern( $index );
		my ($bm, $dist) = Anorman::ESOM::BMSearch::bm_brute_force_search( $vector, $weights );
		
		$self->{'_bestmatches'}->[ $index ] = $bm;		 
		$self->{'_distances'}->set( $i, $dist );
	}
}

#==============================================================================

sub before_epoch {
	my $self = shift;

	# Save intermediate data
	# TODO
	
	# Cool parameters
	$self->cool;

	# Display progress
	printf STDERR ("[ %.2fs ] Epoch: %u, Radius: %u, Num. of Neigh. neurons: %u, Lrn. Rate %.4f\n",
		time() - $TIME,
		$self->{'_epoch'},
		$self->{'_radius'},
		$self->neighborhood->get->size - 1,
		$self->{'_rate'}
	);	

	if ($self->{'_permute'}) {	
		# shuffle data vectors
		warn "\tPermuting data patterns\n" if $VERBOSE;
		@{ $self->{'_permutation'} } = shuffle @{ $self->{'_permutation'} };
	}
};

sub after_update { };

sub after_epoch  {
	my $self = shift;
	warn "\tGrid updated, storing bestmatches\n" if $VERBOSE;
	$self->BMSearch->old_bestmatches( $self->bestmatches );
};

sub update_neighborhood {
	my $self = shift;
	my ($vector, $bm) = @_;

	&_fast_update_neighborhood( $vector,                    # the data vector to use
				    $self->grid->neighbors( $bm, $self->radius ),
				    $self->neighborhood->get,
				    $self->grid->get_weights    # the neurons 
			          );                
}

sub cool {
	warn "\tCooling parameters\n" if $VERBOSE;
	my $self        = shift;
	my $last_radius = $self->{'_radius'};
	my $last_rate   = $self->{'_rate'};
	
	my $n = $self->{'_neighborhood'};
	my $g = $self->{'_grid'};

	$self->{'_radius'} = $self->{'_radius_cooling'}->get_as_int( $self->{'_epoch'} );
	$self->{'_rate'}   = $self->{'_rate_cooling'}->get( $self->{'_epoch'} );

	# re-calculate new neighborhoods if ratio or learning rate has changed
	if (($self->{'_radius'} != $last_radius) && ($self->{'_rate'} != $last_rate)) {
		$n->radius( $g->transform_radius( $self->{'_radius'} ) );
		$n->scaling( $self->{'_rate'});
		$n->init( $g->distances( $self->{'_radius'} ));
	} elsif ($self->{'_rate'} != $last_rate) {
		$n->scaling( $self->{'_rate'} );
		$n->init( $g->distances );
	} else {
		$n->radius( $g->transform_radius( $self->{'_radius'} ) );
		$n->init( $g->distances( $self->{'_radius'} ) );
	}
}

sub update {};

sub stop {
	my $self = shift;
	return ( $self->{'_epoch'} >= $self->{'_epochs'});
}

sub bestmatches { $_[0]->{'_bestmatches'} }

sub descriptives { $_[0]->{'_descriptives'} }

sub data {
	my $self = shift;
	my $data = shift;

	if (defined $data) {

		# Verify that input is matrix
		check_matrix( $data );

		# Add data to object
		$self->{'data'}          = $data;

		# Calculate descriptives
		$self->{'_descriptives'} = Anorman::ESOM::Descriptives->new( $data );

		# Initialize bestmatches and permutations
		$#{ $self->{'_bestmatches'} }  = $data->rows - 1;
		$self->{'_distances'} = Anorman::Data->packed_vector( $data->rows );
		$self->{'_permutation'} = [ 0 .. $data->rows - 1 ];
	} else {
		return $self->{'data'};
	}
}

sub get_pattern {
	my $self = shift;
	return $self->{'data'}->view_row( $_[0] );
}

sub get_distance {
	my $self = shift;
	my ($i, $j) = @_;
}

sub distance_function {
	my $self = shift;
	$self->{'_distance_function'} = shift if defined $_[0];
	return $self->{'_distance_function'};
}

sub epochs {
	my $self = shift;
	$self->{'_epochs'} = shift if defined $_[0];
	return $self->{'_epochs'} if defined $self->{'_epochs'};
}

sub grid {
	my $self = shift;
	$self->{'_grid'} = shift if defined $_[0];
	return $self->{'_grid'} if defined $self->{'_grid'};
}

sub keys {
	my $self = shift;
	$self->{'_keys'} = shift if defined $_[0];
	return $self->{'_keys'} if defined $self->{'_keys'};
}

sub neighborhood {
	my $self = shift;
	$self->{'_neighborhood'} = shift if defined $_[0];
	return $self->{'_neighborhood'} if defined $self->{'_neighborhood'};
}

sub radius_cooling {
	my $self = shift;
	$self->{'_radius_cooling'} = shift if defined $_[0];
	return $self->{'_radius_cooling'} if defined $self->{'_radius_cooling'}
}

sub rate_cooling {
	my $self = shift;
	$self->{'_rate_cooling'} = shift if defined $_[0];
	return $self->{'_rate_cooling'} if defined $self->{'_rate_cooling'}
}

sub distances {
	my $self = shift;
	return $self->{'_distances'};
}

sub BMSearch {
	my $self = shift;

	if (defined $_[0]) {
		$self->{'_bmsearch'} = shift;
		$self->{'_bmsearch'}->som( $self );
	};

	return $self->{'_bmsearch'};
}

sub radius { $_[0]->{'_radius'} };
sub rate   { $_[0]->{'_rate'} };

sub save_bestmatches {
	my $self 	= shift;
	my $filename    = shift;

	my $bestmatches = $self->{'_bestmatches'};
	my $grid        = $self->{'_grid'};

	my $bm = Anorman::ESOM::File::BM->new();
	
	$bm->rows( $grid->rows );
	$bm->columns( $grid->columns );

	my $size = $self->data->size;
	my $i = -1;
	while ( ++$i < $size ) {
		my $key = $self->keys->[ $i ];
		my $row = $grid->index2row( $i );
		my $col = $grid->index2col( $i );
		$bm->add( $key, $row, $col )
	}

	$bm->save( $filename );
}

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::ESOM::SOM',
		ENABLE    => AUTOWRAP =>
		LIBS      => '-L' . $Anorman::Common::AN_SRC_DIR . '/lib',
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include'
	   );

use Inline C => <<'END_OF_C_CODE';

#include "data.h"
#include "perl2c.h"
#include "../lib/vector.c"

void update_neuron( size_t size, double weight, Vector* vector, Vector* neuron ) {
	double* v_elems = vector->elements;
	double* n_elems = neuron->elements;

        size_t v_index = c_v_index( vector, 0 );
        size_t n_index = c_v_index( neuron, 0 );
	
        int k = (size_t) size;
	
	while ( --k >= 0 ) {
		const long double diff = v_elems[ v_index ] - n_elems[ n_index ];

		if (diff != 0) {
			n_elems[ n_index ] += ( weight * diff );
		}

                v_index++;
                n_index++;
	}
}

void _fast_update_neighborhood ( SV* vector, char* neighbors, SV* weights, SV* neurons ) {
	
    SV_2STRUCT( vector, Vector, v );
    SV_2STRUCT( weights, Vector, w );
    SV_2STRUCT( neurons, Matrix, grid );

    unsigned int *n = (unsigned int *) neighbors;

    Vector* neuron;
    Newxz( neuron, 1, Vector);

    neuron->elements  = grid->elements;
    neuron->size      = grid->columns;
    neuron->stride    = grid->column_stride;
    neuron->view_flag = 1;
    
    double* w_elems = w->elements;
    
    size_t i;
    for (i = 0; i < w->size; i++ ) {
        neuron->zero   = n[ i ] * grid->row_stride;

        if ( w_elems[ i ] != 0.0 ) {
            update_neuron( neuron->size, w_elems[ i ], v, neuron );
        }
    }

    c_v_free( neuron );
}

END_OF_C_CODE

1;

package Anorman::ESOM::SOM::Online;

use parent -norequire,'Anorman::ESOM::SOM';

sub new { 
	my $class = shift;
	my $self  = $class->SUPER::new(@_); 

	return $self;
};

sub update {
	my $self = shift;
	$self->update_neighborhood( @_ );
}

1;

package Anorman::ESOM::SOM::KBatch;

use parent -norequire, 'Anorman::ESOM::SOM';

use Anorman::Common;
use Anorman::Data::Functions::VectorVector qw(vv_add);
use Anorman::Data::Functions::Vector qw(v_scale);

my $NUM_UPDATES = 0;

sub new { 
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	$self->{'_hashmap'} = {};
	$self->{'_kepoch'}  = 0;

	return $self
}; 

sub update {
	my $self = shift;
	my $pos  = pop;

	if ($pos % $self->{'_K'} == 0 && $pos && $pos < $self->data->rows ) {
		$self->{'_kepoch'} = 1;
		
		my ($vector, $bm) = @_;
		
		$self->_store_bestmatch( $bm, $vector );

		warn "\tK-batch: updating ", scalar keys %{ $self->{'_hashmap'} }, " bestmaches\n" if $VERBOSE;
		
		while (my ($bm, $bmh ) = each %{ $self->{'_hashmap'} }) {
			my $mean = $self->_mean_bestmatch( $bmh );

			$self->update_neighborhood( $mean, $bm );
			$NUM_UPDATES++;
		}

		%{ $self->{'_hashmap'} } = ();
	} 
}

sub after_update {
	my $self = shift;

	if ($self->{'_kepoch'}) { 
		$self->{'_kepoch'} = 0;
		return;
	}
	
	my ($bm, $i) = @_;
	my $vector = $self->get_pattern( $i );

	$self->_store_bestmatch( $bm, $vector);
}

sub after_epoch {
	my $self = shift;
	$self->SUPER::after_epoch();

	warn "\tEnd of epoch: updating ", scalar keys %{ $self->{'_hashmap'} }, " bestmaches\n" if $VERBOSE;

	while (my ($bm, $bmh ) = each %{ $self->{'_hashmap'} }) {
		my $mean = $self->_mean_bestmatch( $bmh );
		$self->update_neighborhood( $mean, $bm ); 
		$NUM_UPDATES++;
	}

	%{ $self->{'_hashmap'} } = ();
	warn "\t$NUM_UPDATES updates performed\n" if $VERBOSE;
	$NUM_UPDATES = 0;
}

sub K {
	my $self = shift;
	$self->{'_K'} = shift if defined $_[0];
	return $self->{'_K'};
}

sub _store_bestmatch {
	my $self = shift;
	my ($bm, $vector ) = @_;

	if (exists $self->{'_hashmap'}->{ $bm }) {
		my $bmh = $self->{'_hashmap'}->{ $bm };
		$self->_add_bestmatch( $bmh, $vector );
	} else {
		$self->{'_hashmap'}->{ $bm } = [ $vector->copy, 1 ];
	}
}

sub _add_bestmatch {
	my $self = shift;
	my ( $bmh, $vector ) = @_;

	vv_add( $bmh->[0], $vector );
	$bmh->[1]++;
}

sub _mean_bestmatch {
	my $self = shift;
	my ( $bmh, $vector ) = @_;

	if ( $bmh->[1] > 1 ) {
		v_scale( $bmh->[0], 1 / $bmh->[1] );
		$bmh->[1] = 1;
	}

	return $bmh->[0];	
}

1;

package Anorman::ESOM::SOM::SlowBatch;

use parent -norequire,'Anorman::ESOM::SOM';

sub new { $_[0]->SUPER::new(@_) };

sub after_epoch {
	my $self = shift;
	$self->SUPER::after_epoch;

	warn "\tSlow batch-update ", scalar @{ $self->{'_bestmatches'} }, " bestmatches\n";

	my $i = 0;
	foreach my $bm(@{ $self->{'_bestmatches'} }) {
		$self->update_neighborhood( $self->get_pattern( $i ), $bm );
		$i++;
	}
}

1;

package Anorman::ESOM::SOM::GESOM;

use parent -norequire,'Anorman::ESOM::SOM';

use Anorman::ESOM::GrowGrid;

sub new { $_[0]->SUPER::new(@_) };

sub update {
	my $self = shift;
	$self->update_neighborhood( @_ );
}

sub init {
	my $self = shift;
	my $rows    = $self->{'_grid'}->rows;
	my $columns = $self->{'_grid'}->columns;


}

sub before_epoch {

}
	
1;
