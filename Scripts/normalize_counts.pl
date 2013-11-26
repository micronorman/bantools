#!/usr/bin/env perl

# normalize_counts.pl
# # program for normalizing rows,
# # and optionally columns prior to running esom
# #
# # Anders Norman, 2012 anorman@berkeley.edu

use strict;
use warnings;

use Anorman::Counts;
use Getopt::Long;

my ($lambda, $verbose,$output,$input,$row_normalize, $col_normalize, $matrix_normalize);

&GetOptions ( "verbose"  => \$verbose,
	      "output=s" => \$output,
	      "input=s"  => \$input,
	      "lambda=f" => \$lambda,
	      "rows=s"   => \$row_normalize,
	      "cols=s"   => \$col_normalize,
	      "matrix=s" => \$matrix_normalize
	    );

my $t = Anorman::Counts->new;

$t->open($input);
my ($cols,$rows) = $t->dims;

$row_normalize = 'by_sum' unless (defined $row_normalize || defined $col_normalize || defined $matrix_normalize);
warn "Normalizing [ $cols x $rows ] matrix\n" if $verbose;

if ($row_normalize) {
	$t->add_row_stats( 'quick' );
	$t->normalize( $t->rows, $row_normalize, { 'lambda1' => $lambda } );
	warn "Normalized rows [ $row_normalize ]\n" if $verbose;
} 

if ($col_normalize) {
	$t->add_col_stats( 'quick' );
	$t->normalize( $t->cols, $col_normalize, { 'lambda1' => $lambda } );
	warn "Normalized columns [ $col_normalize ]\n" if $verbose;
}

if ($matrix_normalize) {
	$t->add_matrix_stats( 'quick' );
	$t->normalize( $t->matrix, $matrix_normalize, { 'lambda1' => $lambda } );
	warn "Normalized matrix [ $matrix_normalize ]\n" if $verbose;
}

$t->update_info;
$t->print( { 'file' => $output } );
