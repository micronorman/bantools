package Anorman::ESOM::BMSearch;

use strict;
use warnings;

use Anorman::Common;

use Exporter;
use vars qw(@ISA @EXPORT_OK);

@EXPORT_OK = qw(bm_brute_force_search bm_local_search bm_indexed_search);
@ISA       = qw(Exporter);

sub new {
	my $class = shift;
	return bless ( {}, ref($class) || $class );
}

sub som { $_[0]->{'_SOM'} = $_[1] if @_ > 1; $_[0]->{'_SOM'} }

sub old_bestmatches {}

sub init {}

sub constant {}

sub find_bestmatch {}

sub data {}

sub matrix {}

sub permutation {}

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::ESOM::BMSearch',
		LIBS      => '-L' . $Anorman::Common::AN_SRC_DIR . '/lib',
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include'

           );
use Inline C => <<'END_OF_C_CODE';

#include "data.h"
#include "perl2c.h"
#include <float.h>

void bm_brute_force_search( SV* vector, SV* weights ) {
    /* search all weights for bestmatch */
    SV_2STRUCT( vector, Vector, v );
    SV_2STRUCT( weights, Matrix, w );

    IV bm  = -1;
    double min = DBL_MAX;
    double threshold = min;
    double dist2; /* square distance */	

    long double diff;

    double* v_elems = v->elements;
    double* w_elems = w->elements;

    /* highly optimized search. Will only measure euclidean distance */    
    size_t i;
    for (i = 0; i < w->rows; i++) {
        size_t w_index = (v->size + i * w->row_stride) - 1;
        size_t v_index = (v->zero + v->size - 1);

        diff = v_elems[ v_index ] - w_elems[ w_index ];
        dist2 = (diff * diff); 
    
        int k = v->size - 1;
        while ( --k >= 0) {
            v_index--;
            w_index--;
            if (dist2 > threshold)
            break;
            diff   = v_elems[ v_index ] - w_elems[ w_index ];
            dist2 += (diff * diff);
        }

        if ( dist2 < min ) {
             min = dist2;
             bm  = (IV) i;
             threshold = dist2;
        }
    }

    /* Prepare return values */
    Inline_Stack_Vars;

    Inline_Stack_Reset;
    Inline_Stack_Push(sv_2mortal(newSViv(bm)));
    Inline_Stack_Push(sv_2mortal(newSVnv(min)));
    Inline_Stack_Done;
}

void bm_indexed_search( SV* vector, SV* weights, AV* indices ) {
    /* search a list of neurons for the best match */
    SV_2STRUCT( vector, Vector, v );
    SV_2STRUCT( weights, Matrix, w );

    int    bm        = -1;
    double min       = DBL_MAX;
    double threshold = min;
    double dist2; /* square distance */	
    double diff;

    double* v_elems = v->elements;
    double* w_elems = w->elements;

    int n = (int) av_len(indices) + 1;
    int i;

    /* highly optimized search. Only measures euclidean distance */    
    for (i = 0; i < n; i++ ) {
        int index = (int) SvIV( *av_fetch( indices, i, 0 ) ); 
        int w_index = (int) (v->size + index * w->row_stride) - 1;
        int v_index = (int) (v->zero + v->size - 1);

        diff = v_elems[ v_index ] - w_elems[ w_index ];
        dist2 = (diff * diff); 
    
        int k = v->size - 1;
        while ( --k >= 0) {
            v_index--;
            w_index--;
            if (dist2 > threshold)
            break;
            diff   = v_elems[ v_index ] - w_elems[ w_index ];
            dist2  += (diff * diff);
        }

        if ( dist2 < min ) {
             min = dist2;
             bm  = i;
             threshold = dist2;
        }
    }

    /* Prepare return values */
    Inline_Stack_Vars;

    Inline_Stack_Reset;
    Inline_Stack_Push(sv_2mortal(newSViv(bm)));
    Inline_Stack_Push(sv_2mortal(newSVnv(min)));
    Inline_Stack_Done;
}

void bm_local_search( SV* vector, SV* weights, IV top, IV left, IV bottom, IV right, IV grid_rows, IV grid_columns ) {
    /* search a square area for the best match */
    SV_2STRUCT( vector, Vector, v );
    SV_2STRUCT( weights, Matrix, w );

    double* v_elems = v->elements;
    double* w_elems = w->elements;
    
    int    bm        = -1;
    double min       = DBL_MAX;
    double threshold = min;
    double dist2; /* square distance */	
    double diff;

    int i  = (int) top - 1;
    while ( ++i <= bottom ) {

        int j = left - 1;
        while ( ++j <= right ) {

            /* locate neuron on grid */
            int neuron_index = (((i + grid_rows) % grid_rows) * grid_columns) + ((j + grid_columns) % grid_columns);

            /* locate vector in weights matrix */
            int w_index = (neuron_index * w->columns) + w->columns - 1;
            int v_index = (int) (v->zero + v->size - 1);

            diff = v_elems[ v_index ] - w_elems[ w_index ];
            dist2 = (diff * diff); 
    
            int k = v->size - 1;
            while ( --k >= 0) {
                v_index--;
                w_index--;
                if (dist2 > threshold)
                break;
                diff   = v_elems[ v_index ] - w_elems[ w_index ];
                dist2  += (diff * diff);
            }

            if ( dist2 < min ) {
                 min = dist2;
                 bm  = neuron_index;
                 threshold = dist2;
            }
        }
    }

    /* Prepare return values */
    Inline_Stack_Vars;

    Inline_Stack_Reset;
    Inline_Stack_Push(sv_2mortal(newSViv(bm)));
    Inline_Stack_Push(sv_2mortal(newSVnv(min)));
    Inline_Stack_Done;
}

END_OF_C_CODE

1;

package Anorman::ESOM::BMSearch::Simple;

use parent -norequire,'Anorman::ESOM::BMSearch';
use POSIX qw(DBL_MAX);

use Data::Dumper;

sub new { return shift->SUPER::new() };

sub find_bestmatch {
	my $self = shift;
	return Anorman::ESOM::BMSearch::bm_brute_force_search( $_[1], $_[2] );
} 

sub slow_find_bestmatch {
	my $self = shift;
	my ($func, $vector, $neurons) = @_;

	my $neuron = $neurons->view_row( 0 );
	my $dim    = $vector->size;

	my ($bm, $dist);
	my $min = DBL_MAX;

	my $i = -1;
	while ( ++$i < $neurons->rows ) {
		$dist = $func->( $vector, $neuron, $min );

		if ($dist < $min) {
			$min        = $dist;
			$bm         = $i;
		}

		$neuron->_setup( $neuron->size, $neuron->_zero + $dim, 1 );
	}

	return ($bm, $dist);
}

1;

package Anorman::ESOM::BMSearch::Local;

use strict;

use parent -norequire,'Anorman::ESOM::BMSearch';

use List::Util qw(max min);

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(); 

	$self->{'constant'} = 0;
	return $self;
}

sub find_bestmatch {
	my $self   = shift;

	my ($index, $vector, $weights, $epoch) = @_;

	if ($epoch < 1) {
		return Anorman::ESOM::BMSearch::bm_brute_force_search( $vector, $weights );
	} else {
		my $range = $self->get_range( $epoch, $index );
		my $oldbm = $self->{'_old_bestmatches'}->[ $index ];
		
		# find center
		my $r = $self->som->grid->index2row( $oldbm );
		my $c = $self->som->grid->index2col( $oldbm );

		# grid dimensions
		my $rows = $self->som->grid->rows;
		my $cols = $self->som->grid->columns;

		# define bounding box
		my $top    = int max( $r - ( $rows / 2), $r - $range );
		my $left   = int max( $c - ( $cols / 2), $c - $range );
		my $bottom = int min( $r + ( $rows / 2), $r + $range );
		my $right  = int min( $c + ( $cols / 2), $c + $range );

		return Anorman::ESOM::BMSearch::bm_local_search( $vector, $weights, $top, $left, $bottom, $right, $rows, $cols );
	}	
	
}

sub constant {
	my $self     = shift;

	if (defined $_[0]) {
		$self->{'constant'} = $_[0];
	} else {
		return $self->{'constant'};
	}
}

sub old_bestmatches {
	my $self = shift;

	if (defined $_[0]) {
		$self->{'_old_bestmatches'} = $_[0];
	} else {
		return $self->{'_old_bestmatches'};
	}
}

1;

package Anorman::ESOM::BMSearch::Local::Constant;

use parent -norequire,'Anorman::ESOM::BMSearch::Local';

sub get_range {
	my $self = shift;
	return $self->{'constant'};
}

1;

package Anorman::ESOM::BMSearch::Local::QuickLearning;

use parent -norequire,'Anorman::ESOM::BMSearch::Local';

sub get_range {
	my $self = shift;
	return $self->som->radius + $self->{'constant'};
}

package Anorman::ESOM::BMSearch::Local::MuchFasterLearning;

use strict;

use parent -norequire, 'Anorman::ESOM::BMSearch::Local';

use List::Util qw(max);

sub old_bestmatches {
	my $self = shift;

	return $self->{'_old_bestmatches'} if !defined $_[0];

	if (!exists $self->{'_old_bestmatches'}) {
		$self->{'_old_bestmatches'} = [ @{ $_[0] } ];
	} else {
		$self->{'_older_bestmatches'} = [ @{ $self->{'_old_bestmatches' } } ];
		$self->{'_old_bestmatches'}   = [ @{ $_[0] } ];

	}
}

sub get_range {
	my $self = shift;
	my ($epoch, $index) = @_;

	if ($epoch < 2) {
		return $self->som->grid->columns / 2;
	} else {
		my $grid    = $self->som->grid;
		my $oldbm   = $self->{'_old_bestmatches'}->[ $index ];
		my $olderbm = $self->{'_older_bestmatches'}->[ $index ];

		return $self->{'constant'} if $oldbm == $olderbm;

		my $range = max( abs( $grid->index2col( $oldbm ) - $grid->index2col( $olderbm ) ), 
				 abs( $grid->index2row( $oldbm ) - $grid->index2row( $olderbm ) )
			       ) + $self->{'constant'};

		return $range;
	}
}

1;

package Anorman::ESOM::BMSearch::LSH;


1;
