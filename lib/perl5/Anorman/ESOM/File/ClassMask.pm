package Anorman::ESOM::File::ClassMask;

use strict;
use warnings;

use parent 'Anorman::ESOM::File::Map';

use Anorman::Common;

use Scalar::Util qw(looks_like_number);

use overload 
	'""' => \&_stringify;

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new();

	if (@_ == 1) {
		if (looks_like_number($_[0])) {
			my $size = shift;
			%{ $self->{'map'} } = map { $_ => 0 } (0 .. $size - 1); 	
		} else {
			my $filename = shift;
			$self->{'filename'} = $filename;
		}
	}

	$self->{'classes'} = Anorman::ESOM::ClassTable->new;
	$self->{'keys'}    = Anorman::Data::List->new;

	return $self;
}

sub classes {
	my $self = shift;
	
	return $self->{'classes'} unless defined $_[0];

	$self->{'classes'} = shift;
	$self->{'_indexed'} = undef;
}

sub add {
	my $self = shift;
	my ($index, $cls) = @_;

	return unless defined $cls;

	unless (exists $self->{'map'}->{ $index }) {
		$self->{'keys'}->add( $index );
		$self->{'data'}->add( $cls );
		$self->{'map'}->set( $index, $self->{'keys'}->size );
	} else {
		$self->{'data'}->set( $self->{'map'}->get( $index ), $cls );
	}
}

sub get_quick {
	my $self = shift;
	return $self->{'map'}->get( $_[0] );
}

sub get_by_index {
	my ($self, $index) = @_;

	my $pos = $self->{'map'}->get( $index );

	if (defined $pos) { 	
		return $self->{'data'}->get( $self->{'map'}->get( $index ) ); 
	} 
	
	return 0;	
}

sub set {
	my $self = shift;
	$self->add( $_[0], $_[1] );
}

sub index_classes {
	my $self = shift;

	$self->_fill_classes unless defined $self->{'_indexed'};
}

sub _fill_classes {
	my $self  = shift;
	my %class_index = ();

	foreach my $class( @{ $self->classes } ) {
		$class->clear;
	}

	warn "Indexing neurons...\n" if $VERBOSE;
	
	my $i = - 1;
	while ( ++$i < $self->neurons ) {
		my $cls = $self->get_by_index( $i );
		
		if ($cls) { 
			$self->classes->get_by_index( $cls )->add_members( $i );
		} else {
			$self->classes->get(0)->add_members( $i );
		}
	}

	$self->{'_indexed'} = 1;	
}

sub _stringify {
	my $self = shift;

	my $string .= 'CLASS MASK';
	$string .= "\nTotal neurons: " . $self->neurons;
	$string .= "\nMasked neurons: " . $self->map->size;
}

1;
