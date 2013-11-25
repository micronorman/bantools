package Anorman::ESOM::File::Umx;

use strict;
use warnings;

use parent -norequire,'Anorman::ESOM::File::Matrix';

use Anorman::Common;

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new();
	
	if (@_ == 1) {
		$self->filename( shift );
	} elsif (@_ == 2) {
		$self->SUPER::_init(@_);
	}

	return $self;	
}

sub _usage {
	my $usage = "\n\nUsage:";
	my $prefix = "\n" . __PACKAGE__ . "::new(";

	
	return $usage . $prefix . " filename )" . $prefix . " rows, columns )";
}


1;
