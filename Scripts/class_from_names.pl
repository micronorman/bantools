#!/usr/bin/env perl

use strict;
use warnings;

use Anorman::ESOM;

my $esom = Anorman::ESOM->new;

$esom->open($ARGV[0]);

my %classes        = ();
my @dp_class_names = ();

foreach my $dp( $esom->datapoints ) {
	my $name = $dp->name;
	my $class_name;

	if ($name =~ m/^(\S+)(_scaffold.*|_contig.*)?_\d+\s+\d+-\d+/) {
		$class_name = $1;
	} else {
		$name =~ m/^([\w\-\_]+)/;
		$class_name = $1;
	}

	$class_name =~ s/_\d+$//;
	$classes{ $class_name }++;

	push @dp_class_names, $class_name;
}

my %class_numbers = ();

foreach my $class_name( sort { $a cmp $b } keys %classes) {
	my $index = $esom->add_class( $class_name );
	$class_numbers{ $class_name } = $index;
}

print $esom->cls_header_string;

foreach my $dp( $esom->datapoints ) {
	my $index        = $dp->index;
	my $key          = $dp->key;

	my $class_number = $class_numbers{ $dp_class_names[ $index ] };

	print "$key\t$class_number\n";
	
}

