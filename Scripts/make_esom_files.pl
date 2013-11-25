#!/usr/bin/env perl
use strict;
use warnings;

use Anorman::Counts;
use Getopt::Long;

our (
    $FILE,
    $HELP,
    $VERBOSE,
    $NONAMES
    );

# Default output prefix
our $OUT = "out";

&GetOptions (   "help"        => \$HELP,
                "input=s"     => \$FILE,
                "verbose"     => \$VERBOSE,
                "nonames"     => \$NONAMES,
                "output=s"    => \$OUT
              );

my $table = Anorman::Counts->new;

# open table files
$table->open($FILE);

# Write .lrn files
my $lrn_opt   = { 'row_num'    => 1,
                  'row_info'   => 0,
		  'file'       => "$OUT.lrn"
  		};

# .names file
my $names_opt = { 'row_num'    => 1, 
                  'row_info'   => [ qw/name/ ], 
		  'header_row' => 0,
		  'cols'       => 0,
		  'data'       => 0,
		  'col_types'  => 0,
		  'file'       => "$OUT.names"
		 };

$table->print($lrn_opt);
$table->print($names_opt) unless $NONAMES;
