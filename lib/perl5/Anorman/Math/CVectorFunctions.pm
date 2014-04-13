package Anorman::Math::CVectorFunctions;

use strict;
use warnings;

use Anorman::Common;

use Anorman::Data;
use Anorman::Math::VectorFunctions;

my $VF = Anorman::Math::VectorFunctions->new;

my $threshold = 1000;

my $func1 = $VF->_PP_squared_euclidean_distance_upto( \$threshold );
my $func2 = $VF->SQUARED_EUCLID_UPTO( \$threshold );
my $func3 = &fetch_dist_func();
my $func4 = sub { 
	my $i = 0;
	my $dist = ($_[0]->get_quick($i) - $_[1]->get_quick($i)) ** 2;
	while ($dist <= $threshold && ++$i < $_[0]->size ) {
		$dist += ($_[0]->get_quick($i) - $_[1]->get_quick($i)) ** 2;
	}
	return $dist;
};

my $v1 = Anorman::Data->vector(10)->assign(sub{int rand(10)});
my $v2 = $v1->like->assign(sub{int rand(10)});

print "$v1\n$v2\n";

	my ($dist1, $dist2, $dist3, $dist4, $fail);

	$fail = 0;
	$dist1 = $func1->($v1, $v2, $threshold );
	$dist2 = $func2->($v1, $v2, $threshold );
	$dist3 = &execute_dist_func( $func3, $v1, $v2, $threshold );
foreach (1 .. 1e7) {
	$dist4 = $func4->($v1, $v2, $threshold );
}

	warn "Threshold: $threshold\nDIST1 (XS_PP)\t: $dist1\nDIST2 (XS_C)\t: $dist2\nDIST3 (C)\t: $dist3\nDIST4 (PP)\t: $dist4\n\n";

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Math::CVectorFunctions',
		ENABLE    => AUTOWRAP =>
		LIBS      => '-L/usr/local/opt/openblas/lib -L' . $Anorman::Common::AN_SRC_DIR . '/lib -landata -lopenblas',
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include -I/usr/local/opt/openblas/include'
	   );
use Inline C => <<'END_OF_C_CODE';

#include "data.h"
/*#include "cblas.h" */
#include "vector.h"
#include "perl2c.h"
#include "error.h"
#include "functions/functions.h"
#include "functions/vector.h"
#include "functions/vectorvector.h"

/*
#include "../lib/vector.c"
*/

#include "../lib/functions/vector.c"
#include "../lib/functions/vectorvector.c"
#include "../lib/functions/functions.c"

SV* fetch_thr_dist_func () {
    double ( *func_ptr ) ( size_t, Vector*, Vector*, double );

    func_ptr = (vv_thr_func) &c_vv_dist_squared_euclidean_upto;

    PTR_2SVADDR( func_ptr, func_sv );

    return func_sv; 
}

SV* fetch_dist_func () {
    double ( *func_ptr ) ( size_t, Vector*, Vector* );

    func_ptr = (vv_func) &c_vv_dist_squared_euclidean_upto;

    PTR_2SVADDR( func_ptr, func_sv );

    return func_sv; 
}

NV execute_dist_func( SV* sv_func_ptr, SV* sv_u, SV* sv_v, NV th ) {
    SV_2STRUCT( sv_u, Vector, u);
    SV_2STRUCT( sv_v, Vector, v);

    if (u->size != v->size) {
        C_ERROR("Vectors must have sam size", C_EINVAL);
    }

    double ( *func_ptr ) ( size_t, Vector*, Vector*, double );

    func_ptr = INT2PTR( vv_thr_func, SvUV( sv_func_ptr ) );
 
    return (NV) ( *func_ptr ) ( u->size, u, v, th );
}

END_OF_C_CODE

1;

