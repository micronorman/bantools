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

	die "Table $fn does not have the correct number of columns ($dims[0] instead of $table1_cols) for concatenation" if $table1_cols != $dims[0];
        
	$tmp_tab->open($fn);
	
	foreach my $row_r(@{ $tmp_tab->rows }) {
		$t->add_row( $tmp_tab->make_copy( $row_r ) );
	}
	warn "Added $fn to table\n";
}

$t->update_info;

($table1_cols,$table1_rows) = $t->dims;
warn "New table has $table1_rows rows\n";

$t->print();
