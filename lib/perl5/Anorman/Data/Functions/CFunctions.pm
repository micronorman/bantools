package Anorman::Data::Functions::CFunctions;

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Data::Matrix::DensePacked',
		ENABLE    => AUTOWRAP =>
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include'

           );

#include <stdio.h>
#include <limits.h>
#include "data.h"
#include "matrix.h"
#include "perl2c.h"
#include "error.h"
#include "../lib/functions/function.c"

use Inline C => <<'END_OF_C_CODE';


END_OF_C_CODE

1;

