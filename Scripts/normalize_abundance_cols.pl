#!/usr/bin/env perl

use strict;
use warnings;

use Anorman::Counts;
use Getopt::Long;
use Data::Dumper;

my ($counts_file,$verbose,$output,$input,$col_normalize );
my %base_counts;

&GetOptions ( "file=s"   => \$counts_file,
              "cols"     => \$col_normalize,
              "verbose"  => \$verbose,
	      "output=s" => \$output,
	      "input=s"  => \$input,
	    );

my $t = Anorman::Counts->new;

$t->open($input);
my ($cols,$rows) = $t->dims;


warn "Normalizing [ $cols x $rows ] matrix\n" if $verbose;

if ($counts_file) {
	warn "Loading counts file $counts_file\n" if $verbose;
	open (my $FH, '<', $counts_file) or die "Failed to open $counts_file, $!";

	while (defined (my $line = <$FH>)) {
	    next if $line =~ m/^#/;
	    chomp $line;
	    my ($sample,$number) = $line =~ m/^(\S+)\s+(\d+)\s*/; 
            $base_counts{ $sample } = $number if defined $number;
	}
	close $FH;
}

my %samples = map { $_->{'name'}, $_->{'_num'} } $t->col_info;

#print Dumper (\%samples,\%base_counts);exit;

$t->apply( \&normalize_abundance_cols, $t->rows );
$t->print( { 'file' => $output } );

sub normalize_abundance_cols {
	my $data_r = shift;
	my $info_r = shift @{ $data_r };
	#my $i      = 0;

	foreach (@{ $data_r }){ 
		#next if $base_counts[$i] == 0;
		#$$_ /= ( $base_counts[$i] * $info_r->{'length'} );
		$$_ /= $info_r->{'length'};
		#$i++
	}
}
