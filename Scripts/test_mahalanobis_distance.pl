#!/usr/bin/env perl

# Implements Mahalanobis distance in ESOM vector projection
# DM(x) = sqrt( (x - µ)^T * S^-1 * (x - µ) ), where x is a multivariate
# vector, S is the covariance matrix and µ is the mean vector of the set of
# grid neurons
#
# read more at http://en.wikipedia.org/wiki/Mahalanobis_distance
# Anders Norman September 2013, lordnorman@gmail.com

use strict;
use warnings;

use Anorman::Data;
use Anorman::Data::LinAlg::Algebra qw( inverse );
use Anorman::Data::LinAlg::Property qw( :matrix );
use Anorman::Data::Algorithms::MahalanobisDistance;
use Anorman::ESOM;

use Getopt::Long;
use Scalar::Util qw(looks_like_number);

use vars qw($VERSION);

$VERSION = '0.5.8';

my ($input_file, $invcovarfile, $meansfile, $lrnfile, $bmfile, $clsfile, $help, $version);

# parse user input
&usage if @ARGV == 0;

&GetOptions(
	'lrn=s'      => \$lrnfile,
	'input=s'    => \$input_file,
	'invcovar=s' => \$invcovarfile,
	'means=s'    => \$meansfile,
	'bmfile=s'   => \$bmfile,
	'clsfile=s'  => \$clsfile,
	'help'       => \$help,
	'version'    => \$version
) or &usage;

&help if $help;

die "Version: $VERSION\n" if $version;
warn ("No inverse covariance matrix file defined\n") && &usage unless defined $invcovarfile;
warn ("No means file defined\n") && &usage unless defined $meansfile;
warn ("No lrn-file defined\n") && &usage unless defined $lrnfile;

my $esom = Anorman::ESOM->new;

if (defined $bmfile && !defined $clsfile || !defined $bmfile && defined $clsfile) {
	die "Must define both a BestMatches (cls) file and a BestMatches (bm) file";
}

my ($means, $inv_covar);
my $FH;

if ($invcovarfile) {
	warn "Opening inverse covariance matrix file $invcovarfile...\n";

	my $matrix = [];

	open ( $FH, '<', $invcovarfile ) or die ("Could not open file $invcovarfile for reading, $!");

	while (defined (my $line = <$FH>)) {
		chomp $line;
		push @{ $matrix }, [ split (/\t/, $line) ]; 
	}

	close $FH;

	$inv_covar = Anorman::Data->packed_matrix( $matrix );
}

if ($meansfile) {
	warn "Opening means vector file $meansfile...\n";

	my $array = [];

	open ( $FH, '<', $meansfile );

	while (defined (my $line = <$FH>)) {
		chomp $line;
		next unless looks_like_number($line);
		push @{ $array }, $line;
	}

	$means = Anorman::Data->packed_vector( $array );

	close $FH;
}

my $mhdist = Anorman::Data::Algorithms::MahalanobisDistance->new;

$mhdist->set_inverse_covariance( $inv_covar );
$mhdist->set_means( $means );

warn "Opening $lrnfile...\n";
$esom->open($lrnfile, 'lrn' );
warn "Calculating Mahalanobis distances...\n";

# generate classes
$esom->generate_jet_classes;
$esom->init;

# print output
print $esom->cls_header_string;

foreach my $dp( $esom->datapoints ) {
	my $vector     = $dp->vector;
	my $key        = $dp->key;
	my $md         = int $mhdist->MD( $vector );

	$md = 31 if $md > 31;

	print "$key\t$md\n";
}


# subroutines 

sub usage {
	# graceful exit with usage information;
	warn "Usage: $0 [OPTIONS] --lrnfile LrnFile.lrn --incovar invcovar.txt --means means.txt\n";
	warn "Computes Mahalanobis distances between a set of data vectors and an existing group of vectors defined through a inverse covariance matrix and a set of mean values\n";
	warn "Use --help for more information\n";
	exit 1;
}

sub help {
	die "You wish...\n";
}


