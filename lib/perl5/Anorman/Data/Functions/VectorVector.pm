package Anorman::Data::Functions::VectorVector;

use strict;
use warnings;

use Anorman::Common;

use vars qw(@ISA @EXPORTER @EXPORT_OK);

@EXPORT_OK = qw(vv_covariance vv_dist_euclidean vv_squared_dist_euclidean);
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
#include "perl2c.h"
#include "vector.h"
#include "functions/vector.h"
#include "functions/vectorvector.h"

#include "../lib/vector.c"
#include "../lib/functions/functions.c"
#include "../lib/functions/vector.c"
#include "../lib/functions/vectorvector.c"

/*  C function wrappers */

NV vv_covariance ( SV* self, SV* other ) {

    SV_2STRUCT( self, Vector, u );	
    SV_2STRUCT( other, Vector, v );	

    return (NV) c_vv_covariance( u->size, u, v );
}

NV vv_squared_dist_euclidean( SV* self, SV* other ) {
    
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) c_vv_squared_dist_euclidean( u->size, u, v );
}

NV vv_dist_euclidean( SV* self, SV* other ) {

    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) c_vv_dist_euclidean( u->size, u, v );
}

NV vv_dist_euclidean_upto( SV* self, SV* other, NV threshold ) {

    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    return (NV) c_vv_dist_euclidean_upto( u->size, u, v, threshold );
  
}
/*
void vv_minus( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    c_vv_sub( u, v );
}

void vv_add( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    c_vv_add( u, v );
}
*/
END_OF_C_CODE

1;

