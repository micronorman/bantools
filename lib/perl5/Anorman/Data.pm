package Anorman::Data;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data::Config qw($PACK_DATA);
use Anorman::Data::LinAlg::Property qw(is_matrix);

use List::Util qw(min);

sub matrix {
	my $self = shift;

	if ($PACK_DATA) {
		require Anorman::Data::Matrix::DensePacked;
	 	return  Anorman::Data::Matrix::DensePacked->new(@_);
	} else {
		require Anorman::Data::Matrix::Dense;
		return  Anorman::Data::Matrix::Dense->new(@_);
	}
}

sub random_matrix {
	my $self = shift;
	
	return $self->matrix($_[0],$_[1])->assign( sub { rand } );
}


sub vector {
	my $self = shift;

	if ($PACK_DATA) {
		require Anorman::Data::Vector::DensePacked;
		return Anorman::Data::Vector::DensePacked->new(@_);
	} else {
		require Anorman::Data::Vector::Dense;
		return  Anorman::Data::Vector::Dense->new(@_);
	}
}

sub random_vector {
	my $self = shift;

	return $self->vector($_[0])->assign( sub { rand } );
}

sub general_matrix {
	my $self = shift;

	trace_error("Wrong number of arguemnts") unless @_ == 2;

	my ($rows, $columns) = @_;

	my ($i,$j);
	my $m = $self->matrix($rows,$columns);

	for ($i = 0; $i < $rows; $i++) {
		for ($j=0; $j < $columns; $j++) {
			$m->set($i,$j, 1.0 / ($i + $j + 1.0));
		}
	}

	return $m;
}

sub hilbert_matrix {
	my $self = shift;
	my $size = shift;

	my $m = $self->matrix($size,$size);
	
	my ($i,$j);
	for ($i = 0; $i < $size; $i++) {
		for ($j=0; $j < $size; $j++) {
			$m->set($i,$j, 1.0 / ($i + $j + 1.0));
		}
	}

	return $m;
}

sub vandermonde_matrix {
	my $self = shift;
	my $size = shift;

	my $m = $self->matrix($size,$size);
	
	my ($i,$j);
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
		$n = min( $_[0]->rows, $_[0]->columns );
		$I = $_[0]->like($n,$n);
	} else {
		$n = $_[0];
		$I = $self->matrix( $n, $n );
	}
	
	$I->view_diagonal->assign(1);

	return $I;
}


sub map {
	my $self = shift;

	require Anorman::Data::Map;
	return Anorman::Data::Map->new(@_)
}

1;

__END__
package Anorman::Data::Factory::Matrix;

sub new { bless( {} , ref $_[0] || $_[0] ) };

1;
