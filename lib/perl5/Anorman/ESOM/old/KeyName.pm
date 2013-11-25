package Anorman::ESOM::KeyName;

use strict;
use warnings;

use Anorman::Common;

use overload
	'""' => \&_stringify;

sub new {
	my $class = shift;
	
	trace_error("Not enough arguments\n\nusage: " . __PACKAGE__ . "::new( index, name, description )" ) unless @_ >= 2;
	
	my $self = [];

	@{ $self } = @_;

	return bless ( $self, $class );
}

sub index {
	my $self = shift;
	return $self->[0];
}

sub name {
	my $self = shift;

	return $self->[1];
}

sub description {
	my $self = shift;

	return $self->[2];
}

sub _stringify {
	my $self = shift;

	trace_error("Trying to stringify!");
	return join "\t", @{ $self };
}

1;
