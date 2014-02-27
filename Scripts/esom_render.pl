#!/usr/bin/env perl

use strict;
use warnings;

use Anorman::Common;
use Anorman::ESOM;
use Anorman::ESOM::ImageRenderer;

use Getopt::Long;
use Pod::Usage;

use GD;

my (	$bmfile,
	$clsfile,
	$force,
	$pngfile,
	$rgbname,
	$umxfile,
	$wtsfile,
	$zoom,
	$quiet
);

unless (@ARGV) {
	pod2usage( msg => 'Use --help for more information', verbose => 0 );
}

&GetOptions(
	'wts=s' 	=> \$wtsfile,
	'bm=s'		=> \$bmfile,
	'cls=s'		=> \$clsfile,
	'png=s'		=> \$pngfile,
	'rgb=s'		=> \$rgbname,
	'umx=s'		=> \$umxfile,
	'zoom=i'	=> \$zoom,
	'quiet'		=> \$quiet,
	'force'		=> \$force,
	'help'		=> sub { pod2usage( verbose => 1 ) },
	'manual' 	=> sub { pod2usage( verbose => 2 ) }
) or pod2usage( msg => 'Use --help for more information', verbose => 0 );

# Set vebosity
$Anorman::Common::VERBOSE = !$quiet;

# Initialize common ESOM object
my $e = Anorman::ESOM->new;


if (defined $wtsfile) {
	$e->load_weights($wtsfile);

	if (defined $umxfile) {
		unless ( -e $umxfile && !$force ) {
			my $umx = $e->umatrix;
			$umx->save($umxfile);
		} else {
			die "Could not write U-Matrix to $umxfile. Use --force to overwrite existing files\n";
		}
	}

} elsif (defined $umxfile) {
	$e->load_matrix($umxfile);
}

if (defined $pngfile) {
	# Initialize Image renderer
	my $ir = Anorman::ESOM::ImageRenderer->new( $e, colorscheme => $rgbname, zoom => $zoom );
	
	my $image = $ir->render;
	
	die "Could not write Image to $pngfile. Use --force to overwrite existing files\n" if (-e $pngfile && !$force);
	
	open ( my $FH ,'>', $pngfile ) or die "Could not open $pngfile, $!";	

	warn "Writing image to $pngfile...\n" unless $quiet;
	
	# Switch to binary output
	binmode $FH;
	
	print $FH $image->png;

	close $FH;
}

__END__

=head1 NAME

esom_render.pl -- ESOM Rendering Tool

=head1 SYNOPSIS

=over 8

=item B<esom_render.pl>
[-w I<file>]
[-l I<file>]
[-p I<file>]
[-b I<file>] 
[--quiet]
[--force]
[--help | --manual]

=back

=head1 OPTIONS

=over 4

=item B<-b, --bm>

Input file of best matches (*.bm)

=item B<-w, --wts>

Input file of ESOM weights (*.wts)

=item B<-c, --cls>

Input file of datapoint classifications (*.cls)

=item B<-r, --rgb>

Name of the color table to use

=item B<-u, --umx>

Input (or output) file with U-Matrix. If a wts-file is provided, the U-Matrix is generated and saved. Otherwise the U-Matrix is loaded from the umx-file

=item B<-p, --png>

Output file in which to save the rendered ESOM image

=item B<-z, --zoom>

Zoom factor (1-10)

=item B<--force>

Forces overwrite of existing files

=item B<-q, --quiet>

Silence all non-error output

=item B<-h, --help>

Display extended program information

=item B<-m, --manual>

Show the ESOM rendering tool manual

=back

=head1 DESCRIPTION

The ESOM Rendering Tool can render images of ESOMs. Although it significantly reduces the number of options

=head1 AUTHOR

Anders Norman, E<lt>lordnorman@gmail.comE<gt>

=head1 SEE ALSO

L<https://github.com/micronorman/bantools>

=cut
