#!/usr/bin/env perl

use strict;
use warnings;

use Anorman::Data::Algorithms::MahalanobisDistance;
use Anorman::ESOM;

use Getopt::Long;

my ($wtsfile, $bmfile, $lrnfile, $cmxfile, $force, $prefix, $clsfile);

my $invcovarfile = "invcovar.txt";
my $meansfile    = "means.txt";

&GetOptions(
	'bm=s'       => \$bmfile,
	'cls|c=s'    => \$clsfile,
	'cmx|m=s'    => \$cmxfile,
	'lrn=s'      => \$lrnfile,
	'force'      => \$force,
	'wts|w=s'    => \$wtsfile,
	'prefix=s'   => \$prefix,
	'invcovar=s' => \$invcovarfile,
	'means=s'    => \$meansfile
);

if ($prefix) {
	$invcovarfile  = $prefix . "_" . $invcovarfile;
	$meansfile     = $prefix . "_" . $meansfile;

}

die "$invcovarfile already exists. Use --force to ovewrite existing files\n" if !$force && -e $invcovarfile;
die "$meansfile already exists. Use --force to overwrite existing files\n"   if !$force && -e $meansfile;
die "You must specify either a Lrn-file or a Wts-file\n" unless (defined $lrnfile || defined $wtsfile);

my $data;
my $esom = Anorman::ESOM->new;

if (defined $lrnfile) {
	warn "Opening $lrnfile...\n";
	$esom->open($lrnfile);

	# Extract data matrix
	$data = $esom->training_data->data;

	if (defined $clsfile) {
		warn "Opening $clsfile...\n";
		$esom->open($clsfile);
	} elsif (defined $bmfile && defined $clsfile) {
		warn "Opening $bmfile...\n";
		$esom->open( $bmfile, 'bm' );
	
		warn "Opeing $cmxfile...\n";
		$esom->open( $cmxfile );
		
		# generate classes from bestmatches and class mask
		$esom->classify_bestmatches;
	}

} elsif (defined $wtsfile) {
	warn "Opening $wtsfile...\n";
	$esom->open($wtsfile);

	if (defined $cmxfile) {
		warn "Opening $cmxfile...\n";
		$esom->open( $cmxfile, 'cmx' );
	}

	$data = $esom->grid->get_weights;

} else {
	# Nothing yet
}

my @class_names = ('All');
my @mhdists     = ( Anorman::Data::Algorithms::MahalanobisDistance->new( $data ) );
my @data        = ();

if (defined $lrnfile && (defined $clsfile || defined $bmfile && defined $cmxfile)) {

	if (defined $clsfile) {
		warn "Opening $clsfile...\n";
		$esom->open($clsfile);
	} else {
		
	}

	foreach my $class(@{ $esom->classes }) {
		next if $class->index == 0;

		my $name    = $class->name;
		my $members = $class->members;

		warn "$name: ", scalar @{ $members }, "\n";

		# Making a copy ensures fast dot-product calculations during matrix factorizations
		my $matrix = $esom->data->data->view_selection( $members, undef )->copy;
			
		next if $matrix->rows <= 1;

		push @class_names, $class->name;
		push @data, $matrix;
		push @mhdists, Anorman::Data::Algorithms::MahalanobisDistance->new( $matrix );
	}
} elsif (defined $wtsfile) {
	warn "Opening $wtsfile...\n";

	$esom->open($wtsfile);

	push @mhdists, Anorman::Data::Algorithms::MahalanobisDistance->new( $esom->grid->get_weights );
	push @class_names, 'Weights';
}

my $FH;

my $header = '';

$header .= "%" . scalar @mhdists . " \n";
open ($FH, '>', $invcovarfile ) or die ("Could not open file $invcovarfile for writing, $!");

my $i = -1;
while ( ++$i < @class_names ) {
	print $FH ">\[$class_names[$i]\]\n";
	print $FH $mhdists[ $i ]->get_inverse_covariance;
	print $FH "\n";
}

close $FH;

open ($FH, '>', $meansfile ) or die ("Could not open file $meansfile for writing, $!");

$i = -1;
while ( ++$i < @class_names ) {
	print $FH "\[$class_names[$i]\]\n";
	print $FH join ("\n", @{ $mhdists[ $i ]->get_means }), "\n";
	print $FH "\n";
}

close $FH;

