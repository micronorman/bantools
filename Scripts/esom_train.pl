#!/usr/bin/env perl
#
use strict;
use warnings;

use Anorman::Common qw($VERBOSE);

use Anorman::ESOM;
use Anorman::ESOM::Config;
use Anorman::ESOM::File;
use Anorman::ESOM::SOM;
use Anorman::ESOM::Grid;
use Anorman::ESOM::Neighborhood;
use Anorman::ESOM::BMSearch;

use Getopt::Long qw( :config no_auto_abbrev no_ignore_case );
use Pod::Usage;
use POSIX qw(ceil);

$Anorman::Data::Config::PACK_DATA = $Anorman::ESOM::Config::PACK_MATRIX_DATA;

# Default options
my $EPOCHS       = 20;
my $BMSEARCH     = 'standard';
my $BMCONSTANT   = 8;
my $GRID         = 'toroid';
my $SCALE        = 6.5;
my $METHOD       = 'online';
my $NEIGHBORHOOD = 'gauss';
my $dk           = 0.15;
my $COOL_RADIUS  = 'lin';
my $COOL_LEARN   = 'lin';
my $INIT 	 = 'norm_mean_2std';
my $OUTPUT       = 'out';
my $RATIO;
my $optimize_ratio;

my $LRN_FILE     = '';
my $PRE_WEIGHTS  = '';

my ($ROWS,$COLS);

# get user defined options
&GetOptions(
	'columns|c=i'		=> \$COLS,
	'rows|r=i'		=> \$ROWS,
	'lrn|l=s'		=> \$LRN_FILE,
	'epochs|e=i'		=> \$EPOCHS,
	'scale|s=f'		=> \$SCALE,
	'algorithm|a=s'		=> \$METHOD,
	'bmconstant|bmc=i'	=> \$BMCONSTANT,
	'init|i=s'		=> \$INIT,
	'bmsearch|bms=s'	=> \$BMSEARCH,
	'bmconstant|bmc=i'	=> \$BMCONSTANT,
	'cool-radius|rc=s'	=> \$COOL_RADIUS,
	'cool-learn|lc=s'	=> \$COOL_LEARN,
	'grid|g=s'		=> \$GRID,
	'neighborhood|n=s'	=> \$NEIGHBORHOOD,
	'weights|w=s'		=> \$PRE_WEIGHTS,
	'ratio|r'		=> \$optimize_ratio,
	'K|k=f'			=> \$dk,
	'output|o=s'		=> \$OUTPUT,
	'verbose'		=> \$VERBOSE,
	'help|h'		=> sub { pod2usage( verbose => 1 ) },
	'manual'		=> sub { pod2usage( verbose => 2 ) }
) or pod2usage( msg => "\nuse --help for more information\n", verbose => 0 );

if ('' eq $LRN_FILE) {
	pod2usage( msg => "No lrn-file specified", verbose => 0 );
}

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

unless (defined $ROWS && defined $COLS) {
	$ROWS  = ceil( sqrt( ( $lrn->size * $SCALE ) / $RATIO ) );
	$COLS  = ceil( $ROWS * $RATIO );
}

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
warn "Init method: $INIT\n";

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
if ($PRE_WEIGHTS ne '') {

	# Add training grid from file
	$som->grid->load_weights($PRE_WEIGHTS);
} else {

	# Otherwise initialize randomized grid from input data
	$som->init( $INIT );
}

# run training
$esom->train( $som );

warn "Writing output files...\n";

# write output files
$esom->umatrix->save("$OUTPUT.epoch" . $som->epochs . ".umx");
$esom->weights->save("$OUTPUT.epoch" . $som->epochs . ".wts");
$esom->bestmatches->save("$OUTPUT.epoch" . $som->epochs . ".bm");

__END__
=pod

=head1 NAME

esom_train.pl - ESOM training tool

=head1 SYNOPSIS

=over 8

=item B<esom_train.pl> 

-l I<file>
[-w I<file>]
[-a I<STR>]
[-g I<STR>]
[-r]
[-s I<FLOAT>]
[-i I<STR>]
[-e I<INT>]
[-rc I<STR>]
[-lc I<STR>]
[-bms I<STR>]
[-bmc I<INT>]

=back

=head1 OPTIONS

=over 8

=item B<-l, --lrn> I<file>

lrn-file (*.lrn) with input data patterns

=item B<-w, --wts> I<file>

wts-file (*.wts) with weights to begin training with

=item B<-a, --algorithm> 

The training algorithm. Possible choices are:
C<online> (default),
C<slowbatch>,
C<kbatch>

=item B<-g, --grid>

The training grid type. Possible choices are:
C<toroid> (default),
C<toroid_man>,
C<toroid_max>

=item B<-i, --init>

Grid initialization method. Possible choices are:
C<zero>,
C<uni_min_max>,
C<uni_mean_2std>,
C<norm_mean_2std> (default),
C<pca>

=item B<-r, --ratio>

Optimize the ratio between number of rows and columns (based on eigenvalues). Otherwise a default 5/3 ratio is used

=item B<-s, --scale>

Scaling factor. Sets the number of grid neurons per data pattern (from the lrn-file). Default: 6

=item B<-e, --epochs>

The number of training epochs (default: 20)

=item B<-n, --neighborhood>

The neighborhood kernel function. Possible choices are:
C<bubble>,
C<cone>,
C<epan>,
C<gauss> (default),
C<mexhat> 

=item B<-rc, --cool-radius>

Cooling strategy for kernel radius. Choose between C<lin> (linear) or C<exp> (exponential) cooling

=item B<-lc, --cool-learn>

Cooling strategy for learning rate. (see -rc)

=item B<-bms, --bmsearch> 

The bestmatch search method. Possible choices are:
C<standard> (default),
C<constant>,
C<quick>,
C<faster>

=item B<-o, --output>

The output prefix. Will be used to generate names for the output wts-, umx- and bm-files. Default: C<out>

=back

=head1 AUTHOR

Anders Norman E<lt>lordnorman@gmail.comE<gt>

=head1 SEE ALSO

L<https://github.com/micronorman/bantools>

=cut
