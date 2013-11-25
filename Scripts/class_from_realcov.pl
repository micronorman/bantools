#!/usr/bin/env perl

use strict;
use warnings;

use Anorman::Counts;
use Anorman::Math::Common;
use Anorman::ESOM;
use Getopt::Long;

use Data::Dumper;

my ($input, $output, $split);
my $method = 'mean';
my $FH = \*STDOUT;

my %args = ( "input|i=s" => \$input, "output|o=s" => \$output, "split" => \$split, "method=s" => \$method );

&Getopt::Long::GetOptions( %args );

my $t = Anorman::Counts->new;
my $e = Anorman::ESOM->new;

$t->open( $input );

my $rows = $t->[0][0]->{'rows'};
my @coverages = ();

$t->add_row_stats('quick');

if ($split) {
	foreach my $col_i( $t->col_info ) {
		my $fn = $output . $col_i->{'name'}. ".cls";
		@coverages = map { $$_ } grep { ref $_ eq 'SCALAR' } @{ $t->cols( $col_i->{'_num'})->[0] };
		open ($FH, '>', $fn) or die "Could not open $fn for writing, $!";

		&cls_header;
		&calc_coverage(@coverages);
		close $FH;
	}
} else {
	@coverages = map { $_->{"_" . $method } } $t->row_info;

	&cls_header;
	&calc_coverage(@coverages);
}

sub calc_coverage {
	&Anorman::Math::Common::normalize_BoxCox( \@coverages, 0 );
	my $stats = &Anorman::Math::Common::stats_quick( @coverages );
	my ($min,$max) = @{ $stats }{ qw/_min _max/ };

	my $i = 1;
	foreach (@coverages){ my $class = int ( 31 * ( $_ - $min) / ($max - $min)); print $FH "$i\t$class\n";$i++ };
}

sub cls_header {
print $FH <<HEADER;
% $rows
%0        0       0     143
%1        0       0     175
%2        0       0     207
%3        0       0     239
%4        0      16     255
%5        0      48     255
%6        0      80     255
%7        0     112     255
%8        0     143     255
%9        0     175     255
%10       0     207     255
%11       0     239     255
%12      16     255     255
%13      48     255     223
%14      80     255     191
%15     112     255     159
%16     143     255     128
%17     175     255      96
%18     207     255      64
%19     239     255      32
%20     255     255       0
%21     255     223       0
%22     255     191       0
%23     255     159       0
%24     255     128       0
%25     255      96       0
%26     255      64       0
%27     255      32       0
%28     255       0       0
%29     223       0       0
%30     191       0       0
%31     159       0       0
HEADER

}
