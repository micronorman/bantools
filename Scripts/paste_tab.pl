#!/usr/bin/env perl

use strict;
use warnings;

use Anorman::Counts;

my @tables = @ARGV;
my $table1 = shift @tables;

my $t = Anorman::Counts->new;
$t->open($table1);

my ($table1_cols,$table1_rows) = $t->dims;

foreach my $fn(@tables) {
	my $tmp_tab = Anorman::Counts->new;
	my @dims = $tmp_tab->check_dims( $fn );

	die "Table $fn does not have the correct number of rows ($dims[1] instead of $table1_rows) to be pasted" if $table1_rows != $dims[1];
        
	warn "Dims OK for $fn\n";

	$tmp_tab->open($fn);
	
	foreach my $col_r(@{ $tmp_tab->cols }) {
		$t->add_col( $tmp_tab->make_copy( $col_r ) );
	}
	warn "Added $fn to table\n";
}

$t->update_info;

($table1_cols,$table1_rows) = $t->dims;
warn "New table has $table1_cols columns\n";

$t->print();
