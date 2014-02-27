package Anorman::ESOM::File::BM;

use strict;
use warnings;

use parent 'Anorman::ESOM::File::Map';

sub new {
	my $class    = shift;
	my $filename = shift;
	my $self     = $class->SUPER::new();

	$self->{'filename'}  = $filename;

	return $self;
}

sub rows {
	my $self = shift;
	return $self->{'rows'} unless defined $_[0];
	$self->{'rows'} = shift;
}

sub columns {
	my $self = shift;
	return $self->{'columns'} unless defined $_[0];
	$self->{'columns'} = shift;
}

sub datapoints {
	my $self = shift;
	return $self->{'datapoints'} unless defined $_[0];
	$self->{'datapoints'} = shift;
}

1;
