#!/usr/bin/env perl
use strict;
use warnings;

my %BLAST_RESULT = ();
my %CLASS_NUM    = ();

use Anorman::ESOM;
use Anorman::HitTable;
use Data::Dumper;
use Getopt::Long;

my ($blast_file, $names_file, $cls_file, $FH);

&GetOptions(
	'names|n=s' => \$names_file,
	'blast|b=s' => \$blast_file,
	'cls|c=s'   => \$cls_file	
);

my $e = Anorman::ESOM->new;
$e->open( $names_file, 'names' );

open ($FH, '<', $blast_file) or die "ERROR opening $blast_file: $!";

while (defined (my $line = <$FH>)) {
	chomp $line;
	my ($query,$hit) = split ("\t", $line);
	$BLAST_RESULT{ $query } = $hit;
	$CLASS_NUM{ $hit }++;
}

close $FH;

foreach my $class_name(sort keys %CLASS_NUM) {
	$e->add_class( $class_name );
}

$e->generate_class_colors;

my $subseq_index = $e->subseq_index;

while (my ($query, $hit) = each %BLAST_RESULT) {
	my $class_number = $e->class_number( $hit );

	if (exists $subseq_index->{ $query }) {
		foreach my $index(@{ $subseq_index->{ $query } }) {
			$e->dp_class( $index, $class_number );
			my $dp = $e->dp_key( $index );
		}
	}
}

$e->_index_classes;

open ($FH, '>', $cls_file) or die "Cannot open file $cls_file for writing, $!";

print $FH $e->cls_header_string;
print $FH join("\n", map{ $e->dp_key( $_ ) . "\t" . $e->dp_class( $_ ) } $e->datapoints), "\n";

close $FH;
