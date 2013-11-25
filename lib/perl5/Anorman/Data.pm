package Anorman::Data;

BEGIN {
	require 5.006;
}

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data::LinAlg::Property qw(is_packed is_matrix);

use List::Util qw(min);

our $FORMAT = '%10.4G';

sub matrix {
	my $self = shift;

	require Anorman::Data::Matrix::Dense;
	return  Anorman::Data::Matrix::Dense->new(@_);
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
