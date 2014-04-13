package Anorman::Data::Matrix::Pseudo;

use strict;

use parent qw(Anorman::Data::Abstract Anorman::Data::Matrix::Abstract Anorman::Data::Matrix);

use Anorman::Common;
use Anorman::Data::LinAlg::Property qw(is_symmetric is_vector);

use Anorman::Data;
use Anorman::Data::Matrix::Dense;

# Matrices that are stored as a vector internally. 

sub new {
	my $that  = shift;
	my $class = ref $that || $that;
	my $self  = $class->SUPER::new();
	if (@_ != 1) {
		trace_error("Wrong number of arguments");
	}

	my $type = Anorman::Common::sniff_scalar($_[0]);

	if ($type eq 'ARRAY') {
		$self->_new_from_ARRAY(@_);
	} else { 
		$self->_new_from_dims(@_);
	}
	
	return $self;
}


sub _new_from_dims {
	my $self = shift;

	my ( $N,
	     $elements
           ) = @_;

	# Allocate a fresh matrix
	if (@_ == 1) {
		$self->_setup($N, $N);
		$self->{'_ELEMS'} = Anorman::Data->vector( $self->_size_from_N($N) );

	# Set up view on existing matrix elements
	} else {  
		$self->_setup( $N, $N, 0, 0, 1, 1 );

		trace_error("Invalid data elements. Must be a vector")
			unless is_vector($elements);

		$self->{'_ELEMS'} = $elements;
		$self->{'_VIEW'}  = 1;
	}

	$self->{'rstride'} = 1;
}

sub _new_from_ARRAY {
	my $self    = shift;
	
	trace_error("Not an ARRAY reference") unless 'ARRAY' eq ref $_[0];

	my $array = shift;

	# Calculate N from number of elements, where size = (N * (N + 1))/2
	my $N = $self->_N_from_size( scalar @{ $array });

	trace_error("Wrong number of elements") if ($N != int $N);

	my $elements = Anorman::Data->vector( $array );
	$self->_new_from_dims( $N, $elements );
}

#sub size {
#	my $self = shift;
#	my $N    = $self->{'rows'};
#	return ($N * ($N + 1)) >> 1;
#}

sub view_row {
	my $self = shift;
	$self->_check_row($_[0]);

	my $voffsets = [];
	my $j = $self->{'columns'};

	while ( --$j >= 0 ) {
		$voffsets->[ $j ] = $self->_index($_[0], $j)
	}

	return $self->{'_ELEMS'}->view_selection($voffsets);
}

sub view_column {
	return $_[0]->view_row($_[1]);
}

sub view_dice {
	return $_[0]->clone;
}

sub view_diagonal {
	my $self = shift;

	my $voffsets = [];
	my $j = $self->{'rows'};

	while ( --$j >= 0 ) {
		$voffsets->[ $j ] = ($j * ($j + 3)) >> 1;
	}

	return $self->{'_ELEMS'}->view_selection($voffsets);

}

sub get_quick {
	my $self = shift;
	my ($i,$j) = @_;

	if ($i < $j) {
		return $self->get_quick($j,$i);
	} else {
		return $self->{'_ELEMS'}->get_quick( $self->_index($i,$j) ); 
	}
}

sub set_quick {
	my $self = shift;
	my ($i,$j, $v) = @_;

	if ($i < $j) {
		$self->set_quick($j,$i,$v);
	} else {
		$self->{'_ELEMS'}->set_quick( $self->_index($i,$j), $v); 
	}

}

sub like {
	my $self  = shift;
	my ($rows, $columns);

	if (@_ == 2) {
		($rows, $columns) = @_;
	} else {
		$rows    = $self->{'rows'};
		$columns = $self->{'columns'};
	}

	return Anorman::Data::Matrix::Dense->new($rows, $columns);
}

sub _to_string {
	my $self = shift;
	return $self->copy->_to_string;
}

sub _to_array {
	my $self = shift;
	return $self->{'_ELEMS'}->_to_array;
}

1;
