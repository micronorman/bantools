#!/usr/bin/env perl

use strict;
use warnings;

use Anorman::Counts;
use Anorman::ESOM;
use Getopt::Long;
use Data::Dumper;

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


my @colors      = map { chomp;[ split ] } <DATA>;
my $partitions  = @colors;
my $interval     = ($max - $min) / $partitions;

my @breakpoints = map { $min + int( $_ *  $interval ) } (1 .. $partitions);

foreach my $class_num(0..$#colors) {
	$e->add_class( $breakpoints[ $class_num ] . "_bp" , $colors[ $class_num ] );
}

my %bins = map { $_ => [] } @breakpoints;

foreach my $dp(1 .. $rows) { 
	my $class_num = 1;
	my $length    = $lengths[ $dp - 1 ];

	foreach my $limit(@breakpoints) {
		last if $length <= $limit;
		$class_num++;
	}


#	while ($class_num >= 0 && $breakpoints[ $class_num ] > $length ) { $class_num-- };
	$e->add_datapoint( { 'cls' => $class_num } );
#	push @{ $bins->{ $class_num } }, $length;
}


#foreach my $key(sort { $a <=> $b } keys %bins) {
#	print "[ $key ]\n\t", join ("\n\t", @{ $bins{ $key } }), "\n";
#}
print $e->cls_header_string;
foreach my $dp( $e->datapoints ) {
	my $class = $e->dp_class( $dp );
	print "$dp\t$class\n";
}

__DATA__
0 0 143
0 0 175
0 0 207
0 0 239
0 16 255
0 48 255
0 80 255
0 112 255
0 143 255
0 175 255
0 207 255
0 239 255
16 255 255
48 255 223
80 255 191
112 255 159
143 255 128
175 255 96
207 255 64
239 255 32
255 255 0
255 223 0
255 191 0
255 159 0
255 128 0
255 96 0
255 64 0
255 32 0
255 0 0
223 0 0
191 0 0
159 0 0
