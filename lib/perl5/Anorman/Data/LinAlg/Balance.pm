package Anorman::Data::LinAlg::Balance;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data;
use Anorman::Data::LinAlg::BLAS qw( blas_scal blas_asum );
use Anorman::Data::LinAlg::Property qw( :matrix );

my $FLOAT_RADIX    = 2.0;
my $FLOAT_RADIX_SQ = ($FLOAT_RADIX * $FLOAT_RADIX);

sub balance_matrix {
	my $A = shift;

	check_matrix($A);

	my $N = $A->rows;

	my $D = $A->like_vector($N);
	$D->assign(1);

	my $not_converged = 1;

	while ($not_converged) {
		my ($i,$j);
		my ($g,$f,$s);
		my $v;

		$not_converged = 0;

		$i = -1;
		while ( ++$i < $N ) {
			my $row_norm = 0.0;
			my $col_norm = 0.0;

			$j = -1;
			while ( ++$j < $N ) {
				if ($j != $i) {
					$col_norm += abs($A->get($j,$i));
					$row_norm += abs($A->get($i,$j));
				}
			}

			continue if ($col_norm == 0.0 || $row_norm == 0.0);

			$g = $row_norm / $FLOAT_RADIX;
			$f = 1.0;
			$s = $col_norm + $row_norm;

			while ($col_norm < $g) {
				$f *= $FLOAT_RADIX;
				$col_norm *= $FLOAT_RADIX_SQ;
			}

			$g = $row_norm * $FLOAT_RADIX;

			while ($col_norm > $g) {
				$f /= $FLOAT_RADIX;
				$col_norm /= $FLOAT_RADIX_SQ;
			}

			if (($row_norm + $col_norm) < 0.95 * $s * $f) {
				$not_converged = 1;

				$g = 1.0 / $f;

				blas_scal($g, $A->view_row($i));
				blas_scal($f, $A->view_column($i));

				$D->set($i, $D->get($i) * $f);
			}
		}
	}
	
	return $D;
}

sub balance_column {
	my $A = shift;

	check_matrix($A);

	my $N = $A->columns;
	my $D = $A->like_vector($N);
	$D->assign(1);

	my $j = -1;
	while( ++$j < $N ) {
		my $A_j = $A->view_column($j);

		my $s = blas_dasum($A_j);
		my $f = 1.0;

		if ($s == 0) {
			$D->set($j, $f);
			continue;
		}

		while($s > 1.0) {
			$s /= 2.0;
			$f *= 2.0;
		}

		$D->set($j,$f);

		blas_scal(1.0/$f, $A_j) if ($f != 1.0);
	}
	
	return $D;
}

1;
