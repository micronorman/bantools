package Anorman::Data;

BEGIN {
	require 5.006;
}

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data::LinAlg::Property qw(is_packed is_matrix);

use List::Util qw(min);

our $FORMAT = '%10.6G';

sub matrix {
	my $self = shift;

	require Anorman::Data::Matrix::Dense;
	return  Anorman::Data::Matrix::Dense->new(@_);
}

sub general_matrix {
	require Anorman::Data::Matrix::Dense;
	
	my $self = shift;
	my ($rows, $columns) = @_;

	my ($i,$j);
	my $m = Anorman::Data::Matrix::Dense->new($rows,$columns);

	for ($i = 0; $i < $rows; $i++) {
		for ($j=0; $j < $columns; $j++) {
			$m->set($i,$j, 1.0 / ($i + $j + 1.0));
		}
	}

	return $m;
}

sub hilbert_matrix {
	require Anorman::Data::Matrix::Dense;

	my $self = shift;
	my $size = shift;

	my ($i,$j);
	my $m = Anorman::Data::Matrix::Dense->new($size,$size);

	for ($i = 0; $i < $size; $i++) {
		for ($j=0; $j < $size; $j++) {
			$m->set($i,$j, 1.0 / ($i + $j + 1.0));
		}
	}

	return $m;
}

sub vandermonde_matrix {
	require Anorman::Data::Matrix::Dense;

	my $self = shift;
	my $size = shift;

	my ($i,$j);
	my $m = Anorman::Data::Matrix::Dense->new($size,$size);

	for ($i = 0; $i < $size; $i++) {
		for ($j=0; $j < $size; $j++) {
			$m->set($i,$j, ($i + 1.0) ** ($size - $j - 1.0));
		}
	}

	return $m;

}

sub identity_matrix {
	my $self = shift;
	my ($I, $n);

	if ( is_matrix($_[0]) ) {
		my $A = shift;
		
		$n = min( $A->rows, $A->columns );
		$I = is_packed($A) ? $self->packed_matrix( $n, $n ) : $self->matrix( $n, $n );
	} else {
		$n = shift;
		$I = $self->matrix( $n, $n );
	}
	
	my $i = $n;
	while ( --$i >= 0) {
		$I->set_quick($i,$i,1);
	}

	return $I;
}

sub vector {
	my $self = shift;

	require Anorman::Data::Vector::Dense;
	return  Anorman::Data::Vector::Dense->new(@_);
}

sub packed_matrix {
	my $self = shift;

	require Anorman::Data::Matrix::DensePacked;
	return  Anorman::Data::Matrix::DensePacked->new(@_);
}

sub packed_vector {
	my $self = shift;

	require Anorman::Data::Vector::DensePacked;
	return  Anorman::Data::Vector::DensePacked->new(@_);
}

sub map {
	my $self = shift;

	require Anorman::Data::Map;
	return Anorman::Data::Map->new(@_)
}

sub clone {
	my $self  = shift;
	
	if (is_packed($self)) {
		return $self->_struct_clone;
	} else {
		my $clone = {};

		@{ $clone }{ keys %{ $self } } = values %{ $self };

		return bless ( $clone, ref $self );
	}

}

sub _error {
	trace_error($_[1]);
}


1;
