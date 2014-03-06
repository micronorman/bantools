#!/usr/bin/env perl

use strict;
use warnings;

# import common verbosity flag
use Anorman::Common qw($VERBOSE);

use Anorman::ESOM;
use Getopt::Long qw( :config no_auto_abbrev no_ignore_case );
use Pod::Usage;

my ($lrnfile,
    $wtsfile,
    $cmxfile,
    $clsfile,
    $distances,
    $bmfile,
    $quiet,
    );

my %distances = ( euc => 'euclidean',
                  man => 'manhattan',
		  mahal => 'mahalanobis'
		);

# Parse user arguments
&GetOptions( 'l|lrn=s'  => \$lrnfile,
             'M|manual' => sub { pod2usage( verbose => 2 ) },
             'd|dist=s' => \$distances,  
	     'w|wts=s'  => \$wtsfile,
             'm|cmx=s'  => \$cmxfile,
	     'b|bm=s'   => \$bmfile,
             'c|cls=s'  => \$clsfile,
	     'q|quiet'  => \$quiet,
             'h|help'   => sub { pod2usage( verbose => 1 ) }
           ) or pod2usage( exit => 1, verbose => 0 );

$VERBOSE = !$quiet;

# Argument error handling
my $err_msg = '';

$err_msg .= "\nNo wts-file specified" if (!$wtsfile);
$err_msg .= "\nA cls-file MUST be specified when providing a cmx-file" if ($cmxfile && !$clsfile);
$err_msg .= "\nA cmx-file MUST be specified when providing a cls-file" if ($clsfile && !$cmxfile); 
$err_msg .= "\nAn output bm-file MUST be specified when providing a lrn-file" if ($lrnfile && !$bmfile);

pod2usage( msg => $err_msg . "\n" , verbose => 0 ) if $err_msg ne '';

# initialize an ESOM object
my $esom = Anorman::ESOM->new;

# Load weights into ESOM
$esom->load_weights( $wtsfile );

if ($lrnfile) {
	# Load training data into ESOM
	$esom->load_data( $lrnfile );

	# Project training data onto grid and save bm-file
	unless ( $distances ) {
		$esom->bestmatches->save( $bmfile );
	} else {
		$esom->bestmatch_distances->save( $bmfile );
	}
} else {
	# Load bestmatches into ESOM
	$esom->load_bestmatches( $bmfile );
}

if ($cmxfile) {
	my $cmx = Anorman::ESOM::File::ClassMask->new( $cmxfile ) if $cmxfile;
	$cmx->load;
	$esom->add_new_data( $cmx );
	
	# Classify bestmatches and save a cls-file
	$esom->data_classes->save( $clsfile );
}

__END__

=pod

=head1 NAME

esom_project.pl - ESOM projection tool

=head1 SYNOPSIS

=over 8

=item B<esom_project.pl>

B<-w> I<file>
[B<-l> I<file>]
[B<-b> I<file>]
[B<-m> I<file>]
[B<-c> I<file>]
[B<-q>]
[B<-h>]

=back


=head1 OPTIONS

=over 4

=item B<-w, -wts> I<file>

Weights file (*.wts) with trained ESOM map

=item B<-l, --lrn> I<file>

Training file (*.lrn) with data patterns

=item B<-b, --bm> I<file>

Bestmatches file (*.bm) with positions of the closest matched neuron

=item B<-m, --cmx> I<file>

Class Mask file (*.cmx) with classifications of ESOM grid positions

=item B<-c, --cls> I<file>

Classes file (*.cls) with classifications of data points

=item B<-q, --quiet>

Mute standard error output

=item B<-h, --help>

Displays brief help information and exits

=item B<-M, --man>

Displays the ESOM projection tool manual

=back

=head1 EXAMPLES

=head2 Example 1: Projecting data patterns onto trained ESOM

This is awesome

=head1 DESCRIPTION 

B<project_esom.pl> a tool for projecting and classifying training data onto an existing ESOM grid. It's pretty awesome

=head2 Projecting data patterns

Projecting data patterns onto an ESOM grid entails measuring euclidean distances. Again this is A-W-E-S-O-M-E!

=head2 Classifying bestmatches

Classifying is also awesome!

=head1 AUTHOR

Anders Norman, E<lt>lordnorman@gmail.comE<gt>

=head1 SEE ALSO

L<https://github.com/micronorman/bantools>

=cut


