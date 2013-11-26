#!/usr/bin/env perl
#
use strict;
use warnings;

use Anorman::Common qw($VERBOSE);

use Anorman::ESOM;
use Anorman::ESOM::File;
use Anorman::ESOM::SOM;
use Anorman::ESOM::Grid;
use Anorman::ESOM::Neighborhood;
use Anorman::ESOM::BMSearch;

use Getopt::Long;
use POSIX qw(ceil);

# Default options
my $EPOCHS       = 20;
my $BMSEARCH     = 'standard';
my $BMCONSTANT   = 8;
my $GRID         = 'toroid';
my $SCALE        = 6;
my $METHOD       = 'kbatch';
my $NEIGHBORHOOD = 'gauss';
my $dk           = 0.15;
my $COOL_RADIUS  = 'lin';
my $COOL_LEARN   = 'lin';
my $OUTPUT       = 'out';
my $RATIO;
my $optimize_ratio;

my $LRN_FILE     = '';
my $PRE_WEIGHTS  = '';




# get user defined options
&GetOptions(
	'lrn|l=s'		=> \$LRN_FILE,
	'epochs|e=i'		=> \$EPOCHS,
	'scale|s=i'		=> \$SCALE,
	'method|m=s'		=> \$METHOD,
	'bmconstant|bmc=i'	=> \$BMCONSTANT,
	'bmsearch|bms=s'	=> \$BMSEARCH,
	'cool-radius|rc=s'	=> \$COOL_RADIUS,
	'cool-learn|lr=s'	=> \$COOL_LEARN,
	'grid|g=s'		=> \$GRID,
	'neighborhood|n=s'	=> \$NEIGHBORHOOD,
	'weights|w=s'		=> \$PRE_WEIGHTS,
	'ratio|r'		=> \$optimize_ratio,
	'K|k=f'			=> \$dk,
	'output|o=s'		=> \$OUTPUT,
	'verbose'		=> \$VERBOSE
);

my $esom = Anorman::ESOM->new();

# open input data
my $lrn = Anorman::ESOM::File::Lrn->new();

$lrn->load( $LRN_FILE );

warn "Datapoints: ", $lrn->size, "\n";
warn "Vector size: ", $lrn->dimensions, "\n";

$esom->add_new_data( $lrn );

# intialize training
my $som; 

# Initialize method
print STDERR "Method: $METHOD";

if ($METHOD eq 'kbatch') {
	$som = Anorman::ESOM::SOM::KBatch->new;
	my $K = ceil( $lrn->size * $dk );
	$som->K( $K  );	
	print STDERR " (map update at every $K positions)";
} elsif ($METHOD eq 'online') {
	$som = Anorman::ESOM::SOM::Online->new;
} elsif ($METHOD eq 'slowbatch') {
	$som = Anorman::ESOM::SOM::SlowBatch->new;
} else { die "unkown training method" }

warn"\n";

# Initialize neighborhood (default is gaussian)
if ($NEIGHBORHOOD eq 'mexhat') {
	$som->neighborhood( Anorman::ESOM::Neighborhood::MexicanHat->new );
} elsif ($NEIGHBORHOOD eq 'cone') {
	$som->neighborhood( Anorman::ESOM::Neighborhood::Cone->new );
} elsif ($NEIGHBORHOOD eq 'epanechnikov') {
	$som->neighborhood( Anorman::ESOM::Neighborhood::Epanechnikov->new );
} elsif	($NEIGHBORHOOD eq 'bubble') {
	$som->neighborhood( Anorman::ESOM::Neighborhood::Bubble->new );
}

warn "Neighborhood: $NEIGHBORHOOD\n";

# load data into trainer
$som->data( $lrn->data );
$som->keys( $lrn->keys );

# calculate arbitrary grid size based on number of datapoints
$RATIO = $optimize_ratio ? ($som->descriptives->first_eigenvalue  / $som->descriptives->second_eigenvalue) : (5 / 3);

warn "Grid dimension ratio: ", sprintf("%.2f", $RATIO), "\n";

my $ROWS  = ceil( sqrt( ( $lrn->size * $SCALE ) / $RATIO ) );
my $COLS  = ceil( $ROWS * $RATIO );
my $RS    = ceil( $ROWS / 2 );

# Intialize grid
if ($GRID eq 'toroid') {
	$som->grid( Anorman::ESOM::Grid::ToroidEuclidean->new( $ROWS, $COLS, $lrn->dimensions ) );
} elsif ($GRID eq 'toroid_man') {
	$som->grid( Anorman::ESOM::Grid::ToroidManhattan->new( $ROWS, $COLS, $lrn->dimensions ) );
} elsif ($GRID eq 'toroid_max') {
	$som->grid( Anorman::ESOM::Grid::ToroidMax->new( $ROWS, $COLS, $lrn->dimensions ) );
} else {
	die "Invalid grid type: $GRID\n";
}

warn "Grid: $GRID\n";

# set epochs
$som->epochs( $EPOCHS );
warn "Epochs: $EPOCHS\n";

# set cooling functions
if ($COOL_RADIUS eq 'lin') {
	$som->radius_cooling( Anorman::ESOM::Cooling::Linear->new( $RS, $EPOCHS,1) );
	warn "Radius: $RS -> 1 (linear cooling)\n";
} elsif ($COOL_RADIUS eq 'exp') {
	$som->radius_cooling( Anorman::ESOM::Cooling::Exponential->new( $RS, $EPOCHS, 1 ) );
	warn "Radius: $RS -> 1 (exponential cooling)\n";
}

if ($COOL_LEARN eq 'lin') {
	$som->rate_cooling( Anorman::ESOM::Cooling::Linear->new(1,$EPOCHS, 0.1) );
	warn "Learning rate: 1 -> 0.1 (linear cooling)\n";
} elsif ($COOL_LEARN eq 'exp') {
	$som->rate_cooling( Anorman::ESOM::Cooling::Exponential->new(1,$EPOCHS, 0.1) );
	warn "Learning rate: 1 -> 0.1 (exponential cooling)\n";
}

# search method
if ($BMSEARCH eq 'standard') {
	$som->BMSearch( Anorman::ESOM::BMSearch::Simple->new );
} elsif ($BMSEARCH eq 'constant') {
	$som->BMSearch( Anorman::ESOM::BMSearch::Local::Constant->new );
} elsif ($BMSEARCH eq 'quick') {
	$som->BMSearch( Anorman::ESOM::BMSearch::Local::QuickLearning->new );
} elsif ($BMSEARCH eq 'faster') {
	$som->BMSearch( Anorman::ESOM::BMSearch::Local::MuchFasterLearning->new );
}

warn "Search Method: $BMSEARCH\n";
warn "Search Constant: $BMCONSTANT\n";

$som->BMSearch->constant( $BMCONSTANT );

# Initialize trainer
if (defined $PRE_WEIGHTS) {

	# Add training grid from file
	$som->grid->load_weights($PRE_WEIGHTS);
} else {

	# Otherwise initialize randomized grid from input data
	$som->init;
}

# run training
$esom->train( $som );

# write output files
$esom->umatrix->save("$OUTPUT.epoch" . $som->epochs . ".umx");
#$esom->weights->save("$OUTPUT.epoch" . $som->epochs . ".wts");
#$esom->bestmatches->save("$OUTPUT.epoch" . $som->epochs . ".bm");
