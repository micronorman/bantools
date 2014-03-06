#!/usr/bin/env perl

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data::Algorithms::MahalanobisDistance;
use Anorman::ESOM;

use Getopt::Long;

use Data::Dumper;

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

$Anorman::Common::VERBOSE = 1;

if ($prefix) {
	$invcovarfile  = $prefix . "_" . $invcovarfile;
	$meansfile     = $prefix . "_" . $meansfile;

}

#die "$invcovarfile already exists. Use --force to ovewrite existing files\n" if !$force && -e $invcovarfile;
#die "$meansfile already exists. Use --force to overwrite existing files\n"   if !$force && -e $meansfile;
#die "You must specify either a Lrn-file or a Wts-file\n" unless (defined $lrnfile || defined $wtsfile);

#my $data;
my $esom = Anorman::ESOM->new;

if ($wtsfile) {
	$esom->load_weights($wtsfile);
	$esom->load_data( $lrnfile );	
	if ($cmxfile) {

		my %mhdist = ();

		$esom->load_class_mask($cmxfile);
		$esom->class_mask->index_classes;

		foreach my $class(@{ $esom->classes }) {
			next unless $class->index;
			my $name    = $class->name;
			my $members = $class->members;
			my $size = @{ $members };
			
			print "[ $name $size ]\n";
			my $matrix = $esom->weights->data->view_selection( $members );

			my $mh = Anorman::Data::Algorithms::MahalanobisDistance->new( $matrix->copy );
			$mhdist{ $class->index } = $mh;
		}

		if ($bmfile) {
			$esom->load_bestmatches( $bmfile );
			my $cls = $esom->data_classes;

			foreach my $i( 1 .. $esom->datapoints) {
				my $class = $cls->get_by_index( $i );
				my $dist = '-';

				if ($class) {
					$dist = $mhdist{ $class }->distance( $esom->training_data->get_by_index( $i ) );
				}
				print "$i\t$class\t$dist\n";
			}
		}	
	}
}
