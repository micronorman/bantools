package Anorman::ESOM::BestMatchRenderer;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Common::Color;

use Data::Dumper;

sub new {
	my $that  = shift;
	my $class = ref $that || $that;

	my %opt = @_;

	my $self = { 	'bmsize' => 1,
			'circle' => undef,
			'classification' => undef,
			'favouritecolor' => Anorman::Common::Color->new('WHITE')
	};

	if (%opt) {
		while (my($k,$v) = each %opt) {
			next unless exists $self->{ $k };
			$self->{ $k } = $v;
		}
	}

	return bless ( $self, $class );
}

sub render {
	my ($self, $renderer) = @_;

	my ($size, $Index);
	
	my $esom = $renderer->esom;

	if (defined (my $bestmatches = $esom->bestmatches)) {
		my $zoom = $renderer->zoom;
		my $w 	 = $esom->columns * $zoom;
		my $h    = $esom->rows    * $zoom;

		$self->{'gd'} = $renderer->image;
		
		# Render bestmatches
		my $i = -1;
		while ( ++$i < $bestmatches->data->size ) {
			my $bm    = $bestmatches->data->get( $i );
			my $index = $bm->index;
			my $size  = $zoom <= 2 ? $zoom * $self->{'bmsize'} : ($zoom - 2) * $self->{'bmsize'};
			my $x     = $bm->column * $zoom;
			my $y     = $bm->row    * $zoom;

			my @options = ($size, $size, $index, $renderer);

			$self->_draw_bestmatch( $x, $y, @options);
			
			# Draw other quadrants in toroid mode
			if ($renderer->tiled) {
				$self->_draw_bestmatch(($x + $w) % (2 * $w), $y                  , @options);
				$self->_draw_bestmatch($x                  , ($y + $h) % (2 * $h), @options);
				$self->_draw_bestmatch(($x + $w) % (2 * $w), ($y + $h) % (2 * $h), @options);
			}
		}
	}
}

sub classification {
	my $self = shift;
	return unless defined $_[0];
	$self->{'classification'} = $_[0] if $_[0]->isa("Anorman::ESOM::File::Cls");
}

sub _draw_bestmatch {
	my $self = shift;
	my ($x, $y, $sizex, $sizey, $index, $renderer) = @_;

	my $c = $self->_get_color($index);

	if ($self->{'circle'}) {
		$self->{'gd'}->filledEllipse($x, $y, $sizex, $sizey, $c); 
	} else {
		$self->{'gd'}->filledRectangle( $x, $y, $x + $sizex - 1, $y + $sizey - 1, $c );
	}
}

sub _get_color {
	my ($self,$index) = @_;

	my $gd = $self->{'gd'};
	my $c  = $self->{'favouritecolor'};

	# Apply class color if a classification table is present
	if (defined (my $cls = $self->{'classification'})) {
		my $class_i = $cls->get_by_index( $index );
		my $class   = $cls->classes->get( $class_i );

		$c = $class->color if defined $class->color;
	}

	# Return index of existing- or newly allocated color	
	return $gd->colorResolve( $c->rgb );
}

1;
