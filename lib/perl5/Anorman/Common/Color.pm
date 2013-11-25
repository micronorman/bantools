package Anorman::Common::Color;

# A class to handle RGB colors, cuz, well yeah...

# Colors are stored as a blessed array reference ( [red, green, blue] )
# Each color value must be 0..255


use strict;
use warnings;

use Anorman::Common;

use overload
	'==' => \&_equals;

# A default set of colors I saw somewhere
my %PRESETS = (
	WHITE      => [255,255,255],
	LIGHT_GRAY => [192,192,192],
	GRAY       => [128,128,128],
	DARK_GRAY  => [ 64, 64, 64],
	BLACK      => [  0,  0,  0],
	RED        => [255,  0,  0],
	PINK       => [255,175,175],
	YELLOW     => [255,255,  0],
	ORANGE     => [255,200,  0],
	GREEN      => [  0,255,  0],
	BLUE       => [  0,  0,255],
	MAGENTA    => [255,  0,255],
	CYAN       => [  0,255,255]  
);

sub new {
	my $class = shift;

	trace_error("Wrong number of arguments") unless (@_ <= 1 || @_ == 3);

	my $self = [ 255,255,255 ];

	if (@_ == 3) {
		@{ $self } = @_;
	} elsif (@_ == 1) {
		if (ref $_[0] eq 'ARRAY') {
			trace_error("Array can only contain three values (red,green,blue)") unless 3 == scalar @{ $_[0] };
			@{ $self } = @{ $_[0] }; 
		} else {
			# Treat input as string
			my $string = uc( $_[0] );
			trace_error("String was empty") if $string eq '';

			if ($string =~ m/^#([0-9A-F]{2})([0-9A-F]{2})([0-9A-F]{2})$/) {
				@{ $self } = (hex($1),hex($2),hex($3));
			} else {
				trace_error("Invalid arguments") unless exists $PRESETS{ $string };
				$self = $PRESETS{ $string };
			}
		}
	}

	return bless ( $self, $class );
}

sub red {
	return $_[0]->[0] unless defined $_[1];
	$_[0]->[0] = $_[1];
}

sub green {
	return $_[0]->[1] unless defined $_[1];
	$_[0]->[1] = $_[1];
}

sub blue {
	return $_[0]->[2] unless defined $_[1];
	$_[0]->[2] = $_[1];
}

sub hex {
	return sprintf("%s%2.2X%2.2X%2.2X", '#', @{ $_[0] });
}

sub rgb {
	return @{ $_[0] };
}

sub hsv {
	my ($hue,$sat, $delta);

	my $Cmax = 0;
	my $Cmin = 1;
	my $Ci   = 0;
	my @RGB = map { $_ / 255 } @{ $_[0] };

	foreach (0..2) {
		my $oldCmax = $Cmax;

		$Cmax = $RGB[$_] > $Cmax ? $RGB[$_] : $Cmax;
		$Cmin = $RGB[$_] < $Cmin ? $RGB[$_] : $Cmin;
		$Ci   = $_ if $Cmax != $oldCmax;
	}

	$delta = $Cmax - $Cmin;

	if ($Ci == 0) {
		$hue = (($RGB[1] - $RGB[2]) / $delta) % 6;
	} elsif ($Ci == 1) {
		$hue = (($RGB[2] - $RGB[0]) / $delta) + 2;
	} else {
		$hue = (($RGB[0] - $RGB[1]) / $delta) +4;
	}
	
	$hue *= 60;
	$sat  = ($delta == 0) ?  0 : ($delta / $Cmax);

	return ($hue, $sat, $Cmax);
}

sub hsl {
	my ($hue,$sat,$light, $delta);

	my $Cmax = 0;
	my $Cmin = 1;
	my $Ci   = 0;
	my @RGB = map { $_ / 255 } @{ $_[0] };

	foreach (0..2) {
		my $oldCmax = $Cmax;

		$Cmax = $RGB[$_] > $Cmax ? $RGB[$_] : $Cmax;
		$Cmin = $RGB[$_] < $Cmin ? $RGB[$_] : $Cmin;
		$Ci   = $_ if $Cmax != $oldCmax;
	}

	warn "Cmax: $Cmax Cmin: $Cmin Ci: $Ci Delta: $delta\n";
	$delta = $Cmax - $Cmin;

	if ($Ci == 0) {
		$hue = (($RGB[1] - $RGB[2]) / $delta) % 6;
	} elsif ($Ci == 1) {
		$hue = (($RGB[2] - $RGB[0]) / $delta) + 2;
	} else {
		$hue = (($RGB[0] - $RGB[1]) / $delta) +4;
	}
	
	$hue   *= 60;
	$light  = ($Cmax + $Cmin) / 2;
	$sat    = ($delta == 0) ?  0 : $delta / (1 - abs(2 * $light -  1));

	return ($hue, $sat, $light);

}

sub _equals {
	my ($self, $other) = @_;

	foreach (0..2) {
		return undef if $self->[$_] != $other->[$_];
	}

	return 1;
}

1;
