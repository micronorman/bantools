#!/usr/bin/env perl

use strict;
use warnings;

use Anorman::ESOM;
use Anorman::Math::Common;
use Getopt::Long;

my ($input,$output, $lambda);

&GetOptions( 'input=s'   => \$input,
             'output=s'  => \$output,
	     'lambda=f'  => \$lambda
	   );
my $e = Anorman::ESOM::Parser->new( 'umx' );

$e->open($input );

my $Umatrix_r = [ map { map{ \$_ }@{ $_ } } @{ $e->data } ]; 

&Anorman::Math::Common::normalize_BoxCox( $Umatrix_r, $lambda );
&Anorman::Math::Common::normalize_zero_to_one( $Umatrix_r );

my $rows = $e->rows;
my $cols = $e->columns;

print "%$rows $cols\n";
print join("\n", map { join("\t", @{ $_ }) } @{ $e->data });

