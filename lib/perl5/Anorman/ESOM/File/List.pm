package Anorman::ESOM::File::List;

use strict;
use warnings;

use parent 'Anorman::ESOM::File';

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	
	$self->{'data'} = Anorman::Data::List->new;

	return $self;
}

sub data {
	my $self = shift;
	return $self->{'data'} unless defined $_[0];

	$self->{'data'} = shift;
}

sub size {
	my $self = shift;
	return scalar @{ $self->{'data'} };
}

1;

