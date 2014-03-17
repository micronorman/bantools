package Anorman::Math::Distances;

use strict;
use warnings;

use Anorman::Common;

sub new {
	my $class = shift;
	return bless( { }, ref $class || $class );
}

sub data {
	my $self   = shift;
	my $data_r = shift;

	if (defined $data_r) {
		$self->{'data'} = $data_r;
		$self->{'n'}    = @{ $data_r };
	} else {
		return $self->{'data'};
	}
}

sub distance_function {
	my $self = shift;
	my $df   = shift;

	if (defined $df) {
		$self->_error("Not a CODE reference. Expected a distance function") unless (ref $df) =~ m/::Distance::/;
		$self->{'distance_func'} = $df;

		if (exists $self->{'distances'}) {
			@{ $self->{'distances'} } = undef;
		}
	}
	return $self->{'distance_function'};
}

sub get {
	my $self    = shift;
	my ($i, $j) = @_;

	if ($i == $j) { 
		return 0;
	} elsif ( $i > $j) {
		return $self->get($j, $i);
	} else {
		$self->_calculate_distances() unless exists $self->{'distances'};

		return $self->{'distances'}->[ $self->_index($i, $j) ];
	}
}

sub set {
	my $self        = shift;
	my ($i, $j, $d) = @_;

	if ($i > $j) {
		$self->set($j, $i, $d);
	} elsif ($j < $i) {
		$self->{'distances'}->[ $self->_index($i,$j) ] = $d;
	} # ignores $i == $j
}

sub get_distances {
	my $self = shift;

	$self->_calculate_distances() unless $self->{'distances'};
	return wantarray ? @{ $self->{'distances'} } : $self->{'distances'};
}

sub get_distance_matrix {
	my $self = shift;

	$self->_calculate_distances() unless exists $self->{'distances'};
	my $n = $self->{'n'};
}

sub _calculate_distances {
	my $self   = shift;
	my $data   = $self->{'data'} || $self->_error("No DATA loaded\n");
	my $size   = ($self->{'n'} * ($self->{'n'} - 1)) / 2;
	my $length = length ($self->{'data'}->[0]) / 8;
	my $dist   = $self->{'distance_func'} or $self->_error("No distance function set");
	
	warn "Calculating $size Distances from $self->{'n'} weights that are $length deep...\n";
	
	foreach my $i( 0..$self->{'n'} - 1 ) {
		foreach my $j($i + 1..$self->{'n'} - 1) {
			$self->{'distances'}->[ $self->_index($i,$j) ] = 
				$dist->apply( $length, $self->{'data'}->[ $i ], $self->{'data'}->[ $j ] );
		}
	}
}

sub _index {
	my $self = shift;
	return ( $_[0] * $self->{'n'} + $_[1] ) - (( ($_[0] + 1) * ($_[0] + 2) ) / 2);
}

sub _error {
	shift;
	trace_error(@_);
}

1;


