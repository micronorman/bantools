package Anorman::Math::Distances;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data::Matrix::Pseudo::HollowSymmetric;

sub new {
	my $class = shift;
	return bless( { }, ref $class || $class );
}

sub data {
	my $self   = shift;
	my $data_r = shift;

	if (defined $data_r) {
		my $N = $data_r->rows;
		my $row_cache = [];
		my $i = -1;
		while ( ++$i < $N ) {
			$row_cache->[ $i ] = $data_r->view_row( $i );
		}

		$self->{'data'}   = $row_cache;
		$self->{'data2d'} = $data_r;
		$self->{'_n'}     = $N;
	} else {
		return $self->{'data'};
	}
}

sub distance_function {
	my $self = shift;
	my $df   = shift;

	if (defined $df) {
		trace_error("Not a CODE reference. Expected a distance function") unless 'CODE' eq ref $df;
		$self->{'distance_func'} = $df;

		if (exists $self->{'distances'}) {
			$self->{'distances'}->assign(0);
		}
	}
	return $self->{'distance_func'};
}

sub get {
	my $self    = shift;
	my ($i, $j) = @_;

	$self->_calculate_distances() unless exists $self->{'distances'};
	return $self->{'distances'}->get_quick($i,$j);
}

sub get_distances {
	my $self = shift;

	$self->_calculate_distances() unless $self->{'distances'};
	return $self->{'distances'};
}

sub _calculate_distances {
	my $self   = shift;
	my $data   = $self->{'data'} || trace_error("No DATA loaded");
	my $dist   = $self->{'distance_func'} or trace_error("No distance function set");
	my $N      = $self->{'_n'};
	my $size   = ($N * ($N - 1)) >> 1; 

	warn "Initializing distance matrix...\n";
	$self->{'distances'} = Anorman::Data::Matrix::Pseudo::HollowSymmetric->new( $N );
	warn "Calculating $size Distances from $N weights\n";

	my ($i,$j);

	$i = -1;
	while ( ++$i < $N ) {
		$j = -1;
		while ( ++$j < $i ) {
			$self->{'distances'}->set_quick( $i, $j, $dist->( $data->[ $i ], $data->[ $j ] ));
		}
	}
}

1;


