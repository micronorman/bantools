package Anorman::Data::Matrix::Pseudo::HollowSymmetric;

use strict;

use parent qw(Anorman::Data::Matrix::Pseudo);

sub _size_from_N {
	# Calculates how many elements are needed to store the symmetric matrix
	my ($self, $N) = @_;
	return ($N * ($N - 1)) >> 1;
}

sub _N_from_size {
	# Calculate dimensions [ N x N ] of the matrix from length of compressed array 
	my ($self, $size) = @_;
	return  0.5 + sqrt( 0.25 + 2 * $size );
}

sub view_diagonal {
	trace_error("Hollow matrix has no diagonal");
}

sub get_quick {
	my $self = shift;
	my ($i,$j) = @_;

	my $index = $self->_index($i,$j);
	
	return 0 if ($index < 0);

	return $self->{'_ELEMS'}->get_quick( $index ); 
}

sub set_quick {
	my $self = shift;
	my ($i,$j, $v) = @_;

	my $index - $self->_index($i,$j);

	# nothing to do for i == j
	return if $index < 0;
		
	$self->{'_ELEMS'}->set_quick( $self->_index($i,$j), $v); 

}

sub _index { 
	my ($r,$c) = ($_[1],$_[2]);

	$r += $_[0]->{'r0'};
	$c += $_[0]->{'c0'};

	return -1 if ($c == $r);
	
	($r,$c) = ($c,$r) if ($c > $r);

	return $c + (($r * ($r - 1)) >> 1);
}

1;
