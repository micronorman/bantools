#!/usr/bin/env perl

use strict;
use warnings;

use Anorman::Counts;
use Anorman::ESOM;
use Getopt::Long;

$Anorman::Common::VERBOSE = 1;

my ($cls_file, $input, $min, $max);

&GetOptions(
	'input=s'	=> \$input,
	'cls=s'		=> \$cls_file,
	'min=i'		=> \$min,
	'max=i'		=> \$max
);

my $t = Anorman::Counts->new;
my $e = Anorman::ESOM->new;

$t->open($input);

my $rows = $t->[0][0]->{'rows'};
my @lengths = map { $_->{'length'} } $t->row_info;
my $stats = $t->calc_stats( \@lengths, 'full' );

$max = defined $max ? $max : $stats->{'_max'};
$min = defined $min ? $min : $stats->{'_min'};

warn "Minimum length: $min\n";
warn "Maximum length: $max\n";
warn "Median length: $stats->{'_median'}\n";

# Load the Jet color gradient
$e->load_color_table("jet");

my $partitions  = $e->color_table->size;
my $interval     = ($max - $min) / $partitions;

my @breakpoints = map { $min + int( $_ *  $interval ) } (1 .. $partitions);

my $classes = $e->class_table;

foreach my $class_num(0..$partitions - 1) {
	$classes->add( $class_num, $breakpoints[ $class_num ] . "_bp" , $e->color_table->data->[ $class_num ] );
}

my $cls = $e->data_classes;

$cls->filename( $cls_file );
$cls->classes( $classes );

my %bins = map { $_ => [] } @breakpoints;

foreach my $dp(1 .. $rows) { 
	my $class_num = 1;
	my $length    = $lengths[ $dp - 1 ];

	foreach my $limit(@breakpoints) {
		last if $length <= $limit;
		$class_num++;
	}


	$cls->add( $dp, $class_num - 1 );
}

$cls->save;
