package Anorman::ESOM::ImageRenderer;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Common::Color;
use Anorman::ESOM::Config;
use Anorman::ESOM::File::ColorTable;
use Anorman::ESOM::UMatrixRenderer;
use Anorman::ESOM::BestMatchRenderer;

use GD;

use List::Util qw(max);

use Data::Dumper;

my %DEFAULTS = (
	'zoom'	 	=> 1,
	'colorscheme' 	=> undef,
	'background'	=> Anorman::ESOM::UMatrixRenderer->new,
	'foreground'	=> Anorman::ESOM::BestMatchRenderer->new,
	'bmsize' 	=> 1,
	'clipping'	=> undef,
	'clip'		=> 1.0,
	'image'		=> undef,
	'tiled'		=> 1,
	'colors'	=> Anorman::ESOM::File::ColorTable->new
);

sub new {

        my $that  = shift;
	my $class = ref($that) || $that;

	my $self = {};

	%{ $self } = %DEFAULTS;

	bless ($self, $class);


	my ($esom, %opt) = @_;

	if (defined $esom) {
		$self->esom( $esom );
	} 

	if (%opt) {
		while (my ($k,$v) = each %opt) {
			trace_error("Unknown option $k") if !exists $DEFAULTS{ $k };
			$self->{ $k } = $v;
		}
	}	

	if (defined $self->{'colorscheme'}) {
		$self->colorscheme( $self->{'colorscheme'} );
	} else {
		foreach my $i( 0 .. 255) {
			$self->{'colors'}->data->add( Anorman::Common::Color->new($i,$i,$i) );
		}
	}

	return $self;
}

sub render {
	my ($self, $fn) = @_;

	warn "Rendering background...\n" if $VERBOSE;
	$self->_zoom_background;
	$self->_draw_background;
	$self->_clone_bg_image;
	$self->_tile_background;
	$self->_clone_image;

	warn "Rendering foreground...\n" if $VERBOSE;
	$self->{'foreground'}->render( $self );

	return $self->{'image'};
}

sub image {
	my $self = shift;

	return $self->{'image'};
}

sub zoom { $_[1] ? $_[0]->{'zoom'} = $_[1] : $_[0]->{'zoom'} }

sub colorscheme {
	my ($self, $scheme) = @_;

	if (defined $scheme) {
		my $colorfile = $Anorman::ESOM::Config::COLORS_PATH . $scheme . ".rgb";

		trace_error("Color Table $colorfile could not be found") unless -e $colorfile;

		$self->{'colors'}->load($colorfile);
		$self->{'colorscheme'} = $scheme;
	} else {
		return $self->{'colorscheme'}
	}
}

sub bmsize {
	...
}

sub clip {
	...
}

sub tiled { $_[0]->{'tiled'} }

sub esom {
	my ($self, $esom) = @_;

	if (defined $esom) {
		trace_error("Arguement error. Not an ESOM object") unless $esom->isa("Anorman::ESOM");

	
		if (defined $esom->_umx) {
			$self->{'matrix'} = $esom->_umx->data;

		} else {
			$self->{'matrix'} = $self->{'background'}->render( $esom->grid );
		}

		$self->{'height'} = $esom->rows;
		$self->{'width'}  = $esom->columns;
		$self->{'esom'}   = $esom;
	} else {
		return $self->{'esom'};
	}		
}

sub render_background {
	my $self = shift;
	
	if (defined $self->{'esom'}) {
		my $esom = $self->{'esom'};
		if (defined $self->{'esom'}->grid) {
			if (defined $self->{'background'}) {
				$self->{'background'}->render( $esom );
			}
		} else {
			trace_error("No grid in ESOM, nothing to render");
		}
	} else {
		trace_error("No ESOM loaded, nothing to render");
	}
}

sub _clone_bg_image {
	my $self = shift;
	if (defined $self->{'bg_image'}) {
		$self->{'cloned_bg_image'} = $self->{'bg_image'}->clone;
	}
}

sub _clone_image {
	my $self = shift;
	if (defined $self->{'tiled_image'}) {
		$self->{'image'} = $self->{'tiled_image'}->clone;
	}
}

sub _draw_background {
	my $self   = shift;
	my $matrix = $self->{'zoomed_matrix'};

	my $bg_image;

	if (defined $matrix) {
		my $colors = $self->{'colors'}->data;
		my $num_colors = $colors->size;

		my $h = max( 1, $matrix->rows );
		my $w = max ( 1, $matrix->columns );

		$bg_image  = GD::Image->new( $w, $h );

		# Allocate colors
		my $i = -1;
		while ( ++$i < $num_colors ) {
			$bg_image->colorAllocate( $colors->[ $i ]->rgb );
		}	

		my $y = -1;
		while ( ++$y < $h ) {
			my $x = -1;
			while ( ++$x < $w ) {
				my $local_val = $matrix->get_quick( $y, $x );
				my $color_i   = int ($local_val * $num_colors );

				$bg_image->setPixel($x, $y, $color_i );
			}
		}
	} else {
		trace_error("No zoomed matrix present");
	}

	$self->{'bg_image'} = $bg_image;	
}

sub _tile_background {
	my $self  = shift;

	if (defined $self->{'cloned_bg_image'}) {
		my $cloned_bg_image = $self->{'cloned_bg_image'};

		# Get image dimensions
		my ($w, $h) = $cloned_bg_image->getBounds;

		# Allocate tiled image
		my $tiled_image = GD::Image->new( 2 * $w, 2 * $h );

		# Tile image
		$tiled_image->copy( $cloned_bg_image, 0 , 0 , 0, 0, $w, $h );
		$tiled_image->copy( $cloned_bg_image, $w, 0 , 0, 0, $w, $h );
		$tiled_image->copy( $cloned_bg_image, 0 , $h, 0, 0, $w, $h );
		$tiled_image->copy( $cloned_bg_image, $w, $h, 0, 0, $w, $h );

		$self->{'tiled_image'} = $tiled_image;
	}
}

sub _zoom_background {
	my $self   = shift;
	my $zoom   = $self->{'zoom'};
	my $matrix = $self->{'matrix'};

	if (defined $matrix) {
		if ($self->{'zoom'} > 1) {
			my $zoomed_matrix = $matrix->like( $self->{'height'} * $zoom, 
							   $self->{'width'}  * $zoom );

			my $shift = int ($zoom / 2);

			my $h = $self->{'height'};
			my $w = $self->{'width'};

			my ($ih,$fx,$fy,$ul,$ur,$ll,$lr);

			if ($self->{'tiled'}) {
				my $y = -1;
				while ( ++$y < $h ) {
					my $x = -1;
					while ( ++$x < $w ) {
						$ul = $matrix->get_quick($y, $x);

						$ur = $matrix->get_quick($y, ($x + 1) % $w);
						$ll = $matrix->get_quick(($y + 1) % $h, $x);
						$lr = $matrix->get_quick(($y + 1) % $h, ($x + 1) % $w);

						my $yz = -1;
						while ( ++$yz < $zoom ) {
							$fy = $yz / $zoom;

							my $xz = -1;
							while ( ++$xz < $zoom ) {
								$fx = $xz / $zoom;

								$zoomed_matrix->set_quick((($y * $zoom) +$yz 
									+ $shift) % ($h * $zoom),
									(($x * $zoom) + $xz + $shift) % ($w * $zoom),
									((1 - $fy) * (((1 - $fx) * $ul)
									+ ($fx * $ur)))
									+ ($fy * (((1 - $fx) * $ll)
									+ ($fx * $lr))));
							}
						} 
					}
				}
			} else {
				...
			}

			$self->{'zoomed_matrix'} = $zoomed_matrix;
		} else {
			$self->{'zoomed_matrix'} = $matrix->copy;
		}
	} else {
		trace_error("No height matrix present");
	}
}

1;

