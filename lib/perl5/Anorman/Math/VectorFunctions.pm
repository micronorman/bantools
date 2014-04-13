package Anorman::Math::VectorFunctions;

use warnings;
use strict;
no strict "refs";

use Anorman::Common;
use Anorman::Data::LinAlg::Property qw(is_matrix is_square);
use Anorman::Data::Config;
use Anorman::Math::Functions;
use Scalar::Util;
use Anorman::Math::Common qw(multi_quantiles);

our @UNARY_FUNCTIONS    = qw(
	min
	max
	sum
	mean
	variance
	stdev
);

our @BINARY_FUNCTIONS   = qw(
	covariance
	correlation
	dot_product
);

our @DISTANCE_FUNCTIONS = qw(
	MANHATTAN
	EUCLID
	SQUARED_EUCLID
	LQUARTER
	LTHIRD
	LHALF
	LP1
	LP2
	LP3
	LP4
	MAXIMUM
	CANBERRA
	BRAY_CURTIS
	CORRELATION
	COSINE
);

our @THR_DISTANCE_FUNCTIONS = qw(
	MANHATTAN_UPTO
	EUCLID_UPTO
	SQUARED_EUCLID_UPTO
	LQUARTER_UPTO
	LTHIRD_UPTO
	LHALF_UPTO
	LP1_UPTO
	LP2_UPTO
	LP3_UPTO
	LP4_UPTO
	MAXIMUM_UPTO
);

my (@UNARY_CODE,@BINARY_CODE,@DISTANCE_CODE, @THR_DISTANCE_CODE);

if ($Anorman::Data::Config::PACK_DATA == 1) {
	warn "ASSIGNING XS FUNCTIONS\n" if $DEBUG;

	@UNARY_CODE = (
		&_wrap_XS( \&_XS_min ),
		&_wrap_XS( \&_XS_max ),
		&_wrap_XS( \&_XS_sum ),
		&_wrap_XS( \&_XS_mean ),
		&_wrap_XS( \&_XS_variance ),
		&_wrap_XS( \&_XS_stdev )
	);

	@BINARY_CODE = (
		&_wrap_XS( \&_XS_covariance ),
		&_wrap_XS( \&_XS_correlation ),
		&_wrap_XS( \&_XS_dot_product )
	);

	@DISTANCE_CODE = (
		&_wrap_XS( \&_XS_manhattan_distance ),
		&_wrap_XS( \&_XS_euclidean_distance ),
		&_wrap_XS( \&_XS_squared_euclidean_distance ),
		&_wrap_XS_LP(0.25),
		&_wrap_XS_LP(1.0/3.0),
		&_wrap_XS_LP(0.5),
		&_wrap_XS_LP(1),
		&_wrap_XS_LP(2),
		&_wrap_XS_LP(3),
		&_wrap_XS_LP(4),
		&_wrap_XS( \&_XS_maximum_distance ),
		&_wrap_XS( \&_XS_canberra_distance ),
		&_wrap_XS( \&_XS_bray_curtis_distance ),
		&_wrap_XS( \&_XS_correlation_distance ),
		&_wrap_XS( \&_XS_cosine_distance )
	);

	@THR_DISTANCE_CODE = (
		&_wrap_XS( \&_XS_manhattan_distance_upto ),
		&_wrap_XS( \&_XS_euclidean_distance_upto ),
		&_wrap_XS( \&_XS_squared_euclidean_distance_upto ),
		&_wrap_XS_LP_upto(0.25),
		&_wrap_XS_LP_upto(1.0/3.0),
		&_wrap_XS_LP_upto(0.5),
		&_wrap_XS_LP_upto(1),
		&_wrap_XS_LP_upto(2),
		&_wrap_XS_LP_upto(3),
		&_wrap_XS_LP_upto(4),
		&_wrap_XS( \&_XS_maximum_distance_upto ),
	)
} else {
	warn "ASSIGNING PP FUNCTIONS\n" if $DEBUG;

	@UNARY_CODE = (
		\&_PP_min,
		\&_PP_max,
		\&_PP_sum,
		\&_PP_mean,
		\&_PP_variance,
		\&_PP_stdev
	);

	@BINARY_CODE = (
		\&_PP_covariance,
		\&_PP_correlation,
		\&_PP_dot_product
	);

	@DISTANCE_CODE = (
		\&_PP_manhattan_distance,
		\&_PP_euclidean_distance,
		\&_PP_squared_euclidean_distance,
		\&_PP_minkowsky_distance_Pquart,
		\&_PP_minkowsky_distance_Pthird,
		\&_PP_minkowsky_distance_Phalf,
		\&_PP_minkowsky_distance_P1,
		\&_PP_minkowsky_distance_P2,
		\&_PP_minkowsky_distance_P3,
		\&_PP_minkowsky_distance_P4,
		\&_PP_maximum_distance,
		\&_PP_canberra_distance,
		\&_PP_bray_curtis_distance,
		\&_PP_correlation_distance,
		\&_PP_cosine_distance
	);

	@THR_DISTANCE_CODE = (
		\&_PP_manhattan_distance_upto,
		\&_PP_euclidean_distance_upto,
		\&_PP_squared_euclidean_distance_upto,
		\&_PP_minkowsky_distance_Pquart_upto,
		\&_PP_minkowsky_distance_Pthird_upto,
		\&_PP_minkowsky_distance_Phalf_upto,
		\&_PP_minkowsky_distance_P1_upto,
		\&_PP_minkowsky_distance_P2_upto,
		\&_PP_minkowsky_distance_P3_upto,
		\&_PP_minkowsky_distance_P4_upto,
		\&_PP_maximum_distance_upto,
	)
}

my @NAMES = (
	@UNARY_FUNCTIONS,
	@BINARY_FUNCTIONS,
	@DISTANCE_FUNCTIONS,
	@THR_DISTANCE_FUNCTIONS
);

my @CODE  = (
	@UNARY_CODE,
	@BINARY_CODE,
	@DISTANCE_CODE,
	@THR_DISTANCE_CODE
);

my %FUNCTIONS = (); @FUNCTIONS{ @NAMES } = @CODE;

# Assign function aliases to names
while (my ($k,$v) = each %FUNCTIONS) {
	*$k = $v;
}

my $F = Anorman::Math::Functions->new;


# Object constructor 

sub new { bless ( {}, $_[0] ) }


#=================================
# Unary vector functions: y = F(v)
#=================================

sub trimmed_mean {
	my $self = shift;
	my $trim = shift;

	return sub {
		my @data = sort { $a <=> $b } @{ $_[0] };
		my @phis = ( $trim / 2, 1 - $trim / 2 );

		my @quants = Anorman::Math::Common::multi_quantiles( \@phis, \@data );

		my $s = 0.0;
		my $c = 0;
		my $i = $_[0]->size;
		while ( --$i >= 0 ) {
			my $v = $_[0]->get_quick($i);
			if (($v > $quants[0]) && ($v < $quants[1])) {
				$s += $v;
				$c++;
			}
		}

		return $s / $c;
	}
}


sub robust_mean {
	my $self = shift;
	return $self->trimmed_mean(0.2);
}

sub robust_stdev {
	my $self = shift;

	return sub {
		my @data   = sort { $a <=> $b } @{ $_[0] };
		my @phis   = (0.25,0.75);
		my @quants = Anorman::Math::Common::multi_quantiles( \@phis, \@data );

		my $s = sqrt( $self->variance->( $_[0] ) );

		return List::Util::min( ($quants[1] - $quants[0])/ 1.349, $s);
	}
}

sub median {
	my $self= shift;
	return $self->quantile(0.5);
}

sub quantile {
	my $self = shift;
	my $phi  = shift;

	return sub {
		my @data = sort { $a <=> $b } @{ $_[0] };
		my @quant = Anorman::Math::Common::quantile( $phi, \@data );

		return $quant[0];
	}
}


sub _PP_min    { return &_wrap_unary( $F->min , $F->identity ) } # Minimum
sub _PP_max    { return &_wrap_unary( $F->max , $F->identity ) } # Maximum
sub _PP_sum    { return &_wrap_unary( $F->plus, $F->identity ) } # Sum
sub _PP_sum_sq { return &_wrap_unary( $F->plus, $F->square   ) } # Sum of squares

# Vector min

sub _PP_mean     { 
	my $f1 = &_PP_sum;
	return sub { $f1->($_[0],$_[1]) / $_[0]->size } 
}


# Vecor variance

sub _PP_variance {
	my $f1 = &_PP_mean;
	my $f2 = &_PP_sum_sq;
	my $f3 = &_PP_sum;

	return sub { 
		     my $m = $f1->($_[0]); 
		     return ($f2->($_[0]) - $m * $f3->($_[0])) / ($_[0]->size - 1);
		   }
}


# Vector standard deviation

sub _PP_stdev {
	my $f1 = &_PP_variance;
	
	return sub { sqrt( $f1->($_[0]) ) }
}


#====================================
# Binary vector functions: y = F(v,w)
#====================================

sub _PP_covariance {
	my $f1 = &_PP_mean;

	return sub {
		     my $size = $_[0]->size;
	             my $ma = $f1->($_[0]);
	             my $mb = $f1->($_[1]);
	             
		     my $sum = 0;
	
		     my $i = -1;
	             while( ++$i < $size ) {
	               $sum+= ($_[0]->get_quick($i) - $ma) * ($_[1]->get_quick($i) - $mb)
		     }
	
		     return $sum / ($size - 1) 
		    }
}

sub _PP_correlation {
	my $f1 = &_PP_stdev;
	my $f2 = &_PP_covariance;

	return sub {
		     my $sa = $f1->($_[0]);
		     my $sb = $f1->($_[1]);

		     return $f2->($_[0], $_[1]) / ($sa * $sb)
		   }
}
		
sub _PP_dot_product {
	return &_wrap_binary( $F->plus, $F->mult );
}


#======================================
# Vector Distance functions: y = D(v,w)
#======================================


# Manhattan (aka City block) distance

sub _PP_manhattan_distance      { &_wrap_binary( $F->plus, $F->chain( $F->abs, $F->minus ) ) };
sub _PP_manhattan_distance_upto { &_wrap_binary_upto( $F->plus, $F->chain( $F->abs, $F->minus )) };


# Euclidean distance

sub _PP_euclidean_distance {
	my $f1 = &_wrap_binary( $F->plus, $F->chain( $F->square, $F->minus ) );

	return sub { sqrt( $f1->($_[0],$_[1])) }	
}

sub _PP_euclidean_distance_upto {
	my $th = $_[1];
	my $f1 = &_wrap_binary_upto( $F->plus, $F->chain( $F->square, $F->minus ), $th );

	return sub { sqrt( $f1->($_[0],$_[1], $$th ** 2 )) };
}


# Squared Euclidean distance

sub _PP_squared_euclidean_distance {
	return &_wrap_binary( $F->plus, $F->chain( $F->square, $F->minus ) );	
}

sub _PP_squared_euclidean_distance_upto {
	return &_wrap_binary_upto( $F->plus, $F->chain( $F->square, $F->minus ));
}


# Maximum (Chebyshew) distance

sub _PP_maximum_distance {
	return &_wrap_binary( $F->max, $F->chain( $F->abs, $F->minus ));
}

sub _PP_maximum_distance_upto {
	return &_wrap_binary_upto( $F->max, $F->chain( $F->abs, $F->minus ), $_[1]);
}


# Minkowsky distances P = (1/4, 1/3, 1/2, 1, 2, 3, 4)

sub _PP_minkowsky_distance_Pquart { return &_wrap_LP(0.25) }
sub _PP_minkowsky_distance_Pthird { return &_wrap_LP(1/3 ) }
sub _PP_minkowsky_distance_Phalf  { return &_wrap_LP(0.5 ) }
sub _PP_minkowsky_distance_P1     { return &_wrap_LP(1   ) }
sub _PP_minkowsky_distance_P2     { return &_wrap_LP(2   ) }
sub _PP_minkowsky_distance_P3     { return &_wrap_LP(3   ) }
sub _PP_minkowsky_distance_P4     { return &_wrap_LP(4   ) }

sub _PP_minkowsky_distance_Pquart_upto { return &_wrap_LP_upto(0.25) }
sub _PP_minkowsky_distance_Pthird_upto { return &_wrap_LP_upto(1/3 ) }
sub _PP_minkowsky_distance_Phalf_upto  { return &_wrap_LP_upto(0.5 ) }
sub _PP_minkowsky_distance_P1_upto     { return &_wrap_LP_upto(1   ) }
sub _PP_minkowsky_distance_P2_upto     { return &_wrap_LP_upto(2   ) }
sub _PP_minkowsky_distance_P3_upto     { return &_wrap_LP_upto(3   ) }
sub _PP_minkowsky_distance_P4_upto     { return &_wrap_LP_upto(4   ) }


# Canberra distance

sub _PP_canberra_distance {
	return &_wrap_binary( $F->plus, sub { abs($_[0] - $_[1]) / abs($_[0]) + abs($_[1]) } );
}


# Bray-Curtis distance

sub _PP_bray_curtis_distance {
	my $f1 = &_wrap_binary( $F->plus, $F->chain( $F->abs, $F->minus ) );
	my $f2 = &_wrap_binary( $F->plus, $F->plus );

	return sub { $f1->($_[0], $_[1]) / $f2->($_[0],$_[1]) }
}


# Correlation distance

sub _PP_correlation_distance {
	my $f1 = &_PP_correlation;

	return sub { 1 - $f1->($_[0],$_[1]) }; 
}


# Cosine distance 

sub _PP_cosine_distance {
	
	return sub {
		my $ab = $_[0]->dot_product( $_[1] );
		my $aa = $_[0]->dot_product( $_[0] );
		my $bb = $_[1]->dot_product( $_[1] );

		return 1 - $ab / (sqrt($aa) * sqrt($bb)); 
	}
}

sub MAHALANOBIS {
	my $A = $_[1];
	return sub { my $diff = $_[0] - $_[1]; return sqrt( $A->solve( $diff )->dot_product( $diff ) ) }
}


#=========================================
# Wrappers for vector aggreation functions
#=========================================

sub _wrap_unary {
	# Perform aggregation on a single vector (usually a descriptive statistic)
	my ($aggr, $f) = @_;

	return sub { $_[0]->aggregate( $aggr, $f ) };
}

sub _wrap_binary {
	# Perform aggregation between two vectors (usually a distance function)
	my ($aggr, $f) = @_;

	return sub { $_[0]->aggregate($_[1], $aggr, $f) }
}

sub _wrap_binary_upto {
	# As above, but with a threshold. Quicker if only interessted in smallest distance
	# Takes three arguments
	my ($aggr, $f) = @_;

	return sub { 
		     trace_error("Wrong number of arguments") if @_ != 3; 
		     return $_[0]->aggregate_upto($_[1], $aggr, $f, $_[2] ); 
		   };
}

sub _wrap_LP {
	my $p       = $_[0];
	my $recip_p = (1/$p);
	
	my $f1   = &_wrap_binary( $F->plus,
                                  $F->chain( $F->pow($p), 
                                             $F->chain($F->abs, $F->minus)));

	return sub { $f1->($_[0],$_[1]) ** $recip_p }; 
}

sub _wrap_LP_upto {
	my       $p = $_[0];

	trace_error("P cannot be zero") if $p == 0;

	my $recip_p = 1 / $p;
	my $f1 = &_wrap_binary_upto( $F->plus, $F->chain( $F->pow($p), $F->chain($F->abs, $F->minus)));

	return sub { $f1->($_[0], $_[1], $_[2] ** $p ) ** $recip_p };
}

sub _wrap_XS {
	my $code = shift;
	return sub { $code };
}

sub _wrap_XS_LP {
	# This simply binds the third argument (The P-value) to the XS_LP_function...
	my $p = shift;
	return sub { return sub { &_XS_LP_distance( $_[0], $_[1], $p ) } };
}

sub _wrap_XS_upto {
	my $code = shift;

	trace_error("Not a valid CODE block") unless ref $code eq 'CODE';
	
	return sub { return sub { $code->($_[0], $_[1], $_[2]) } };

}

sub _wrap_XS_LP_upto {
	my $p = shift;

	return sub { return sub { &_XS_LP_distance_upto( $_[0], $_[1], $p, $_[2]) } }
}

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Math::VectorFunctions',
		ENABLE    => AUTOWRAP =>
		LIBS      => '-L/usr/local/opt/openblas/lib -L' . $Anorman::Common::AN_SRC_DIR . '/lib -landata -lopenblas',
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include -I/usr/local/opt/openblas/include'
	   );
use Inline C => <<'END_OF_C_CODE';

#include "data.h"
#include "cblas.h"
#include "error.h"
#include "vector.h"
#include "perl2c.h"
#include "functions/functions.h"
#include "functions/vector.h"
#include "functions/vectorvector.h"

/*
#include "../lib/vector.c"
*/

#include "../lib/functions/vector.c"
#include "../lib/functions/vectorvector.c"
#include "../lib/functions/functions.c"


/* Unary functions */

NV _XS_max (SV* self) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_max( v->size, v );
}

NV _XS_min (SV* self) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_min( v->size, v );
}

NV _XS_variance ( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_variance( v->size, v );
}

NV _XS_variance2 ( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_variance2( v->size, v );
}

NV _XS_mean ( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_mean( v->size, v );
}

NV _XS_sum ( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_sum( v );
}

NV _XS_stdev ( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return (NV) sqrt( c_v_variance2( v->size, v ) );
}


/* Binary functions */

NV _XS_covariance ( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );	
    SV_2STRUCT( other, Vector, v );	

    return (NV) c_vv_covariance( u->size, u, v );
}

NV _XS_correlation ( SV* self, SV* other ) {

    SV_2STRUCT( self, Vector, u );	
    SV_2STRUCT( other, Vector, v );	

    return (NV) c_vv_correlation( u->size, u, v );
}

NV _XS_dot_product( SV* self, SV* other ) {

    SV_2STRUCT( self, Vector, u );	
    SV_2STRUCT( other, Vector, v );	

    return (NV) c_vv_dot_product(u, v, 0, u->size );
}

/************************
 ** Distance functions **
 ************************/


/* Manhattan */

NV _XS_manhattan_distance( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) c_vv_aggregate_quick( u->size, u, v, &c_plus, &c_abs_diff );
}

NV _XS_manhattan_distance_upto( SV* self, SV* other, NV th ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) c_vv_aggregate_quick_upto( u->size, u, v, &c_plus, &c_abs_diff, th );
}


/* Euclidean */

NV _XS_euclidean_distance( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) sqrt( c_vv_aggregate_quick( u->size, u, v, &c_plus, &c_square_diff ) );
}

NV _XS_euclidean_distance_upto( SV* self, SV* other, NV th ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) sqrt( c_vv_aggregate_quick_upto( u->size, u, v, &c_plus, &c_square_diff, th * th ) );
}

NV _XS_squared_euclidean_distance( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) c_vv_aggregate_quick( u->size, u, v, &c_plus, &c_square_diff );
}

NV _XS_squared_euclidean_distance_upto( SV* self, SV* other, NV th ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) c_vv_aggregate_quick_upto( u->size, u, v, &c_plus, &c_square_diff, th );
}


/* Maximum */

NV _XS_maximum_distance( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) c_vv_aggregate_quick( u->size, u, v, &c_max, &c_abs_diff );    
}

NV _XS_maximum_distance_upto( SV* self, SV* other, NV th ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) c_vv_aggregate_quick_upto( u->size, u, v, &c_max, &c_abs_diff, th );    
}


/* Bray-Curtis */

NV _XS_bray_curtis_distance( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) c_vv_aggregate_quick( u->size, u, v, &c_plus, &c_abs_diff ) /
                c_vv_aggregate_quick( u->size, u, v, &c_plus, &c_plus );    
}


/* Correlation */

NV _XS_correlation_distance( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) ( 1 - c_vv_correlation( u->size, u, v ) );    
}


/* Canberra */

NV _XS_canberra_distance( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) c_vv_aggregate_quick( u->size, u, v, &c_plus, &c_canberra_diff );
}

/* Cosine */

NV _XS_cosine_distance( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );	
    SV_2STRUCT( other, Vector, v );
    
    if (u->size != v->size) {
        C_ERROR("Vectors must have same length", C_EINVAL);
    }

    size_t size = u->size;
    
    double ab = c_vv_dot_product( u, v, 0, size );	
    double aa = c_vv_dot_product( u, u, 0, size );	
    double bb = c_vv_dot_product( v, v, 0, size );

    return (NV) 1 - ab / sqrt(aa) / sqrt(bb);	
}

/* LP (Minkowskyi) distances */

NV _XS_LP_distance( SV* self, SV* other, NV p_value ) {
    SV_2STRUCT(  self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    const size_t size = u->size;
    const double p    = (const double) p_value;

    double result = c_p_diff( c_v_get_quick( u, 0 ), c_v_get_quick( v, 0 ), p );
    
    size_t i;
    for (i = 1; i < size; i++ ) {
        result += c_p_diff( c_v_get_quick( u, i ), c_v_get_quick( v, i ), p );
    }

    return (NV) pow( result, 1 / p );
}

NV _XS_LP_distance_upto( SV* self, SV* other, NV p_value, NV nv_th ) {
    SV_2STRUCT(  self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    const size_t size = u->size;
    const double p    = (const double) p_value;
    const double th   = pow( nv_th, p );
    
    double result = c_p_diff( c_v_get_quick( u, 0 ), c_v_get_quick( v, 0 ), p );
    
    size_t i;
    for (i = 1; i < size; i++ ) {
        if (result > th)
        break;

        result += c_p_diff( c_v_get_quick( u, i ), c_v_get_quick( v, i ), p );
    }

    return (NV) pow( result, 1 / p );    
}

SV* _XS_mahalanobis_distance_chol( SV* self, SV* other, SV* sv_LLT ) {
    /* Mahalanobis distance based on a Cholesky decomposition
       Requires the input matrix to be symmetric positive-definite */
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );
    SV_2STRUCT( sv_LLT, Matrix, LLT );

    SV* mahal_dist = newSVnv(0);

    const size_t size = u->size;

    Vector* diff;

    /* Allocate temporary space for difference vector */
    Newxz( diff, 1, Vector );

    diff->size      = size;
    diff->stride    = 1;

    diff->elements  = c_v_alloc( diff, size );

    /* copy elements */
    c_vv_copy( diff, u );

   /* subtract second vector */
    c_vv_sub( diff, v );


    double* LLT_data =  LLT->elements + (LLT->row_zero + LLT->column_zero);
    double* diff_data = diff->elements + diff->zero;

    double result;
    double* tmp;

    /* store temporary vector for dot product calculation */
    Newx( tmp, size, double );
    Copy( diff->elements, tmp, size, double );

    /* Solve (equivalent to multiplying with the inverse covariance matrix) */
    cblas_dtrsv(CblasRowMajor, CblasLower, CblasNoTrans, CblasNonUnit, (int) size, LLT_data, LLT->row_stride,
                diff_data, (int) diff->stride);

    cblas_dtrsv(CblasRowMajor, CblasUpper, CblasNoTrans, CblasNonUnit, (int) size, LLT_data, LLT->row_stride,
                diff_data, (int) diff->stride);

    result = cblas_ddot( (int) size, diff_data, 1, tmp, 1 );
   
    sv_setnv( mahal_dist, sqrt( result ) );

    /* Free all temporary elements */
    Safefree( diff->elements );
    Safefree( diff );
    Safefree( tmp );

    return mahal_dist;    
}

END_OF_C_CODE

1;

