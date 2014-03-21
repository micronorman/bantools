package Anorman::Data::Functions::Vector;

use strict;
use warnings;

use vars qw(@ISA @EXPORT_OK);
use Anorman::Common;

@EXPORT_OK = qw(v_variance v_variance2 v_scale v_add_constant v_mean v_sum v_stdev);
@ISA = qw(Exporter);

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Data::Functions::Vector',
		ENABLE    => AUTOWRAP =>
		LIBS      => '-L' . $Anorman::Common::AN_SRC_DIR . '/lib -lvector',
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include'
	   );
use Inline C => <<'END_OF_C_CODE';

#include "data.h"
#include "vector.h"
#include "perl2c.h"
#include "functions/vector.h"

#include "../lib/vector.c"
#include "../lib/functions/vector.c"
#include "../lib/functions/functions.c"

NV v_variance ( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_variance( v->size, v );
}

NV v_variance2 ( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_variance2( v->size, v );
}

NV v_mean ( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_mean( v->size, v );
}

NV v_sum ( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_sum( v );
}

NV v_stdev ( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return (NV) sqrt( c_v_variance2( v->size, v ) );
}

IV v_scale ( SV* self, NV value ) {
    SV_2STRUCT( self, Vector, v );

    return (IV) c_v_scale( v, value );
}

IV v_add_constant( SV* self, NV value ) {
    SV_2STRUCT( self, Vector, v);

    return (IV) c_v_add_constant( v, value ); 
}

END_OF_C_CODE

1;

