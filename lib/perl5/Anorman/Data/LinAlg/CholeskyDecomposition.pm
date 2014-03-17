package Anorman::Data::LinAlg::CholeskyDecomposition;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data;
use Anorman::Data::LinAlg::Property qw( :all );
use Anorman::Data::BLAS qw( :all );
use Anorman::Math::Common qw(quiet_sqrt);

use List::Util qw(max);


use overload 
	'""' => \&_stringify;

sub new {
	my $that  = $_[0];
	my $class = ref $that || $that;
	my $self  = bless ( {}, $class );

	$self->decompose($_[1]) if @_ > 1;

	return $self;
}

sub decompose {
	my $self = shift;
	my $A    = shift;

	check_matrix($A);
	check_square($A);

	my ($i,$j,$k);
	my $M = $A->rows;
	my $L = $A->copy;


	my $A_00 = $L->get_quick(0,0);
	my $L_00 = quiet_sqrt($A_00);

	my $symposdef = ($A_00 > 0);

	$L->set(0,0,$L_00);

	if ($M > 1) {
		my $A_10 = $L->get_quick(1,0);
		my $A_11 = $L->get_quick(1,1);
	
		my $L_10 = $A_10 / $L_00;
		my $diag = $A_11 - $L_10 * $L_10;

		my $L_11 = quiet_sqrt($diag);

		$symposdef = ($symposdef && $diag > 0);

		$L->set_quick(1,0,$L_10);
		$L->set_quick(1,1,$L_11);
	}

	$k = 1;
	while ( ++$k < $M ) {
		my $A_kk = $L->get_quick($k,$k);
		
		$i = -1;
		while ( ++$i < $k ) {
			my $sum = 0;

			my $A_ki = $L->get_quick($k,$i);
			my $A_ii = $L->get_quick($i,$i);

			my $ci = $L->view_row($i);
			my $ck = $L->view_row($k);

			if ($i > 0) {
				my $di = $ci->view_part(0,$i);
				my $dk = $ck->view_part(0,$i);

				$sum = $di->dot_product( $dk );
			}

			$A_ki = ($A_ki - $sum) / $A_ii;
			$L->set_quick($k, $i, $A_ki);
		}

		{
			my $ck = $L->view_row( $k );
			my $dk = $ck->view_part(0,$k);

			my $sum  = blas_nrm2( $dk );
			my $diag = $A_kk - $sum * $sum;

			my $L_kk = quiet_sqrt($diag);

			$symposdef = ($symposdef && $diag > 0);

			$L->set_quick($k,$k, $L_kk);
		}
	}

	$self->{'_is_symmetric_positive_definite'} = $symposdef;

	$i = 0;
	while ( ++$i < $M ) {
		$j = -1;
		while ( ++$j < $i ) {
			$L->set_quick($j,$i,0);
			#my $A_ij = $LLT->get_quick($i,$j);
			#$LLT->set_quick($j,$i,$A_ij);
		}
	}

	$self->{'_L'} = $L;

	return $L if $symposdef;
}


=head
sub solve {
	my $self = shift;
	my $B    = shift;

	check_matrix($B);

	trace_error("Matrix row dimensions must agree.") unless ($B->rows == $self->{'_n'});
	trace_error("Matrix is not symmetric positive definite.") unless $self->is_symmetric_positive_definite;

	my $L  = $self->{'_L'};
	my $n  = $self->{'_n'};
	my $X  = $B->copy;
	my $nx = $B->columns;

	my $c = -1;
	while ( ++$c < $nx ) {
		
		my $i = -1;
		while ( ++$i < $n ) {
			my $sum = $B->get_quick( $i, $c );

			my $k = $i;
			while ( --$k >= 0 ) {
				$sum -= $L->get_quick($i,$k) * $X->get_quick( $k, $c );
			}
			$X->set_quick( $i, $c, $sum / $L->get_quick( $i, $i) );
		}

		$i = $n;
		while ( --$i >= 0 ) {
			my $sum = $X->get_quick( $i, $c );
	
			my $k = $i;
			while ( ++$k < $n ) {
				$sum -= $L->get_quick($k,$i) * $X->get_quick( $k, $c );
			}
			$X->set_quick( $i, $c, $sum / $L->get_quick( $i, $i ) );
		}
	}
	
	return $X;
}
=cut

sub solve {
	my $self = shift;
	my $b    = shift;

	my $L = $self->{'_L'};

	check_vector($b);

	trace_error("Matrix row dimension must match b size") if ($L->rows != $b->size);
	trace_error("Matrix is not symmetric positive definite.") unless $self->is_symmetric_positive_definite;
	
	# Copy x <- b
	my $x = $b->copy;

	# Solve for c using forward-substitution, L c = b
	blas_trsv(BlasLower, BlasNoTrans, BlasNonUnit, $L, $x);

	# Perform back-substitution, U x = c
	blas_trsv(BlasUpper, BlasNoTrans, BlasNonUnit, $L->view_dice, $x);

	return $x;
}

sub svx {
	# Solve in-place
	my $self = shift;
	my $x    = shift;

	my $L = $self->{'_L'};

	check_vector($x);

	trace_error("Matrix row dimension must match b size") if ($L->rows != $b->size);
	trace_error("Matrix is not symmetric positive definite.") unless $self->is_symmetric_positive_definite;
	
	# Solve for c using forward-substitution, L c = b
	blas_trsv(BlasLower, BlasNoTrans, BlasNonUnit, $L, $x);

	# Perform back-substitution, U x = c
	blas_trsv(BlasUpper, BlasNoTrans, BlasNonUnit, $L->view_dice, $x);
}

sub invert {
	my $self = shift;

	my $I = $self->{'_L'}->copy;
	my $N = $I->rows;

	my $sum;
	my ($i,$j);

	$i = -1;
	while ( ++$i < $N ) {
		my $ajj;

		$j = $N - $i - 1;

		$I->set_quick( $j, $j, 1.0 / $I->get_quick($j,$j));
		$ajj = -$I->get_quick($j,$j);

		if ($j < $N - 1) {
			my $m  = $I->view_part( $j + 1, $j + 1, $N - $j - 1, $N - $j - 1);
			my $v1 = $I->view_column( $j )->view_part( $j + 1, $N - $j - 1);

			blas_trmv(BlasLower, BlasNoTrans, BlasNonUnit, $m, $v1 );
			blas_scal($ajj, $v1);
		}

	}

	$i = -1;
	while ( ++$i < $N ) {
		$j = $i;
		while ( ++$j < $N ) {
			my $v1 = $I->view_column( $i )->view_part( $j, $N - $j );
			my $v2 = $I->view_column( $j )->view_part( $j, $N - $j );

			$sum = $v1->dot_product( $v2 );

			$I->set_quick($i,$j, $sum);
		}

		my $v1 = $I->view_column($i)->view_part( $i, $N - $i );

		$sum = $v1->dot_product( $v1 );
		$I->set_quick($i,$i,$sum);
	}

	$j = 0;
	while ( ++$j < $N) {
		$i = -1;
		while ( ++$i < $j ) {
			my $L_ij = $I->get_quick($i,$j);
			$I->set_quick($j,$i,$L_ij);
		}
	}

	return $I;
}

sub L {
	my $self = shift;
	return $self->{'_L'};
}

sub is_symmetric_positive_definite {
	my $self = shift;
	return $self->{'_is_symmetric_positive_definite'};
}
sub _stringify {
	my $self = shift;

	my $string = '';

	$string .= "-----------------------------------\n";
	$string .= "Cholesky Decomposition of Matrix(A)\n";
	$string .= "-----------------------------------\n";

	$string .= "A is symmetric positive definite: " . ($self->is_symmetric_positive_definite ? "YES" : "NO");
	$string .= "\n\nL:\n$self->{'_L'}";
	$string .= "\n\ninverse(A):\n" . $self->invert if $self->is_symmetric_positive_definite;

	return $string;
}

1;
