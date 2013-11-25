#!/usr/bin/env perl

use strict;
use warnings;

# import common verbosity flag
use Anorman::Common qw($VERBOSE);

use Anorman::ESOM;
use Getopt::Long;

my ($lrnfile,$wtsfile,$bmfile,$quiet);

&GetOptions( 'lrn=s'	 => \$lrnfile,
	     'wts=s'	 => \$wtsfile,
	     'bm=s'	 => \$bmfile,
	     'quiet'     => \$quiet
           );

$VERBOSE = !$quiet;

die "File $lrnfile not found" unless -e $lrnfile;
die "File $wtsfile not found" unless -e $wtsfile;

my $e = Anorman::ESOM->new;

my $lrn = Anorman::ESOM::File::Lrn->new( $lrnfile );
my $wts = Anorman::ESOM::File::Wts->new( $wtsfile );

# load data
$lrn->load;
$e->add_new_data( $lrn );

# load weights
$wts->load;
$e->add_new_data( $wts );

print $e if $VERBOSE;

# Write bestmatches to file
$e->bestmatches->save( $bmfile );
