package Anorman::Data::LinAlg::Algebra;

use Exporter;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);
@EXPORT_OK = qw(
	inverse
	permute
	permute_rows
	transpose
	solve
	trace
	det
	rank
	cond
);

%EXPORT_TAGS = ( all => [ @EXPORT_OK ] );


use Anorman::Common;
use Anorman::Math::Algorithm;
use Anorman::Data;
use Anorman::Data::LinAlg::Property qw( :all );
use Anorman::Data::LinAlg::LUDecomposition;
use Anorman::Data::LinAlg::QRDecomposition;
use Anorman::Data::LinAlg::SingularValueDecomposition;

use List::Util qw(min);

sub inverse {
	my $A = shift;

	check_matrix($A);

	#if (is_square($A) && is_diagonal($A)) {
	#
	#}
	
	return &solve($A, Anorman::Data->identity_matrix($A));
}

sub det {
	my $A = shift;

	check_matrix($A);

	return &_lu($A)->det();
}

sub cond {
	my $A = shift;

	check_matrix($A);

	return &_svd($A)->cond();
}

sub permute {
	my $A = shift;

	if (is_vector($A)) {
		my ($indexes, $work) = @_;
		my $size = $A->size;
	
		trace_error("Invalid permutation") if (@{ $indexes } != $size);

		if (!defined $work) {
			@{ $work } = @{ $A };
		} else {
			$A->to_array($work);
		}
		
		my $i = $size;
		while ( --$i >= 0 ) {
			$A->set_quick($i, $work->[ $indexes->[ $i ] ]);
		}
		return $A;
	} elsif (is_matrix($A)) {
		my ($row_indexes, $column_indexes) = @_;
		return $A->view_selection($row_indexes, $column_indexes);
	} else {
		trace_error("Must be a matrix or a vector");
	}
}

sub permute_rows {
	my ($A, $indexes) = @_;

	my $size    = $A->rows;

	trace_error("Index out of bounds: invalid permutation") if (@{ $indexes } != $size);

	my $columns = $A->columns;

	if ($columns < $size/10) {

		my $j = $columns;
		while ( --$j >= 0) {
			&permute($A->view_column($j), $indexes);
		}
		return $A;
	}

	$swapper = sub { $A->view_row($_[0])->swap($A->view_row($_[1])) };

	Anorman::Math::Algorithm::generic_permute($indexes, $swapper);
	return $A;
}

sub transpose {
	my $A = shift;

	check_matrix($A);

	return $A->view_dice($A);
}

sub solve {
	my ($A, $B) = @_;

	check_matrix($A);
	check_matrix($B);

	return ($A->rows == $A->columns ? (&_lu($A)->solve($B)) : (&_qr($A)->solve($B)));
}

sub trace {
	my $A = shift;
	
	check_matrix($A);
	
	my $sum = 0;
	my $i   = min($A->rows, $A->columns);
	
	while ( --$i >= 0 ) {
		$sum += $A->get_quick($i,$i);
	}
	return $sum;	
}

sub rank {
	my $A = shift;

	check_matrix($A);

	return &_svd($A)->rank;
}

sub _lu {
	return Anorman::Data::LinAlg::LUDecomposition->new($_[0]);
}

sub _qr {
	return Anorman::Data::LinAlg::QRDecomposition->new($_[0]);
}

sub _chol {
	return Anorman::Data::LinAlg::CholeskyDecomposition->new($_[0]);
}

sub _eig {
	return Anorman::Data::LinAlg::EigenvalueDecomposition->new($_[0]);
}

sub _svd {
	return Anorman::Data::LinAlg::SingularValueDecomposition->new($_[0]);
}

1;
