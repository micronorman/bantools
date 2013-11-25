package Anorman::ESOM::ClassMask;

use strict;
use warnings;

use Anorman::Common;
use Anorman::ESOM::Class;

sub new {
	my $class = shift;
	my $cmx   = shift;
	my $grid  = shift;
	
	my $self = { 'grid'    => undef,
		     'colors'  => [], # color table for when creating new classes
		     'classes' => [], # list of classes
                     'key2pos' => {}, # internal index of keys and array positions of classified datapoints
		     'keys'    => [], # list of keys
		     'data'    => [], # list of datapoint classifications
	};


	if (defined $cmx) {
		foreach my $key(keys %{ $ESOM->_cmx }) {
			$self->{ $key } = $ESOM->_cmx->{ $key } if exists $self->{ $key };
		}
	}

	$self->{'grid'} = $grid if ref $grid eq 'Anorman::ESOM::Grid';

	return bless( $self, ref $class || $class );
}

sub keys {
	my $self = shift;	
	return $self->{'keys'} unless defined $_[0];
	
	$self->{'data'} = shift;
}

sub classes {
	my $self = shift;
	return $self->{'classes'} unless defined $_[0];

	$self->{'classes'} = shift;
}

sub data {
	my $self = shift;
	return $self->{'data'} unless defined $_[0];
	
	$self->{'data'} = shift;
}

sub colors {
	my $self = shift;
	return $self->{'colors'} unless defined $_[0];

	$self->{'colors'}
}

sub grid {
	my $self = shift;
	return $self->{'grid'} unless defined $_[0];

	$self->{'grid'} = shift;	
}

sub add {
	# add a index - class pair
	my $self = shift;
	my ($index, $class) = @_;

	return unless $class;

	#TODO create a new class if none exists
	if (exists $self->{'key2pos'}->{ $index }) {
		$self->{'data'}->[ $self->{'key2pos'}->{ $index } ] = $class;
	} else {
		push @{ $self->{'keys'} }, $index;
		push @{ $self->{'data'} }, $class;
		$self->{'key2pos'}->{ $index } = $#{ $self->{'keys'} };
	}
}

sub add_class {
	my $self = shift;
}

sub classify {
	my $self = shift;
	my $bestmatches = shift;

	trace_error("No class mask present") if @{ $self->{'data'} } == 0;

	my %cls;
	foreach my $bm(@{ $bestmatches }) {
		trace_error("Not a bestmatch") unless ref $bm eq 'Anorman::ESOM::BestMatch';
		trace_error("No grid defined") unless defined $self->{'grid'};

		my $index = $self->{'grid'}->coords2index( $bm->row, $bm->column );
		my $class = exists $self->{'key2pos'}->{ $index } ? $self->{'data'}->[ $self->{'key2pos'}->{ $index } ] : 0;

		$cls{ $bm->index } = $class;
		
	}

	return \%cls;
}

1;
