package Anorman::Data::BLAS;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data::LinAlg::Property qw( :all );

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);


use constant {
	BlasNoTrans   => 111,
	BlasTrans     => 112,
	BlasConjTrans => 113,
	BlasUpper     => 121,
	BlasLower     => 122,
	BlasNonUnit   => 131,
	BlasUnit      => 132,
	BlasLeft      => 141,
	BlasRight     => 142
};

@ISA       = qw(Exporter);

@EXPORT_OK = qw(
	BlasNoTrans
	BlasTrans
	BlasConjTrans
	BlasUpper
	BlasLower
	BlasNonUnit
	BlasUnit
	BlasLeft
	BlasRight
	blas_dot
	blas_nrm2
	blas_asum
	blas_iamax
	blas_swap
	blas_copy
	blas_axpy
	blas_scal
	blas_gemv
	blas_symv
	blas_trmv
	blas_trsv
	blas_ger
	blas_syr
	blas_syr2
	blas_gemm
	blas_symm
	blas_trmm
	blas_trsm
);

@EXPORT = qw(
	BlasNoTrans
	BlasTrans
	BlasConjTrans
	BlasUpper
	BlasLower
	BlasNonUnit
	BlasUnit
	BlasLeft
	BlasRight
);

%EXPORT_TAGS = ( 

L1 => [ qw(BlasNoTrans BlasTrans BlasConjTrans BlasUpper BlasLower
           BlasNonUnit BlasUnit BlasLeft BlasRight blas_dot blas_nrm2
           blas_asum blas_iamax blas_swap blas_copy blas_axpy blas_scal) ],

L2 => [ qw(BlasNoTrans BlasTrans BlasConjTrans BlasUpper BlasLower
           BlasNonUnit BlasUnit BlasLeft BlasRight blas_gemv blas_symv
           blas_trmv blas_trsv blas_ger blas_syr blas_syr2) ],

L3 => [ qw(BlasNoTrans BlasTrans BlasConjTrans BlasUpper BlasLower
           BlasNonUnit BlasUnit BlasLeft BlasRight blas_gemm blas_symm
           blas_trmm blas_trsm) ],

all => [ @EXPORT_OK ]

);


#==============================================================================
# Level 1
#==============================================================================

sub blas_dot ($$) {
	my ($X, $Y) = @_;

	if ($X->size == $Y->size) {
		my $N = $X->size;

		my $r  = 0;
		my $i = -1;
		while ( ++$i < $N ) {
			$r += $X->get_quick( $i ) * $Y->get_quick( $i );
		}

		return $r;
	} else {
		trace_error("Invalid lengths");
	}
}


# Norm of vector #

sub blas_nrm2 ($) {
	my ($X) = @_;

	my $N     = $X->size;
	my $scale = 0.0;
	my $ssq   = 1.0;

	if ($N <= 0) {
		return 0;
	} elsif ($N == 1) {
		return abs( $X->get_quick(0) );
	}

	my $i = -1;
	while ( ++$i < $N ) {
		my $x = $X->get_quick($i);

		unless ($x == 0) {
			my $ax = abs($x);

			if ($scale < $ax) {
				$ssq   = 1.0 + $ssq * ($scale / $ax) * ($scale / $ax);
				$scale = $ax;
			} else {
				$ssq += ($ax / $scale) * ($ax / $scale);
			}
		}
	}

	return $scale * sqrt($ssq);
}


# Absolute sum of vector

sub blas_asum ($) {
	# Calculates absolute sum of a vector
	my ($X) = @_;

	my $N = $X->size;
	my $r = 0.0;

	my $i = -1;
	while ( ++$i < $N ) {
		$r += abs( $X->get($i) );
	}	

	return $r;
}


# Absolute maximum element of vector

sub blas_iamax ($) {
	my ($X) = @_;

	my $N = $X->size;

	my $max = 0.0;
	my $r   = 0;

	my $i = -1;
	while ( ++$i < $N ) {
		if (abs( $X->get_quick($i) ) > $max) {
			$max = abs($X->get_quick($i));
			$r   = $i;
		}
	}

	return $r;
}


# Swap vectors 

sub blas_swap ($$) {
	my ($X, $Y) = @_;

	if ($X->size == $Y->size) {

		my $N = $X->size; 

		my $i = -1;
		while ( ++$i < $N ) {
			my $tmp = $X->get_quick($i);
			$X->set_quick($i, $Y->get($i));
			$Y->set_quick($i, $tmp);
		}
	} else {
		trace_error("Invalid length");
	}
}


# Copy vectors

sub blas_copy ($$) {
	my ($X, $Y) = @_;

	if ($X->size == $Y->size) {

		my $N = $X->size;

		my $i = -1;
		while ( ++$i < $N ) {
			$Y->set_quick($i, $X->get_quick($i));
		}

	} else {
		trace_error("Invalid length");
	}
}

# Compute Y = alpha X + Y

sub blas_axpy ($$$) {
	my ($alpha, $X, $Y) = @_;

	if ($X->size == $Y->size) {

		return if ($alpha == 0.0);

		my $N = $X->size;
		
		#NOTE: Loop unrolling doesn't really improve speed 
		# unless array elements are accessed directly
		#my $m = $N % 4;

		#my $i = -1;
		#while ( ++$i < $m) {
		#	$Y->set_quick( $i, $alpha * $X->get_quick($i) );
		#}

		#$i = $m;
		#while ( $i + 3 < $N ) {
		#	$Y->set_quick($i  , $Y->get_quick($i  ) + $alpha * $X->get_quick($i  ));
		#	$Y->set_quick($i+1, $Y->get_quick($i+1) + $alpha * $X->get_quick($i+1));
		#	$Y->set_quick($i+2, $Y->get_quick($i+2) + $alpha * $X->get_quick($i+2));
		#	$Y->set_quick($i+3, $Y->get_quick($i+3) + $alpha * $X->get_quick($i+3));
		#	$i += 4;
		#}

		my $i = -1;
		while ( ++$i < $N ) {
			$Y->set_quick($i, $Y->get_quick($i) + $alpha * $X->get_quick($i) );
		}

	} else {
		trace_error("Invalid length");
	}
}

sub blas_rotg {
	...
}

sub blas_rot {
	...
}

sub blas_rotmg {
	...
}

sub blas_rotm {
	...
}

# Scale vector

sub blas_scal ($$) {
	my ($alpha, $X) = @_;

	my $N = $X->size;

	my $i = -1;
	while ( ++$i < $N ) {
		$X->set_quick( $i, $alpha * $X->get_quick($i) );
	}
}

#==============================================================================
# Level 2
#==============================================================================


# Matrix-vector product with a general matrix

sub blas_gemv ($$$$$$) {
	my ($TransA, $alpha, $A, $X, $beta, $Y) = @_;

	my $M = $A->rows;
	my $N = $A->columns;

	my $Trans = ($TransA != BlasConjTrans) ? $TransA : BlasTrans;

	if (($TransA == BlasNoTrans && $N == $X->size && $M == $Y->size)
	    || ($TransA == BlasTrans && $M == $X->size && $N == $Y->size)) {

		return if ($M == 0 || $N == 0);	
		return if ($alpha == 0.0 && $beta == 1.0);

		my ($i,$j);
		my ($lenX, $lenY);

		if ($Trans == BlasNoTrans) {
			$lenX = $N;
			$lenY = $M;
		} else {
			$lenX = $M;
			$lenY = $N;
		}

		# Form y := beta*y
		if ($beta == 0.0) {
			$i = -1;
			while ( ++$i < $lenY ) {
				$Y->set_quick($i, 0.0);
			}
		} elsif ($beta != 1.0) {
			$i = -1;
			while ( ++$i < $lenY ) {
				$Y->set_quick( $i, $Y->get_quick($i) * $beta );
			}
		}

		return if ($alpha == 0);

		if ($Trans == BlasNoTrans) {

			# Form y := alpha*A*x + y
			$i = -1;
			while ( ++$i < $lenY ) {
				my $temp = 0.0;

				$j = -1;
				while ( ++$j < $lenX ) {
					$temp += $X->get_quick($i) * $A->get_quick($i,$j);
				}

				$Y->set_quick( $i, $Y->get_quick($i) + $alpha * $temp );
			}
		} elsif ($Trans == BlasTrans) {

			# Form y := alpha*A'*x + y
			$j = -1;
			while ( ++$j < $lenX ) {
				my $temp = $alpha * $X->get_quick($i);

				if ($temp != 0.0) {
					$i = -1;
					while ( ++$i < $lenY ) {
						$Y->set_quick($i, $Y->get_quick($i) + $temp * $A->get_quick($j,$i))
					}
				}
			}
		} else {
			trace_error("Unrecognized operation");
		}
	} else {
		trace_error("Invalid length");
	}
}

sub blas_hemv {
	...
}


# Matrix-vector product with a symmetric matrix 

sub blas_symv ($$$$$$) {
	my ($UpLo, $alpha, $A, $X, $beta, $Y) = @_;

	my $M = $A->rows;
	my $N = $A->columns;

	# Dimension checks
	if ($M != $N) {
		trace_error("Matrix must be square");
	} elsif ($N != $X->size || $N != $Y->size) {
		trace_error("Invalid length");
	}

	return if ($alpha == 0.0 && $beta == 1.0);

	my ($i,$j);

	if ($beta == 0.0) {
		$i = -1;
		while ( ++$i < $N ) {
			$Y->set_quick($i, 0.0);
		}
	} elsif ($beta != 1.0) {
		$i = -1;
		while ( ++$i < $N ) {
			$Y->set_quick($i, $Y->get_quick * $beta );
		}
	}

	return if ($alpha == 0);

	if ($UpLo == BlasUpper) {
		$i = -1;
		while ( ++$i < $N ) {
			my $temp1 = $alpha * $X->get_quick($i);
			my $temp2 = 0.0;

			$Y->set_quick($i, $Y->get_quick($i) + $temp1 * $A->get_quick($i,$i));

			$j = $i;
			while ( ++$j < $N ) {
				$Y->set_quick($j, $Y->get_quick($j) + $temp1 * $A->get_quick($i,$j));
				$temp2 += $X->get_quick($j) * $A->get_quick($i,$j);
			}

			$Y->set_quick($i, $Y->get_quick($i) + $alpha * $temp2 );
		}
	} elsif ($UpLo == BlasLower) {
		$i = $N;
		while ( --$i >= 0 ) {
			my $temp1 = $alpha * $X->get_quick($i);
			my $temp2 = 0.0;

			$Y->set_quick($i, $Y->get_quick($i) + $temp1 * $A->get_quick($i,$i));

			$j = -1;
			while ( ++$j < $i ) {
				$Y->set_quick($j, $Y->get_quick($j) + $temp1 * $A->get_quick($i,$j));
				$temp2 += $X->get_quick($j) * $A->get_quick($i,$j);

			}

			$Y->set_quick($i, $Y->get_quick($i) + $alpha * $temp2 );
		}
	}
	
}


# Matrix-vector product with a triangular matrix

sub blas_trmv ($$$$$) {
	my ($UpLo, $TransA, $Diag, $A, $X) = @_;

	my $nonunit = ($Diag == BlasNonUnit);
	my $Trans   = ($TransA != BlasConjTrans) ? $TransA : BlasTrans;

	my $M = $A->rows;
	my $N = $A->columns;

	if ($M != $N) {
		trace_error("Matrix must be square");
	} elsif ($N != $X->size) {
		trace_error("Invalid length");
	}

	my ($i,$j);

	if ($Trans == BlasNoTrans && $UpLo == BlasUpper) {
		my $i = -1;
		while ( ++$i < $N ) {
			my $temp = 0.0;

			$j = $i - 1;
			while ( ++$j < $N ) {
				$temp += $X->get_quick($j) * $A->get_quick($i,$j);
			}
		
			if ($nonunit) {
				$X->set_quick($i, $temp + $X->get_quick($i) * $A->get_quick($i,$i));
			} else {
				$X->set_quick($i, $X->get_quick($i) + $temp);

			}
		}
	} elsif ($Trans == BlasNoTrans && $UpLo == BlasLower) {
		my $i = $N;
		while ( --$i >= 0 ) {
			my $temp = 0.0;

			$j = -1;
			while ( ++$j < $i ) {
				$temp += $X->get_quick($j) * $A->get_quick($i,$j);
			}
		
			if ($nonunit) {
				$X->set_quick($i, $temp + $X->get_quick($i) * $A->get_quick($i,$i));
			} else {
				$X->set_quick($i, $X->get_quick($i) + $temp);

			}
		}
	} elsif ($Trans == BlasTrans && $UpLo == BlasUpper) {
		my $i = $N;
		while ( --$i >= 0 ) {
			my $temp = 0.0;

			$j = -1;
			while ( ++$j < $i ) {
				$temp += $X->get_quick($j) * $A->get_quick($i,$j);
			}
		
			if ($nonunit) {
				$X->set_quick($i, $temp + $X->get_quick($i) * $A->get_quick($i,$i));
			} else {
				$X->set_quick($i, $X->get_quick($i) + $temp);

			}
		}
	} elsif ($Trans = BlasTrans && $UpLo == BlasLower) {
		my $i = -1;
		while ( ++$i < $N ) {
			my $temp = 0.0;

			$j = $i - 1;
			while ( ++$j < $N ) {
				$temp += $X->get_quick($j) * $A->get_quick($i,$j);
			}
		
			if ($nonunit) {
				$X->set_quick($i, $temp + $X->get_quick($i) * $A->get_quick($i,$i));
			} else {
				$X->set_quick($i, $X->get_quick($i) + $temp);

			}
		}
	} else {
		trace_error("Unrecognized operation");
	}
}


# Solve nonsingular triangular set of linear equations

sub blas_trsv ($$$$$) {
	my ($UpLo, $TransA, $Diag, $A, $X) = @_;

	my $M = $A->rows;
	my $N = $A->columns;
	
	#print "TRSV\nX: $X\nA:\n$A\n";

	if ($M != $N) {
		trace_error("Matrix must be square");
	} elsif ($N != $X->size) {
		trace_error("Invalid length");
	}

	my $nonunit = ($Diag == BlasNonUnit);
	my $Trans   = ($TransA != BlasConjTrans) ? $TransA : BlasTrans;

	return if ($N == 0);

	my ($i,$j);

	if ($Trans = BlasNoTrans && $UpLo == BlasUpper) {
		if ($nonunit) {
			$X->set_quick($N - 1, $X->get_quick($N - 1) / $A->get_quick($N-1,$N-1));
		}

		my $i = $N - 1;
		while ( --$i >= 0 ) {
			my $temp = $X->get_quick($i);

			$j = $i;
			while ( ++$j < $N ) {
				my $Aij = $A->get_quick($i,$j);
				$temp -= $Aij * $X->get_quick($j);
			}
		
			if ($nonunit) {
				$X->set_quick($i, $temp / $A->get_quick($i,$i));
			} else {
				$X->set_quick($i, $temp);

			}
		}
	} elsif ($Trans = BlasNoTrans && $UpLo == BlasLower) {
		if ($nonunit) {
			$X->set_quick(0, $X->get_quick(0) / $A->get_quick(0,0));
		}

		my $i = 0;
		while ( ++$i < $N ) {
			my $temp = $X->get_quick($i);

			$j = -1;
			while ( ++$j < $i ) {
				my $Aij = $A->get_quick($i,$j);
				$temp -= $Aij * $X->get_quick($j);
			}
		
			if ($nonunit) {
				$X->set_quick($i, $temp / $A->get_quick($i,$i));
			} else {
				$X->set_quick($i, $temp);

			}
		}
	} elsif ($Trans == BlasTrans && $UpLo == BlasUpper) {
		if ($nonunit) {
			$X->set_quick(0, $X->get_quick(0) / $A->get_quick(0,0));
		}

		my $i = 0;
		while ( ++$i < $N ) {
			my $temp = $X->get_quick($i);

			$j = -1;
			while ( ++$j < $i ) {
				my $Aji = $A->get_quick($j,$i);
				$temp -= $Aji * $X->get_quick($j);
			}
		
			if ($nonunit) {
				$X->set_quick($i, $temp / $A->get_quick($i,$i));
			} else {
				$X->set_quick($i, $temp);

			}
		}
	} elsif ($Trans == BlasTrans && $UpLo == BlasLower) {
		if ($nonunit) {
			$X->set_quick($N - 1, $X->get_quick($N - 1) / $A->get_quick($N-1,$N-1));
		}

		my $i = $N - 1;
		while ( --$i >= 0 ) {
			my $temp = $X->get_quick($i);

			$j = $i;
			while ( ++$j < $N ) {
				my $Aji = $A->get_quick($j,$i);
				$temp -= $Aji * $X->get_quick($j);
			}
		
			if ($nonunit) {
				$X->set_quick($i, $temp / $A->get_quick($i,$i));
			} else {
				$X->set_quick($i, $temp);

			}
		}
	} else {
		trace_error("Unrecognized operation");
	}
}


# General rank-1 update

sub blas_ger ($$$$) {
	my ($alpha, $X, $Y, $A) = @_;

	my $M = $A->rows;
	my $N = $A->columns;

	if ($X->size == $M && $Y->size == $N) {
		my $i = -1;
		while ( ++$i < $M) {
			my $tmp = $alpha * $X->get_quick($i);

			my $j = -1;
			while ( ++$j < $N ) {
				$A->set_quick($i,$j, $A->get_quick($i,$j) + $Y->get_quick($j) * $tmp);
			}
		}
	} else {
		trace_error("Invalid length");
	}
}


sub blas_geru {
	...
}

sub blas_gerc {
	...
}

sub blas_her {
	...
}

sub blas_her2 {
	...
}


# Symmetric rank-1 update

sub blas_syr {
	my ($UpLo, $alpha, $X, $A) = @_;

	my $M = $A->rows;
	my $N = $A->columns;

	if ($M != $N) {
		trace_error("Matrix must be square");
	} elsif ($X->size != $N) {
		trace_error("Invalid length");
	}

	return if ($N == 0);
	return if ($alpha == 0.0);

	if ($UpLo == BlasUpper) {
		my $i = -1;
		while ( ++$i < $N ) {
			my $tmp = $alpha * $X->get_quick($i);

			my $j = $i - 1;
			while ( ++$j < $N ) {
				$A->set_quick($i,$j, $A->get_quick($i,$j) + $X->get_quick($j) * $tmp);
			}
		}
	} elsif ($UpLo == BlasLower) {
		my $i = -1;
		while ( ++$i < $N ) {
			my $tmp = $alpha * $X->get_quick($i);

			my $j = -1;
			while ( ++$j < $i ) {
				$A->set_quick($i,$j, $A->get_quick($i,$j) + $X->get_quick($j) * $tmp);
			}
		}
	} else {
		trace_error("Unrecognized operation");
	}
}


# Symmetric rank-2 update

sub blas_syr2 {
	my ($UpLo, $alpha, $X, $Y, $A) = @_;

	my $M = $A->rows;
	my $N = $A->columns;

	if ($M != $N) {
		trace_error("Matrix must be square");
	} elsif ($X->size != $N || $Y->size != $N) {
		trace_error("Invalid length");
	}

	return if ($N == 0);
	return if ($alpha == 0.0);

	if ($UpLo == BlasUpper) {
		my $i = -1;
		while ( ++$i < $N ) {
			my $tmp1 = $alpha * $X->get_quick($i);
			my $tmp2 = $alpha * $Y->get_quick($i);

			my $j = $i - 1;
			while ( ++$j < $N ) {
				$A->set_quick($i,$j, $A->get_quick($i,$j) 
					+ $tmp1 * $Y->get_quick($j)
					+ $tmp2 * $X->get_quick($j));
			}
		}
	} elsif ($UpLo == BlasLower) {
		my $i = -1;
		while ( ++$i < $N ) {
			my $tmp1 = $alpha * $X->get_quick($i);
			my $tmp2 = $alpha * $Y->get_quick($i);

			my $j = -1;
			while ( ++$j < $i ) {
				$A->set_quick($i,$j, $A->get_quick($i,$j) 
					+ $tmp1 * $Y->get_quick($j)
					+ $tmp2 * $X->get_quick($j));
			}
		}
	} else {
		trace_error("Unrecognized operation");
	}
}

#==============================================================================
# Level 3
#==============================================================================


# Matrix-matrix product of two general matrices

sub blas_gemm ($$$$$$$) {
	my ($TransA, $TransB, $alpha, $A, $B, $beta, $C) = @_;

	my $M = $C->rows;
	my $N = $C->columns;
	my $MA = ($TransA == BlasNoTrans) ? $A->rows    : $A->columns;
	my $NA = ($TransA == BlasNoTrans) ? $A->columns : $A->rows;
	my $MB = ($TransB == BlasNoTrans) ? $B->rows    : $B->columns;
	my $NB = ($TransB == BlasNoTrans) ? $B->columns : $B->rows;

	if ($M == $MA && $N == $NB && $NA == $MB) {

		return if ($alpha == 0.0 && $beta == 1.0);

		my ($i,$j,$k);
		my $K = $NA;

		# Form y := beta * y
		if ($beta == 0.0) {
			$i = -1;
			while ( ++$i < $M ) {
				$j = -1;
				while ( ++$j < $N ) {
					$C->set_quick($i,$j, 0.0);
				}
			}
		} elsif ($beta != 1.0) {
			$i = -1;
			while ( ++$i < $M ) {
				$j = -1;
				while ( ++$j < $N ) {
					$C->set_quick($i,$j, $C->get_quick($i,$j) * $beta);
				}
			}
			
		}

		return if ($alpha == 0.0);

		if ($TransA == BlasNoTrans && $TransB == BlasNoTrans) {

			# Form C := alpha * A * B + C
			$k = -1;
			while ( ++$k < $K) {
				$i = -1;
				while ( ++$i < $M ) {
					my $temp = $alpha * $A->get_quick($i,$k);
					if ($temp != 0) {
						$j = -1;
						while ( ++$j < $N ) {
							$C->set_quick($i,$j, $C->get_quick($i,$j)
								+ $temp * $B->get_quick( $k, $j ));
						}
					}
				}
			}
		} elsif ($TransA == BlasNoTrans && $TransB == BlasTrans) {

			# Form C := alpha * A * B' + C
			$i = -1;
			while ( ++$i < $M ) {
				$j = -1;
				while ( ++$j < $N ) {
					my $temp = 0.0;
					if ($temp != 0) {
						$k = -1;
						while ( ++$k < $K ) {
							$temp += $A->get_quick($i,$k) * $B->get_quick($j,$k)
						}

						$C->set_quick($i,$j, $C->get_quick($i,$j)
							+ $alpha * $temp );
					}
				}
			}

		} elsif ($TransA == BlasTrans && $TransB == BlasNoTrans) {
			$k = -1;
			while ( ++$k < $K) {
				$i = -1;
				while ( ++$i < $M ) {
					my $temp = $alpha * $A->get_quick($k,$i);
					if ($temp != 0) {
						$j = -1;
						while ( ++$j < $N ) {
							$C->set_quick($i,$j, $C->get_quick($i,$j)
								+ $temp * $B->get_quick( $k, $j ));
						}
					}
				}
			}

		} elsif ($TransA == BlasTrans && $TransB == BlasTrans) {
			$i = -1;
			while ( ++$i < $M ) {
				$j = -1;
				while ( ++$j < $N ) {
					my $temp = 0.0;
					if ($temp != 0) {
						$k = -1;
						while ( ++$k < $K ) {
							$temp += $A->get_quick($k,$i) * $B->get_quick($j,$k)
						}

						$C->set_quick($i,$j, $C->get_quick($i,$j)
							+ $alpha * $temp );
					}
				}
			}
		} else {
			trace_error("Unrecognized operation");
		}
	} else {
		trace_error("Invalid length");
	}
}


# Matrix-matrix product of a symmetric matrix A and a general matrix B

sub blas_symm ($$$$$$$) {
	my ($Side, $UpLo, $alpha, $A, $B, $beta, $C) = @_;

	my $M  = $C->rows;
	my $N  = $C->columns;
	my $MA = $A->rows;
	my $NA = $A->columns;
	my $MB = $B->rows;
	my $NB = $B->columns;

	if ($MA != $NA) {
		trace_error("Matrix A must be square");
	}

	if (($Side == BlasLeft && ($M == $MA && $N == $NB && $NA == $MB))
	    || ($Side == BlasRight && ($M == $MB && $N == $NA && $NB == $MA)))  {
		return if ($alpha == 0.0 && $beta == 1.0);

		my ($i,$j,$k);
	
		# Form y := beta * y
		if ($beta == 0) {

			# $C->assign(0);
			$i = -1;
			while ( ++$i < $M ) {

				$j = -1;
				while ( ++$j < $N ) {
					$C->set_quick( $i, $j, 0.0);
				}
			}
		} elsif ($beta != 1.0) {

			# $C->assign( sub { $_[0] * $beta } );
			$i = -1;
			while ( ++$i < $M ) {

				$j = -1;
				while ( ++$j < $N ) {
					$C->set_quick( $i, $j, $C->get_quick( $i, $j) * $beta );
				}
			}

		}

		return if ($alpha == 0.0);

		if ($Side = BlasLeft && $UpLo == BlasUpper) {

			# Form C := alpha * A * B + C
			$i = -1;
			while ( ++$i < $M ) {

				$j = -1;
				while ( ++$j < $N ) {
					my $temp1 = $alpha * $B->get_quick($i,$j);
					my $temp2 = 0.0;

					$C->set_quick($i,$j, $C->get_quick($i,$j)
						+ $temp1 * $A->get_quick($i,$i));

					$k = $i;
					while ( ++$k < $M ) {
						my $Aik = $A->get_quick($i,$k);

						$C->set_quick($k,$j, $C->get_quick($k,$j)
							+ $Aik * $temp1);
						$temp2 += $Aik * $B->get_quick($k,$j);
					}

					$C->set_quick($i,$j, $C->get_quick($i,$j) + $alpha * $temp2)
				}
			}
		} elsif ($Side == BlasLeft && $UpLo == BlasLower) {

			# Form C := alpha * A * B + C
			$i = -1;
			while ( ++$i < $M ) {

				$j = -1;
				while ( ++$j < $N ) {
					my $temp1 = $alpha * $B->get_quick($i,$j);
					my $temp2 = 0.0;

					$C->set_quick($i,$j, $C->get_quick($i,$j)
						+ $temp1 * $A->get_quick($i,$i));

					$k = -1;
					while ( ++$k < $i ) {
						my $Aik = $A->get_quick($i,$k);

						$C->set_quick($k,$j, $C->get_quick($k,$j)
							+ $Aik * $temp1);
						$temp2 += $Aik * $B->get_quick($k,$j);
					}

					$C->set_quick($i,$j, $C->get_quick($i,$j)
						+ $temp1 * $A->get_quick($i,$i)
						+ $alpha * $temp2);
				}
			}
		} elsif ($Side == BlasRight && $UpLo == BlasUpper) {

			# Form C := alpha * B * A + C
			$i = -1;
			while ( ++$i < $M ) {

				$j = -1;
				while ( ++$j < $N ) {
					my $temp1 = $alpha * $B->get_quick($i,$j);
					my $temp2 = 0.0;

					$C->set_quick($i,$j, $C->get_quick($i,$j)
						+ $temp1 * $A->get_quick($j,$j));

					$k = $j;
					while ( ++$k < $N ) {
						my $Ajk = $A->get_quick($j,$k);

						$C->set_quick($i,$k, $C->get_quick($k,$j)
							+ $Ajk * $temp1);
						$temp2 += $Ajk * $B->get_quick($i,$k);
					}

					$C->set_quick($i,$j, $C->get_quick($i,$j)
						+ $alpha * $temp2);
				}
			}
		} elsif ($Side == BlasRight && $UpLo == BlasLower) {

			# Form C := alpha * B * A + C
			$i = -1;
			while ( ++$i < $M ) {

				$j = -1;
				while ( ++$j < $N ) {
					my $temp1 = $alpha * $B->get_quick($i,$j);
					my $temp2 = 0.0;

					$C->set_quick($i,$j, $C->get_quick($i,$j)
						+ $temp1 * $A->get_quick($j,$j));

					$k = -1;
					while ( ++$k < $j ) {
						my $Ajk = $A->get_quick($j,$k);

						$C->set_quick($i,$k, $C->get_quick($k,$j)
							+ $Ajk * $temp1);
						$temp2 += $Ajk * $B->get_quick($i,$k);
					}

					$C->set_quick($i,$j, $C->get_quick($i,$j)
						+ $temp1 * $A->get_quick($j,$i)
						+ $alpha * $temp2);
				}
			}
		} else {
			trace_error("Unrecognized operation");
		}	
	} else {
		trace_error("Invalid length");
	}
}

sub blas_hemm {
	...
}

# Rank-k update of a symmetric matrix C

sub blas_syrk ($$$$$$) {
	my ($UpLo, $Trans, $alpha, $A, $beta, $C) = @_;

	my $M = $C->rows;
	my $N = $C->columns;
	my $J = ($Trans == BlasNoTrans) ? $A->rows : $A->columns;
	my $K = ($Trans == BlasNoTrans) ? $A->columns: $A->rows;

	if ($M != $N) {
		trace_error("Matrix C must be square");
	} elsif ($N != $J) {
		trace_error("Invalid length");
	}

	my ($i,$j,$k);

	return if ($alpha == 0.0 && $beta == 1.0);

	if ($beta == 0) {
		if ($UpLo == BlasUpper) {

			$i = -1;
			while ( ++$i < $N ) {

				$j = $i - 1;
				while ( ++$j < $M ) {
					$C->set_quick($i,$j,0);
				}
			}
		} else {

			$i = -1;
			while ( ++$i < $N ) {

				$j = -1;
				while ( ++$j < $i ) {
					$C->set_quick($i,$j,0);
				} 
			}
		}
	} elsif ($beta != 1.0) {
		if ($UpLo == BlasUpper) {

			$i = -1;
			while ( ++$i < $N ) {

				$j = $i - 1;
				while ( ++$j < $M ) {
					$C->set_quick($i,$j, $C->get_quick($i,$j) * $beta);
				}
			}
		} else {

			$i = -1;
			while ( ++$i < $N ) {

				$j = -1;
				while ( ++$j <= $i ) {
					$C->set_quick($i,$j, $C->get_quick($i,$j) * $beta);
				} 
			}
		}
	}

	return if ($alpha == 0.0);

	if ($UpLo == BlasUpper && $Trans == BlasNoTrans) {

		$i = -1;
		while ( ++$i < $N ) {
			$j = $i - 1;
			while ( ++$j < $N ) {
				my $temp = 0.0;

				$k = -1;
				while ( ++$k < $K ) {
					$temp += $A->get_quick($i,$k) * $A->get_quick($j,$k);
				}

				$C->set_quick($i,$j, $C->get_quick($i,$k) + $alpha * $temp);
			}
		}
	} elsif ($UpLo == BlasUpper && $Trans == BlasTrans) {

		$i = -1;
		while ( ++$i < $N ) {
			$j = $i - 1;
			while ( ++$j < $N ) {
				my $temp = 0.0;

				$k = -1;
				while ( ++$k < $K ) {
					$temp += $A->get_quick($k,$i) * $A->get_quick($k,$j);
				}

				$C->set_quick($i,$j, $C->get_quick($i,$k) + $alpha * $temp);
			}
		}

	} elsif ($UpLo == BlasLower && $Trans == BlasNoTrans) {

		$i = -1;
		while ( ++$i < $N ) {
			$j = - 1;
			while ( ++$j < $i ) {
				my $temp = 0.0;

				$k = -1;
				while ( ++$k < $K ) {
					$temp += $A->get_quick($i,$k) * $A->get_quick($j,$k);
				}

				$C->set_quick($i,$j, $C->get_quick($i,$k) + $alpha * $temp);
			}
		}

	} elsif ($UpLo == BlasLower && $Trans == BlasTrans) {

		$i = -1;
		while ( ++$i < $N ) {
			$j = - 1;
			while ( ++$j < $i ) {
				my $temp = 0.0;

				$k = -1;
				while ( ++$k < $K ) {
					$temp += $A->get_quick($k,$i) * $A->get_quick($k,$j);
				}

				$C->set_quick($i,$j, $C->get_quick($i,$k) + $alpha * $temp);
			}
		}

	} else {
		trace_error("Unrecognized operation");
	}
}

sub blas_herk {
	...
}

sub blas_syr2k {

}

sub blas_her2k {
	...
}


# Matrix-matrix product of a triangular matrix A and a general matrix B

sub blas_trmm ($$$$$$$) {
	my ($Side, $UpLo, $TransA, $Diag, $alpha, $A, $B) = @_;

	my $M  = $B->rows;
	my $N  = $B->columns;
	my $MA = $A->rows;
	my $NA = $A->columns;

	if ($MA != $NA) {
		trace_error("Matrix A must be square");
	}

	if (($Side == BlasLeft && $M == $MA) || ($Side == BlasRight && $N == $MA)) {
		my ($i,$j,$k);

		my $nonunit = ($Diag == BlasNonUnit);
		my $Trans   = ($TransA == BlasConjTrans) ? BlasTrans : $TransA;

		if ($Side == BlasLeft && $UpLo == BlasUpper && $Trans == BlasNoTrans) {

			# Form B := alpha * TriU(A) * B
			$i = -1;
			while ( ++$i < $M ) {
				
				$j = -1;
				while ( ++$j < $N ) {
					my $temp = 0.0;

					if ($nonunit) {
						$temp = $A->get_quick($i,$i) * $B->get_quick($i,$j);
					} else {
						$temp = $B->get_quick($i,$j);
					}

					$k = $i;
					while ( ++$k < $M ) {
						$temp += $A->get_quick($i,$k) * $B->get_quick($k,$j);
					}

					$B->set_quick($i,$j, $alpha * $temp);
				}
			}

		} elsif ($Side == BlasLeft && $UpLo == BlasUpper && $Trans == BlasTrans) {

			# Form B := alpha * (Tri(U))' * B
			$i = $M;
			while ( --$i >= 0 ) {
				
				$j = -1;
				while ( ++$j < $N ) {
					my $temp = 0.0;

					$k = -1;
					while ( ++$k < $i ) {
						$temp += $A->get_quick($k,$i) * $B->get_quick($k,$j);
					}

					if ($nonunit) {
						$temp = $A->get_quick($i,$i) * $B->get_quick($i,$j);
					} else {
						$temp = $B->get_quick($i,$j);
					}

					$B->set_quick($i,$j, $alpha * $temp);
				}
			}
		} elsif ($Side == BlasLeft && $UpLo == BlasLower && $Trans == BlasNoTrans) {

			# Form B := alpha * TriL(A) * B
			$i = $M;
			while ( --$i >= 0 ) {
				
				$j = -1;
				while ( ++$j < $N ) {
					my $temp = 0.0;

					$k = -1;
					while ( ++$k < $i ) {
						$temp += $A->get_quick($i,$k) * $B->get_quick($k,$j);
					}

					if ($nonunit) {
						$temp += $A->get_quick($i,$i) * $B->get_quick($i,$j);
					} else {
						$temp += $B->get_quick($i,$j)
					}

					$B->set_quick($i,$j, $alpha * $temp);
				}
			}

		} elsif ($Side == BlasLeft && $UpLo == BlasLower && $Trans == BlasTrans) {

			# Form B := alpha * TriL(A)' * B
			$i = -1;
			while ( ++$i < $M ) {
				
				$j = -1;
				while ( ++$j < $N ) {
					my $temp = 0.0;

					if ($nonunit) {
						$temp += $A->get_quick($i,$i) * $B->get_quick($i,$j);
					} else {
						$temp += $B->get_quick($i,$j)
					}

					$k = $i;
					while ( ++$k < $M ) {
						$temp += $A->get_quick($k,$i) * $B->get_quick($k,$j);

					}

					$B->set_quick($i,$j, $alpha * $temp);
				}
			}

		} elsif ($Side == BlasRight && $UpLo == BlasUpper && $Trans == BlasNoTrans) {

			# Form B := alpha * B * TriU(A)
			$i = -1;
			while ( ++$i < $M ) {
				
				$j = $N;
				while ( --$j >= 0 ) {
					my $temp = 0.0;

					$k = -1;
					while ( ++$k < $j ) {
						$temp += $A->get_quick($k,$j) * $B->get_quick($i,$k);
					}

					if ($nonunit) {
						$temp += $A->get_quick($j,$j) * $B->get_quick($i,$j);
					} else {
						$temp += $B->get_quick($i,$j)
					}

					$B->set_quick($i,$j, $alpha * $temp);
				}
			}

		} elsif ($Side == BlasRight && $UpLo == BlasUpper && $Trans == BlasTrans) {

			# Form B := alpha * B * (TriU(A))'
			$i = -1;
			while ( ++$i < $M ) {
				
				$j = -1;
				while ( ++$j < $N ) {
					my $temp = 0.0;

					if ($nonunit) {
						$temp += $A->get_quick($j,$j) * $B->get_quick($i,$j);
					} else {
						$temp += $B->get_quick($i,$j)
					}

					$k = $j;
					while ( ++$k < $N ) {
						$temp += $A->get_quick($j,$k) * $B->get_quick($i,$k);
					}

					$B->set_quick($i,$j, $alpha * $temp);
				}
			}
		} elsif ($Side == BlasRight && $UpLo == BlasLower && $Trans == BlasNoTrans) {

			# Form B := alpha * B * TriL(A)
			$i = -1;
			while ( ++$i < $M ) {
				
				$j = -1;
				while ( ++$j < $N ) {
					my $temp = 0.0;

					if ($nonunit) {
						$temp += $A->get_quick($j,$j) * $B->get_quick($i,$j);
					} else {
						$temp += $B->get_quick($i,$j)
					}
					
					$k = $j;
					while ( ++$k < $N ) {
						$temp += $A->get_quick($k,$j) * $B->get_quick($i,$k);
					}

					$B->set_quick($i,$j, $alpha * $temp);
				}
			}

		} elsif ($Side == BlasRight && $UpLo == BlasLower && $Trans == BlasTrans) {

			# Form B := alpha * B * TriL(A)'
			$i = -1;
			while ( ++$i < $M ) {
				
				$j = $N;
				while ( --$j >= 0 ) {
					my $temp = 0.0;

					$k = -1;
					while ( ++$k < $j ) {
						$temp += $A->get_quick($j,$k) * $B->get_quick($i,$k);
					}

					if ($nonunit) {
						$temp += $A->get_quick($j,$j) * $B->get_quick($i,$j);
					} else {
						$temp += $B->get_quick($i,$j)
					}

					$B->set_quick($i,$j, $alpha * $temp);
				}
			}

		} else {
			trace_error("Unrecognized operation");
		}
	}
}


# Solve a nonsingular triangular system of equations

sub blas_trsm ($$$$$$$) {
	my ($Side, $UpLo, $TransA, $Diag, $alpha, $A, $B) = @_;

	my $M  = $B->rows;
	my $N  = $B->columns;
	my $MA = $A->rows;
	my $NA = $A->columns;

	if ($MA != $NA) {
		trace_error("Matrix A must be square");
	}

	if (($Side == BlasLeft && $M == $MA) || ($Side == BlasRight && $N == $MA)) {
		my ($i,$j,$k);

		my $nonunit = ($Diag == BlasNonUnit);
		my $Trans   = ($TransA == BlasConjTrans) ? BlasTrans : $TransA;

		if ($Side == BlasLeft && $UpLo == BlasUpper && $Trans == BlasNoTrans) {

			# Form B := alpha * inv(TriU(A)) * B
			if ($alpha != 1.0) {

				$i = -1;
				while ( ++$i < $M ) {
				
					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($i,$j, $B->get_quick($i,$j) * $alpha);
					}
				}
			}

			$i = $M;
			while ( --$i >= 0 ) {
				if ($nonunit) {
					my $Aii = $A->get_quick($i,$i);

					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($i,$j, $B->get_quick($i,$j) / $Aii);
					}
				}

				$k = -1;
				while ( ++$k < $i ) {
					my $Aki = $A->get_quick($k,$i);

					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($k,$j, $B->get_quick($k,$j) 
							- $Aki * $B->get_quick($i,$j));
					}
				}
			}
		} elsif ($Side == BlasLeft && $UpLo == BlasUpper && $Trans == BlasTrans) {

			# Form B := alpha * inv(TriU(A))' * B
			if ($alpha != 1.0) {

				$i = -1;
				while ( ++$i < $M ) {
				
					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($i,$j, $B->get_quick($i,$j) * $alpha);
					}
				}
			}

			$i = -1;
			while ( ++$i < $M ) {
				if ($nonunit) {
					my $Aii = $A->get_quick($i,$i);

					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($i,$j, $B->get_quick($i,$j) / $Aii);
					}
				}

				$k = $i;
				while ( ++$k < $M ) {
					my $Aik = $A->get_quick($i,$k);

					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($k,$j, $B->get_quick($k,$j) 
							- $Aik * $B->get_quick($i,$j));
					}
				}
			}
		} elsif ($Side == BlasLeft && $UpLo == BlasLower && $Trans == BlasNoTrans) {

			# Form B := alpha * inv(TriL(A)) * B
			if ($alpha != 1.0) {

				$i = -1;
				while ( ++$i < $M ) {
				
					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($i,$j, $B->get_quick($i,$j) * $alpha);
					}
				}
			}

			$i = -1;
			while ( ++$i < $M ) {
				if ($nonunit) {
					my $Aii = $A->get_quick($i,$i);

					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($i,$j, $B->get_quick($i,$j) / $Aii);
					}
				}

				$k = $i;
				while ( ++$k < $M ) {
					my $Aki = $A->get_quick($k,$i);

					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($k,$j, $B->get_quick($k,$j) 
							- $Aki * $B->get_quick($i,$j));
					}
				}
			}
		} elsif ($Side == BlasLeft && $UpLo == BlasLower && $Trans == BlasTrans) {

			# Form B := alpha * inv(TriL(A))' * B
			if ($alpha != 1.0) {

				$i = -1;
				while ( ++$i < $M ) {
				
					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($i,$j, $B->get_quick($i,$j) * $alpha);
					}
				}
			}

			$i = $M;
			while ( --$i >= 0 ) {
				if ($nonunit) {
					my $Aii = $A->get_quick($i,$i);

					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($i,$j, $B->get_quick($i,$j) / $Aii);
					}
				}

				$k = -1;
				while ( ++$k < $i ) {
					my $Aik = $A->get_quick($i,$k);

					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($k,$j, $B->get_quick($k,$j) 
							- $Aik * $B->get_quick($i,$j));
					}
				}
			}
		} elsif ($Side == BlasRight && $UpLo == BlasUpper && $Trans == BlasNoTrans) {

			# Form B := alpha * B * inv(TriU(A))
			if ($alpha != 1.0) {

				$i = -1;
				while ( ++$i < $M ) {
				
					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($i,$j, $B->get_quick($i,$j) * $alpha);
					}
				}
			}

			$i = -1;
			while ( ++$i < $M ) {

				$j = -1;
				while ( ++$j < $N ) {
					if ($nonunit) {
						my $Ajj = $A->get_quick($j,$j);

						$B->set_quick($i,$j, $B->get_quick($i,$j) / $Ajj);
					}

					{
						my $Bij = $B->get_quick($i,$j);
						
						$k = $j;
						while ( ++$k < $N ) {
							$B->set_quick($i,$k, $B->get_quick($i,$k) 
								- $A->get_quick($j,$k) * $Bij);
						}
					}
				}
			}
		} elsif ($Side == BlasRight && $UpLo == BlasUpper && $Trans == BlasTrans) {

			# Form B := alpha * B * inv(TriU(A))'
			if ($alpha != 1.0) {

				$i = -1;
				while ( ++$i < $M ) {
				
					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($i,$j, $B->get_quick($i,$j) * $alpha);
					}
				}
			}

			$i = -1;
			while ( ++$i < $M ) {

				$j = $N;
				while ( --$j >= 0 ) {
					if ($nonunit) {
						my $Ajj = $A->get_quick($j,$j);

						$B->set_quick($i,$j, $B->get_quick($i,$j) / $Ajj);
					}

					{
						my $Bij = $B->get_quick($i,$j);
						
						$k = -1;
						while ( ++$k < $j ) {
							$B->set_quick($i,$k, $B->get_quick($i,$k) 
								- $A->get_quick($k,$j) * $Bij);
						}
					}
				}
			}
		} elsif ($Side == BlasRight && $UpLo == BlasLower && $Trans == BlasNoTrans) {

			# Form B := alpha * B * inv(TriL(A))
			if ($alpha != 1.0) {

				$i = -1;
				while ( ++$i < $M ) {
				
					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($i,$j, $B->get_quick($i,$j) * $alpha);
					}
				}
			}

			$i = -1;
			while ( ++$i < $M ) {

				$j = $N;
				while ( --$j >= 0 ) {
					if ($nonunit) {
						my $Ajj = $A->get_quick($j,$j);

						$B->set_quick($i,$j, $B->get_quick($i,$j) / $Ajj);
					}

					{
						my $Bij = $B->get_quick($i,$j);
						
						$k = -1;
						while ( ++$k < $j ) {
							$B->set_quick($i,$k, $B->get_quick($i,$k) 
								- $A->get_quick($j,$k) * $Bij);
						}
					}
				}
			}
		} elsif ($Side == BlasRight && $UpLo == BlasLower && $Trans == BlasTrans) {

			# Form B := alpha * B * inv(TriL(A))'
			if ($alpha != 1.0) {

				$i = -1;
				while ( ++$i < $M ) {
				
					$j = -1;
					while ( ++$j < $N ) {
						$B->set_quick($i,$j, $B->get_quick($i,$j) * $alpha);
					}
				}
			}

			$i = -1;
			while ( ++$i < $M ) {

				$j = -1;
				while ( ++$j < $N ) {
					if ($nonunit) {
						my $Ajj = $A->get_quick($j,$j);

						$B->set_quick($i,$j, $B->get_quick($i,$j) / $Ajj);
					}

					{
						my $Bij = $B->get_quick($i,$j);
						
						$k = $j;
						while ( ++$k < $N ) {
							$B->set_quick($i,$k, $B->get_quick($i,$k) 
								- $A->get_quick($k,$j) * $Bij);
						}
					}
				}
			}
		} else {
			trace_error("Unrecognized operation");
		}
	}
}


1;
