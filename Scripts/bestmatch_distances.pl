#!/usr/bin/env perl

use strict;
use warnings;

use Anorman::ESOM::Parser;
use Anorman::ESOM::Grid;
use Anorman::Math::Common;
use Anorman::Data;
use Anorman::Data::Functions::VectorVector qw(vv_dist_euclidean);
use Getopt::Long;

my ($lrnfile,$wtsfile,$bmfile,$clsfile);

&GetOptions( 'lrnfile|l=s' => \$lrnfile,
	     'wtsfile|W=s' => \$wtsfile,
	     'bmfile|b=s'  => \$bmfile,
	     'clsfile|c=s' => \$clsfile
           );

die "$!, $lrnfile" unless -e $lrnfile;
die "$!, $wtsfile" unless -e $wtsfile;
die "$!, $bmfile" unless -e $bmfile;

my $lrn = Anorman::ESOM::Parser->new('lrn');
my $wts = Anorman::ESOM::Parser->new('wts');
my $bm  = Anorman::ESOM::Parser->new('bm');

warn "Loading lrn-file $lrnfile\n";
$lrn->open($lrnfile);
my $lrn_dp = $lrn->datapoints;
warn "Datapoints: ", $lrn_dp, "\n";

my $dims = $lrn->dim;
warn "Vector size: ", $lrn->dim, "\n";

warn "Loading bestmatches file $bmfile\n";
$bm->open($bmfile);

my $bm_dp   = $bm->size;
my $bm_cols = $bm->columns;
my $bm_rows = $bm->rows;

# file compatability sanity check
die "Number of bestmatches ( $bm_dp )does not match the number of data vectors ( $lrn_dp )" if ($lrn_dp != $bm_dp);

warn "Loading weights file $wtsfile\n";
$wts->open($wtsfile);

die "Error: different vector lengths in input and training data" unless $dims == $wts->dim;

my $cols = $wts->columns;
my $rows = $wts->rows; 

warn "Grid size [ $rows x $cols ]\n";

# grid dimensions sanity check
die "Bestmaches file has the wrong grid dimensions [ $bm_cols x $bm_rows ]" if ($bm_rows != $rows || $bm_cols != $cols);

my $bm_r  = $bm->data;
my $lrn_r = $lrn->data;
my $wts_r = $wts->data;

my @distances = ();
my $i;

my $grid = Anorman::ESOM::Grid::ToroidEuclidean->new;
$grid->rows( $rows );
$grid->columns( $cols );

# calculated euclidean distances between a vector and its bestmatch neuron
$i = -1;
while (++$i < $lrn->datapoints ) {
	my ($bm_x, $bm_y) = @{ $bm_r->[ $i ] };
	my $index = $grid->coords2index( $bm_x, $bm_y );
	
	$distances[ $i ] = vv_dist_euclidean( $lrn_r->view_row( $i ), $wts_r->view_row( $index ) );
}

my $stat = Anorman::Math::Common::stats_full(@distances);

print STDERR "min: $stat->{'_min'}\n";
print STDERR "max: $stat->{'_max'}\n";
print STDERR "mean: $stat->{'_mean'}\n";
print STDERR "stdev: $stat->{'_stdev'}\n";
print STDERR "median: $stat->{'_median'}\n";
# Normalize distances (square transformation followed by [0..1] transformation)
#Anorman::Math::Common::normalize_BoxCox(\@distances, 0.5, 1);
#Anorman::Math::Common::normalize_zero_to_one(\@distances);

my $FH = \*STDOUT;

if ($clsfile) {
	open ( $FH, '>', $clsfile) or die "Could not open $clsfile for writing, $!\n";
}

&cls_header( $FH );

$i = -1;
while (++$i < $lrn->datapoints) {
	my $class = int $distances[ $i ];
	$class = 31 if $class > 31;
	my $dp    = $bm->keys->[ $i ];
	print "$dp\t$class\n";
}

close $FH if $clsfile;

sub cls_header {
my $FH = shift;
print $FH <<HEADER;
% $lrn_dp
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

