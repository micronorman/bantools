package Anorman::Data::Config;

use strict;
use warnings;

use vars qw(@ISA @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);

@EXPORT_OK = qw(
	$PACK_DATA
	$FORMAT
	$VECTOR_ENDS
	$VECTOR_SEPARATOR
	$MATRIX_ROW_ENDS
	$MATRIX_ROW_SEPARATOR
	$MATRIX_COL_SEPARATOR
	$MAX_ELEMENTS
);

%EXPORT_TAGS = ( 'string_rules' => [qw($FORMAT $VECTOR_ENDS $VECTOR_SEPARATOR $MATRIX_ROW_ENDS $MATRIX_ROW_SEPARATOR $MATRIX_COL_SEPARATOR) ]);

our $PACK_DATA   = 0;
our $FORMAT      = '%7.3G';

our $VECTOR_ENDS          = [ '{ ', ' }' ];
our $VECTOR_SEPARATOR     = ",";
our $MATRIX_ROW_ENDS      = [ '[ ', ' ]' ];
our $MATRIX_COL_SEPARATOR = ",";
our $MATRIX_ROW_SEPARATOR = "\n";

our $MAX_ELEMENTS     = 2147483647;

1;
