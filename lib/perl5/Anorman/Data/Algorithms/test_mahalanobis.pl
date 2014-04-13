#!/usr/bin/env perl

use strict;
use warnings;

use Anorman::ESOM;
use Anorman::Data;
use Anorman::Data::Algorithms::MahalanobisDistance;
use Anorman::Math::Distances;

my $e = Anorman::ESOM->new;
my $lrn = $e->load_data($ARGV[0]);
my $M = $lrn->data;

my $mhdist = Anorman::Data::Algorithms::MahalanobisDistance->new( $M );
my   $dist = Anorman::Math::Distances->new(); 
my     $DF = $mhdist->get_function;

$dist->distance_function( $DF );
$dist->data( $M->view_sample(20) );

print "Mahalanobis Distance Matrix:\n";
print $dist->get_distances;

