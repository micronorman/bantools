package Anorman::Data::Matrix::Pseudo::Symmetric;

use strict;

use parent qw(Anorman::Data::Matrix::Pseudo);

sub _size_from_N {
	# Calculates how many elements are needed to store the symmetric matrix
	my ($self, $N) = @_;
	return ($N * ($N + 1)) >> 1;
}

sub _N_from_size {
	# Calculate dimensions [ N x N ] of the matrix from length of compressed array 
	my ($self, $size) = @_;
	return  -0.5 + sqrt( 0.25 + 2 * $size );
}

sub _index { 
	my ($r,$c) = ($_[1],$_[2]);

	$r += $_[0]->{'r0'};
	$c += $_[0]->{'c0'};

	($r,$c) = ($c,$r) if ($c < $r);

	return $c + (($r * ($r + 1)) >> 1);
}

1;
