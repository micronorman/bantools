package Anorman::Data::Functions::Vector;

use warnings;
use strict;
no strict "refs";

use Anorman::Common;
use Anorman::Data::Config;
use Anorman::Math::Functions;

my $F = Anorman::Math::Functions->new;
my %FUNCTIONS = ();

if ($Anorman::Data::Config::PACK_DATA == 1) {
	warn "ASSIGNING XS FUNCTIONS\n" if $DEBUG;

	my %UNARY_XS_FUNCTIONS = (
		'max'		=> \&XS_max,
		'min'		=> \&XS_min,
		'mean'		=> \&XS_mean,
		'sum'		=> \&XS_sum,
		'variance'	=> \&XS_variance,
		'stdev'		=> \&XS_stdev
	);

	my %DISTANCE_XS_FUNCTIONS = (
		'MANHATTAN'	=> \&XS_manhattan_distance,
		'EUCLID'	=> \&XS_euclidean_distance,
		'LQUARTER'	=> &XS_LP(0.25),
		'LTHIRD'	=> &XS_LP(1.0/3.0),
		'LHALF'		=> &XS_LP(0.5),
		'LP1'		=> &XS_LP(1),
		'LP2'		=> &XS_LP(2),
		'LP3'		=> &XS_LP(3),
		'LP4'		=> &XS_LP(4),
		'MAXIMUM'	=> \&XS_maximum_distance,
		'CANBERRA'	=> \&XS_canberra_distance,
		'BRAY_CURTIS'	=> \&XS_bray_curtis_distance,
		'CORRELATION'	=> \&XS_correlation_distance,
		'MAHALANOBIS'	=> \&XS_mahalanobis_distance_chol,
	);

	my %BINARY_XS_FUNCTIONS = (
		'covariance'	=> \&XS_covariance,
		'correlation'	=> \&XS_correlation,
		'dot_product'	=> \&XS_dot_product
	);

	%FUNCTIONS = (
		%UNARY_XS_FUNCTIONS,
		%BINARY_XS_FUNCTIONS,
		%DISTANCE_XS_FUNCTIONS
	);	
} else {
	warn "ASSIGNING PP FUNCTIONS\n" if $DEBUG;

	my %UNARY_PP_FUNCTIONS = (
		'max'		=> sub { $_[0]->aggregate( $F->max , $F->identity ) },
		'min'		=> sub { $_[0]->aggregate( $F->min , $F->identity ) },
		'mean'		=> sub { $_[0]->aggregate( $F->plus, $F->identity ) / $_[0]->size },
		'sum'		=> sub { $_[0]->aggregate( $F->plus, $F->identity ) },
		'variance'	=> sub { my $mean = &mean->($_[0]);
					return ($_[0]->aggregate( $F->plus, $F->square)
					- $mean * $_[0]->aggregate($F->plus, $F->identity))/($_[0]->size - 1) },
		'stdev'		=> sub { sqrt( &variance->($_[0]) ) }
	);


	my %BINARY_PP_FUNCTIONS = (
		'covariance'	=> sub { my $size = $_[0]->size;
	                                 my $sum = 0;
	                                 my $ma = &mean->($_[0]);
	                                 my $mb = &mean->($_[1]);
	
					 my $i = -1;
	                                 while( ++$i < $size ) {
	                                 	$sum+= ($_[0]->get_quick($i) - $ma) * ($_[1]->get_quick($i) - $mb)
					 }
	
					 return $sum / ($size - 1) 
				       },
		'correlation'	=> sub { my $sa = &stdev->($_[0]);
	                                 my $sb = &stdev->($_[1]);
	
	                                 return &covariance->($_[0],$_[1])/($sa*$sb)
	                               }, 
		'dot_product'	=> sub { $_[0]->aggregate($_[1], $F->plus, $F->mult ) }
	);


	my %DISTANCE_PP_FUNCTIONS = (
		'MANHATTAN'	=> sub { $_[0]->aggregate( $_[1], $F->plus, $F->chain( $F->abs, $F->minus)) },
		'EUCLID'	=> sub { sqrt( $_[0]->aggregate($_[1], $F->plus, $F->chain( $F->square, $F->minus))) },
		'LQUARTER'	=> &LP(0.25),
		'LTHIRD'	=> &LP(1.0/3.0),
		'LHALF'		=> &LP(0.5),
		'LP1'		=> &LP(1),
		'LP2'		=> &LP(2),
		'LP3'		=> &LP(3),
		'LP4'		=> &LP(4),
		'MAXIMUM'	=> sub { $_[0]->aggregate( $_[1], $F->max, $F->chain($F->abs, $F->minus )) },
		'CANBERRA'	=> sub { $_[0]->aggregate( $_[1], $F->plus, sub { abs($_[0] - $_[1]) / abs($_[0] + $_[1]) } )},
		'BRAY_CURTIS'	=> sub { $_[0]->aggregate( $_[1], $F->plus, $F->chain($F->abs, $F->minus)) /
					 $_[0]->aggregate( $_[1], $F->plus, $F->plus) },
		'CORRELATION'	=> sub { 1 - &correlation->($_[0],$_[1]) },
		'MAHALANOBIS'	=> sub { my $diff = $_[0] - $_[1]; $_[2]->solve( $diff )->dot_product( $diff ) }
	);


	%FUNCTIONS = (
		%UNARY_PP_FUNCTIONS,
		%BINARY_PP_FUNCTIONS,
		%DISTANCE_PP_FUNCTIONS
	);	
}


while (my ($k,$v) = each %FUNCTIONS) {
	*$k = sub { return $v };
}

sub new { bless ( {}, $_[0] ) }

sub LP {
	my $p = $_[0];
	return sub { ($_[0]->aggregate($_[1], $F->plus,
                                       $F->chain( $F->pow($p),
                                                  $F->chain($F->abs, $F->minus))))
                      ** (1/$p)
                   }
}

sub XS_LP {
	# OK, it's a semi-perl method...
	my $p = $_[0];
	return sub { &XS_LP_distance( $_[0], $_[1], $p ) };
}

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Data::Functions::Vector',
		ENABLE    => AUTOWRAP =>
		LIBS      => '-L/usr/local/opt/openblas/lib -L' . $Anorman::Common::AN_SRC_DIR . '/lib -landata -lopenblas',
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include -I/usr/local/opt/openblas/include'
	   );
use Inline C => <<'END_OF_C_CODE';

#include "data.h"
#include "cblas.h"
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

NV XS_max (SV* self) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_max( v->size, v );
}

NV XS_min (SV* self) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_min( v->size, v );
}

NV XS_variance ( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_variance( v->size, v );
}

NV XS_variance2 ( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_variance2( v->size, v );
}

NV XS_mean ( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_mean( v->size, v );
}

NV XS_sum ( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_sum( v );
}

NV XS_stdev ( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return (NV) sqrt( c_v_variance2( v->size, v ) );
}

NV XS_covariance ( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );	
    SV_2STRUCT( other, Vector, v );	

    return (NV) c_vv_covariance( u->size, u, v );
}

NV XS_correlation ( SV* self, SV* other ) {

    SV_2STRUCT( self, Vector, u );	
    SV_2STRUCT( other, Vector, v );	

    return (NV) c_vv_correlation( u->size, u, v );
}

NV XS_dot_product( SV* self, SV* other ) {

    SV_2STRUCT( self, Vector, u );	
    SV_2STRUCT( other, Vector, v );	

    return (NV) c_vv_dot_product(u, v, 0, u->size );
}

NV XS_manhattan_distance( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) c_vv_aggregate_quick( u->size, u, v, &c_plus, &c_abs_diff );
}

NV XS_euclidean_distance( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) sqrt( c_vv_aggregate_quick( u->size, u, v, &c_plus, &c_square_diff ) );
}

NV XS_maximum_distance( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) c_vv_aggregate_quick( u->size, u, v, &c_max, &c_abs_diff );    
}

NV XS_bray_curtis_distance( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) c_vv_aggregate_quick( u->size, u, v, &c_plus, &c_abs_diff ) /
                c_vv_aggregate_quick( u->size, u, v, &c_plus, &c_plus );    
}

NV XS_correlation_distance( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) ( 1 - c_vv_correlation( u->size, u, v ) );    
}

NV XS_LP_distance( SV* self, SV* other, SV* p_value ) {
    SV_2STRUCT(  self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    const size_t size = u->size;
    const double p    = SvNV( p_value );

    double result = c_p_diff( c_v_get_quick( u, 0 ), c_v_get_quick( v, 0 ), p );
    
    size_t i;
    for (i = 1; i < size; i++ ) {
        result += c_p_diff( c_v_get_quick( u, i ), c_v_get_quick( v, i ), p );
    }

    return (NV) pow( result, 1 / p );
}

NV XS_canberra_distance( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) c_vv_aggregate_quick( u->size, u, v, &c_plus, &c_canberra_diff );
}

SV* XS_mahalanobis_distance_chol( SV* self, SV* other, SV* sv_LLT ) {
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

    Safefree( diff->elements );
    Safefree( diff );
    Safefree( tmp );

    return mahal_dist;    
}

END_OF_C_CODE

1;

