package Anorman::ESOM::Config;

use strict;
use warnings;

use Anorman::Common;

use vars qw(@ISA @EXPORT);

@ISA = qw( Exporter );

warn "Loading ESOM configuration\n" if $VERBOSE;

our $PACK_MATRIX_DATA = 1;

our $COLORS_PATH      = $ENV{'BANTOOLS'} . "/etc/colors/";
our $UMATRIX_GRADIENT = 'earthcolor';

our %FILETYPES = (
	'lrn'   => 'Multivariate Data',  
        'cov'	=> 'Covariance Data',
	'cls'   => 'Classification',
	'names' => 'Names',
	'wts'   => 'ESOM weights',
	'bm'    => 'Bestmatches', 
	'umx'   => 'ESOM U-matrix',
	'cmx'   => 'Class mask',
	'rgb'   => 'Color table'
);

our %CLASS_NAMES = (
	'lrn'	=> 'Lrn',
	'cls'	=> 'Cls',
	'cov'	=> 'Covariance',
	'names' => 'Names',
	'wts'	=> 'Wts',
	'bm'	=> 'BM',
	'umx'	=> 'Umx',
	'cmx'	=> 'ClassMask',
	'rgb'	=> 'ColorTable'
);

our %TYPES = reverse %CLASS_NAMES;

if ($DEBUG) {
	my @gradients = glob "$COLORS_PATH" . "*.rgb";
	warn "Found " . (scalar keys %FILETYPES) . " filetypes\n";
	warn "Colors path: " . $COLORS_PATH . "\n";
	warn "Found " . (scalar @gradients) . " color gradients\n";
	warn "U-Matrix gradient: " . $UMATRIX_GRADIENT . "\n";
	warn "Pack matrix data: : " . ($PACK_MATRIX_DATA ? 'ON' : 'OFF') . "\n";
}

1;
