#!/usr/bin/env perl
use strict;
use warnings;

use Anorman::ESOM;


my @lines=();
my %HASH = ();
my $newcat =1;

while (<>) {

	next if /^%/;
	my @F = split ("\t", $_);
	my $sample = $1 if $F[1] =~ m/(.*)(_scaffold.*|_contig.*)/;

	if (exists $HASH{$sample}) {
	    push @lines, $HASH{$sample};
	} else {
	    push @lines, $HASH{$sample} = $newcat;
	    $newcat++;
	}
}
print "%", scalar @lines, "\n";

foreach (sort { $HASH{$a} <=> $HASH{$b} } keys %HASH) { 
    print "%$HASH{$_}\t$_\n"
}

my $n = 1;
foreach (@lines) {
	print "$n\t$_\n";
	$n++;
}
