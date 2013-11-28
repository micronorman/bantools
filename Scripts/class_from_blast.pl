#!/usr/bin/env perl
use strict;
use warnings;

my %BLAST_RESULT = ();
my %CLASS_NUM    = ();

use Anorman::ESOM::File;
use Getopt::Long;

use Data::Dumper;

my ($blast_file, $names_file, $cls_file, $FH);

&GetOptions(
	'names|n=s' => \$names_file,
	'blast|b=s' => \$blast_file,
	'cls|c=s'   => \$cls_file	
);

my $names = Anorman::ESOM::File::Names->new( $names_file );
my $cls   = Anorman::ESOM::File::Cls->new( $cls_file );

$names->load;

open ($FH, '<', $blast_file) or die "ERROR opening $blast_file: $!";

while (defined (my $line = <$FH>)) {
	chomp $line;
	my ($query,$hit) = split ("\t", $line);
	$BLAST_RESULT{ $query } = $hit;
	$CLASS_NUM{ $hit }++;
}

close $FH;

foreach my $class_name(sort keys %CLASS_NUM) {
	$cls->classes->add( undef, $class_name );
}

my $subseq_index = $names->subseq_index;

my %tmp_cls = ();
while (my ($query, $hit) = each %BLAST_RESULT) {
	my $class_number = $cls->classes->get_by_name( $hit )->index;

	if (exists $subseq_index->{ $query }) {
		foreach my $index(@{ $subseq_index->{ $query } }) {
			$tmp_cls{ $index } = $class_number;
		}
	} else {
		warn "$query was not found\n";
	}
}

foreach my $index(sort { $a <=> $b } keys %tmp_cls) {
	$cls->add( $index, $tmp_cls{$index} );
}

$cls->set_datapoints( $names->datapoints );
$cls->save();

