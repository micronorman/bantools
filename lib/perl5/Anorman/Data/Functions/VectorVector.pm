package Anorman::Data::Functions::VectorVector;

use strict;
use warnings;

use Anorman::Common;

use vars qw(@ISA @EXPORTER @EXPORT_OK);

@EXPORT_OK = qw(vv_covariance vv_add_assign vv_minus_assign vv_dist_euclidean);
@ISA       = qw(Exporter);


use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Data::Functions::VectorVector',
		ENABLE    => AUTOWRAP =>
		LIBS      => '-L' . $Anorman::Common::AN_SRC_DIR . '/lib -lvector',
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include'
	   );
use Inline C => <<'END_OF_C_CODE';

#include "data.h"
#include "vector.h"
#include "functions/vector.h"
#include "functions/vectorvector.h"

#include "../lib/vector.c"
#include "../lib/functions/functions.c"
#include "../lib/functions/vector.c"
#include "../lib/functions/vectorvector.c"

#define SV_2VECTOR( sv, ptr_name )    Vector* ptr_name = (Vector*) SvIV( SvRV( sv ) )

static void _check_size( Vector*, Vector* );

/* perl to C interface */

NV vv_covariance ( SV* self, SV* other ) {

    SV_2VECTOR( self, u );	
    SV_2VECTOR( other, v );	

    _check_size( u, v);	
    return (NV) c_vv_covariance( u->size, u, v );
}

NV vv_dist_euclidean( SV* self, SV* other ) {

    SV_2VECTOR( self, u );
    SV_2VECTOR( other, v );
    _check_size( u, v);	

    return (NV) c_vv_dist_euclidean( u->size, u, v );
}

NV vv_dist_euclidean_upto( SV* self, SV* other, NV threshold ) {

    SV_2VECTOR( self, u );
    SV_2VECTOR( other, v );
    _check_size( u, v);	

    return (NV) c_vv_dist_euclidean_upto( u->size, u, v, (double) threshold );
  
}

void vv_minus_assign( SV* self, SV* other ) {
    SV_2VECTOR( self, u );
    SV_2VECTOR( other, v );
    _check_size( u, v );

    c_vv_minus_assign( u, v );
}

void vv_add_assign ( SV* self, SV* other ) {
    SV_2VECTOR( self, u );
    SV_2VECTOR( other, v );
    _check_size( u, v);

    c_vv_plusmult_assign( u->size, u, v, 1 );
}

void _check_size( Vector* u, Vector* v ) {
    if (u->size != v->size) {
	    croak("Vectors (u,v) have different sizes");
    }
}

END_OF_C_CODE

1;

