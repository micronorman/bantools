package Anorman::Data::LinAlg::LUDecomposition;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data;
use Anorman::Data::BLAS qw ( :L2 blas_axpy );
use Anorman::Data::LinAlg::Property qw( :all );
use Anorman::Data::LinAlg::Algebra qw( permute_rows );
use List::Util qw(min max);

use overload
	'""' => \&_to_string;

sub new {
	my $class = ref $_[0] || $_[0];
	my $self  = bless ( {}, $class );

	$self->decompose( $_[1] ) if @_ > 1;

	return $self;
}

sub decompose {
	my ($self, $A) = @_;

	check_matrix( $A );
	check_square( $A );

	my $N  = $A->rows;
	my $LU = $A->copy;

	my $signum = 1;
	my $p      = [(0 .. $N - 1)];

	my ($i,$j,$k);
	
	$j = -1;
	while ( ++$j < $N - 1 ) {
		my $max     =  abs( $LU->get_quick($j,$j) );
		my $i_pivot = $j;

		$i = $j;
		while ( ++$i < $N ) {
			my $aij = abs( $LU->get_quick($i,$j) );

			if ($aij > $max) {
				$max = $aij;
				$i_pivot = $i;
			}
		}

		if ($i_pivot != $j) {
			$LU->swap_rows( $j, $i_pivot );
			($p->[ $j ], $p->[ $i_pivot ]) = ($p->[ $i_pivot ],$p->[ $j ]);
			$signum = -$signum;
		}

		my $ajj = $LU->get_quick($j,$j);
		if ($ajj != 0) {
			
			$i = $j;
			while ( ++$i < $N ) {
				my $aij = $LU->get_quick( $i, $j ) / $ajj;

				$LU->set_quick( $i, $j, $aij );

				$k = $j;
				while ( ++$k < $N ) {
					my $aik = $LU->get_quick( $i, $k );
					my $ajk = $LU->get_quick( $j, $k );

					$LU->set_quick( $i, $k, $aik - $aij * $ajk )
				}
			}
		}
	}

	$self->{'piv'}      = $p;
	$self->{'pivsign'}  = $signum;
	$self->{'singular'} = $self->singular($LU);
	$self->{'LU'}       = $LU;

	return $LU;
}

sub LU {
	return $_[0]->{'LU'};
}

sub L {
	my $self = shift;
	return $self->_lower_triangular( $self->{'LU'}->copy );
}

sub U {
	my $self = shift;
	return $self->_upper_triangular( $self->{'LU'}->copy );
}

sub det {
	my $self = shift;
	my $LU   = $self->{'LU'};
	my $N    = $LU->rows;
	my $det  = $self->{'pivsign'};
	
	my $j = -1;
	while ( ++$j < $N ) {
		$det *= $LU->get_quick($j,$j);
	}

	return $det;
}

sub invert {
	my $self = shift;
	my $LU   = $self->{'LU'};

	trace_error("Matrix is singular") if $self->singular;

	my $N = $LU->rows;
	my $I = Anorman::Data->identity_matrix( $LU );

	my $i = -1;
	while ( ++$i < $N ) {
		my $c = $I->view_column($i);
		$self->svx( $c );
	}

	return $I;
}

sub solve {
	my $self = shift;
	my $b    = shift;
	my $LU   = $self->{'LU'};
	my $p    = $self->{'piv'};

	trace_error("Matrix size must match solution/rhs size") if $b->size != $LU->rows;
	trace_error("Matrix is singular") if $self->singular;

	my $x = $b->copy;
	
	$self->svx( $x );

	return $x;
}

sub svx {
	my $self = shift;
	my $x    = shift;
	my $LU   = $self->{'LU'};
	my $p    = $self->{'piv'};

	trace_error("Matrix size must match solution/rhs size") if $x->size != $LU->rows;
	trace_error("Matrix is singular") if $self->singular;

	# Apply permutation to RHS
	Anorman::Data::LinAlg::Algebra::permute( $x, $p );

	# Solve for c using forward-substitution, L c = P b
	blas_trsv(BlasLower, BlasNoTrans, BlasUnit, $LU, $x);

	# Perform back-substitution, U x = c
	blas_trsv(BlasUpper, BlasNoTrans, BlasNonUnit, $LU, $x);	
}

sub refine {
	my $self = shift;

	my ($A, $b, $x) = @_;

	my $residual = $b->copy;

	blas_gemv(BlasNoTrans, 1.0, $A, $x, -1.0, $residual);
	
	$self->svx( $residual );

	blas_axpy(-1.0, $residual, $x);	

}

sub _lower_triangular {
	my ($self, $A) = @_;
	my $rows = $A->rows;
	my $cols = $A->columns;

	my $min = min($rows, $cols);
	
	my $r = $min;
	while ( --$r >= 0) {
		my $c = $min;
		while ( --$c >= 0) {
			$A->set_quick($r,$c,0) if ($r < $c);
			$A->set_quick($r,$c,1) if ($r == $c);
		}
	}

	return $A;
}

sub _upper_triangular {
	my ($self, $A) = @_;
	my $rows = $A->rows;
	my $cols = $A->columns;

	my $min = min($rows, $cols);
	
	my $r = $min;
	while ( --$r >= 0) {
		my $c = $min;
		while ( --$c >= 0) {
			$A->set_quick($r,$c,0) if ($r > $c);
		}
	}

	return $A;

}

sub singular {
	my ($self, $A) = @_;
	return $self->{'singular'} unless defined $A;

	my $n = $A->rows;

	my $i = -1;
	while ( ++$i < $n) {
		return 1 if $A->get_quick($i,$i) == 0;
	}

	return 0;
}

sub pivot {
	my $self = shift;
	return $self->{'piv'};
}

sub _to_string {
	my $self = shift;
	
	my $string = '';

	$string .= "------------------------------\n";
	$string .= "LU-Decomposition of Matrix (A)\n";
	$string .= "------------------------------\n";
	$string .= "A is non-singular: " . !$self->singular . "\n";
	$string .= "\ndet(A): " . $self->det . "\n";
	$string .= "\npivot: " . join ("," , @{ $self->{'piv'} }) . "\n";
	$string .= "\n\nL:\n" . $self->L;
	$string .= "\n\nU:\n" . $self->U;
	$string .= "\n\ninverse(A):\n" . $self->invert() unless $self->singular;

	return $string;
}

1;
