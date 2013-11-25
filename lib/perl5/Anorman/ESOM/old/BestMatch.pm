package Anorman::ESOM::BestMatch;

use strict;
use warnings;

use Anorman::Common;

use overload
	'""' => \&_to_string;

# simple class for containing BestMatches
# index, row, and column numbers are stored internally 
# as an anonymous array

sub new {
	my $class = shift;
	
	my $self = [];

	if (@_ == 3) {
		@{ $self } = @_;
	} elsif (@_ != 0) {
		trace_error("Wrong number of arguments\nUsage: " . __PACKAGE__ . "::new( index, row, column )");
	}

	return bless ( $self, ref $class || $class );
}

sub index {
	my $self = shift;
	return $self->[0] unless defined $_[1];
	$self->[0] = shift;
}

sub row {
	my $self = shift;
	return $self->[1] unless defined $_[1];
	$self->[1] = shift;
}

sub column {
	my $self = shift;
	return $self->[2] unless defined $_[1];
	$self->[2] = shift;
}

sub _to_string {
	my $self = shift;
	return join ("\t", @{$self});
}

1;

