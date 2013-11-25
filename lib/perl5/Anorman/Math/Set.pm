package Anorman::Math::Set;

# Maintain set of unique numbers in no particular order

use strict;
use warnings;

use Anorman::Common;
use Scalar::Util qw(looks_like_number);

require 5.006;

sub TIEARRAY {
	my $class       = shift;

	return bless ( [{}, 0 ], $class );
}

sub PUSH {
	my $self = shift;

	# Only add numbers
	foreach (grep { looks_like_number($_) && $_ == $_ } @_) {
		if (!exists $self->[0]->{ $_ }) {
			$self->[0]->{ $_ } = undef;
			$self->[1]++;
		}
	}

	return $self->[1];
}

sub FETCHSIZE {
	my $self = shift;
	return $self->[1];
}

sub STORESIZE {
	trace_error("Cannot change the size of a set explicitly");
}

sub DELETE {
	my ($self, $value) = @_; 

	return undef if !defined $value;

	if (exists $self->[0]->{ $value }) {
		delete $self->[0]->{ $value };

		$self->[1]--;

		return $value;
	}
}

sub EXISTS {
	my ($self, $value) = @_;

	return exists $self->[0]->{ $value };
}



sub SHIFT {
	my $self = shift;

	if (defined (my $value = (each %{ $self->[0] })[0])) {
		return $self->DELETE($value);
	} else {
		keys %{ $self->[0] };
	}

}

sub SPLICE {
	trace_error("Seriously, don't try and splice a set");
}

sub FETCH {
	my $self = shift;
	return (keys %{ $self->[0] })[ $_[0] ];
}

sub STORE {
	my $self = shift;
	$self->PUSH( $_[1] );
}

sub CLEAR {
	my $self = shift;
	%{ $self->[0] } = ();
	   $self->[1]   = 0;

	keys %{ $self->[0] };
}

sub EXTEND {
	# Do Nothing
}

sub POP { ... }
sub UNSHIFT { ... }
sub UNTIE { 
	my $self = shift;
	return sort { $a <=> $b } keys %{ $self->[0] };
}

1;

