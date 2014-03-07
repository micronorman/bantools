package Anorman::ESOM::File::Wts;

use strict;
use warnings;

use parent 'Anorman::ESOM::File::Grid';

use Anorman::Common;

sub new {
	my $that = shift;
	my $class = ref $that || $that;

	my $self  = $class->SUPER::new();

	if (@_ == 1) {
		$self->filename( shift );
	} elsif (@_ == 3) {
		my ($rows, $columns, $dims ) = @_;

		$self->_init( $rows, $columns, $dims );
	}

	return $self;
}

sub _usage {
	my $usage = "\n\nUsage:";
	my $prefix = "\n" . __PACKAGE__ . "::new( ";

	
	return $usage . $prefix . " filename )" . $prefix . " rows, columns, dims )";
}

1;
