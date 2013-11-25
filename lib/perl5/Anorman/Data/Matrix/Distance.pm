package Anorman::Data::Matrix::Distance;

=head1 NAME 

Anorman::Data::Matrix::Distance

=head1 SYNOPSIS

 use Anorman::Data::Matrix::Dense;>
 use Anorman::Data::Matrix::Distance;

 $data = Anorman::Data::Matrix::Dense->new(5,5);
 $data->assign( sub{ rand(1) } );

 $dm = Anorman::Data::Matrix::Distance->new( $data );

 print $dm->get_distance_matrix;

 0.000 1.087 0.550 1.040 0.857
 1.087 0.000 1.126 0.939 0.764
 0.550 1.126 0.000 1.180 0.711
 1.040 0.939 1.180 0.000 1.051
 0.857 0.768 0.711 1.051 0.000

=head1 DESCRIPTION

A class for calculating and storing a euclidean distance matrix in a linear array. 
The user can specify a distance function (such as Manhattan distance), but the default
is Euclidean vector distance

=head1 AUTHOR

Anders Norman

=head1 SEE ALSO

L<http://en.wikipedia.org/wiki/Euclidean_distance_matrix>

=cut

use strict;

use Anorman::Common;
use Anorman::Data::LinAlg::Property qw( :matrix );
use Anorman::Data::Matrix::Dense;
use Anorman::Math::DistanceFactory;

sub new {
	my $class = shift;

	my $self = {
		'n'      => undef,
		'data'   => undef,
		'_ELEMS' => undef,
		'_FUNC'  => undef
	};

	bless ( $self, ref $class || $class );

	if (@_ == 1) {
		$self->data($_[0]);
		$self->_calculate_distances;
	} 

	return $self;
}

sub rows {
	return $_[0]->{'_n'};
}

sub columns {
	return $_[0]->{'_n'};
}

sub data {
	my $self = shift;
	
	if (defined $_[0]) {
		check_matrix($_[0]);
		
		my $data = shift;

		$self->{'data'} = [ map { $data->view_row( $_ ) } (0 .. $data->rows - 1) ];
		$self->{'n'}    = $data->rows;
	} else {
		return $self->{'data'};
	}
}

sub get_distance_matrix {
	my $self = shift;

	trace_error("No matrix defined") if !defined $self->{'_ELEMS'};

	my $matrix;

	if (is_packed($self->{'_ELEMS'})) {
		$matrix = Anorman::Data::Matrix::DensePacked->new( $self->{'n'}, $self->{'n'} );
	} else {
		$matrix = Anorman::Data::Matrix::Dense->new( $self->{'n'}, $self->{'n'} );
	}

	my $i = -1;
	while ( ++$i < $self->{'n'} ) {

		my $j = - 1;
		while (++$j < $self->{'n'}) {
			$matrix->set_quick( $i, $j, $self->get( $i, $j ) );
		}
	}

	return $matrix;
}

sub get {
	my $self    = shift;
	my ($i, $j) = @_;

	if ($i == $j) { 
		return 0;
	} elsif ( $i > $j) {
		return $self->get($j, $i);
	} else {
		$self->_calculate_distances() unless defined $self->{'_ELEMS'};

		return $self->{'_ELEMS'}->get_quick( $self->_index($i, $j) );
	}
}

sub set {
	my $self        = shift;
	my ($i, $j, $d) = @_;

	if ($i > $j) {
		$self->set($j, $i, $d);
	} elsif ($j < $i) {
		$self->{'_ELEMS'}->set_quick( $self->_index($i,$j) ) = $d;
	} # ignores $i == $j
}

sub _index {
	my $self = shift;
	my ($i, $j) = @_;
	my $n = $self->{'n'};
	
	my $index = $i * $n -($i - 1);
	$index << 2;
	$index += $j;

	return $index;
	return ( $_[0] * $self->{'n'} + $_[1] ) - (( ($_[0] + 1) * ($_[0] + 2) ) / 2);
}

sub _calculate_distances {
	my $self = shift;

	if (!defined $self->{'_FUNC'}) {
		warn "No distance function defined, using Euclidean distances...\n";
		$self->{'_FUNC'} = Anorman::Math::DistanceFactory->get_function( SPACE => 'euclidean', PACKED => 1 );
	}

	my $size = ($self->{'n'} * ($self->{'n'} - 1)) / 2;

	if (is_packed($self->{'data'}->[0])) {
		$self->{'_ELEMS'} = Anorman::Data->packed_vector( $size );
	} else {
		$self->{'_ELEMS'} = Anorman::Data->vector( $size );
	}
	
	warn "Calculating $size distances...\n";
	my $i = -1;
	while (++$i < ($self->{'n'} - 1)) {

		my $j = $i;
		while (++$j < $self->{'n'}) {
			$self->{'_ELEMS'}->set_quick( $self->_index( $i, $j ), $self->{'_FUNC'}->apply( $self->{'data'}->[ $i ], $self->{'data'}->[ $j ] ));
		}
	}
	warn "Done\n";
}


1;

