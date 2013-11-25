package Anorman::ESOM::File::Map;

use strict;
use warnings;

use parent 'Anorman::ESOM::File::List';

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	$self->{'map'} = Anorman::Data::Hash->new;

	return $self;
}

sub map {
	my $self = shift;

	return $self->{'map'} unless defined $_[0];
	
	$self->{'map'} = shift;
}

sub data {
	my $self = shift;

	return $self->{'data'} unless defined $_[0];

	$self->{'data'} = shift;
	$self->{'map'}->clear;

	foreach (@{ $self->{'data'} }) {
		$self->{'map'}->set( $_->index, $_ );
	} 
}

sub add {
	my $self = shift;
	my $item = shift;

	$self->{'data'}->add( $item );
	$self->{'map'}->set( $item->index, $item )
}

sub get {
	my $self = shift;
	my $key  = shift;

	return $self->{'map'}->{ $key };
}

sub get_quick {
	my $self  = shift;
	my $index = shift;

	return $self->{'data'}->[ $index ];	
}

sub remove { ... }

1;

