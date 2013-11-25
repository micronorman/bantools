package Anorman::Data::LinAlg::EigenValueDecomposition;

use strict;

use Anorman::Common;
use Anorman::Math::Common;
use Anorman::Data;
use Anorman::Data::LinAlg::Property qw( :matrix );

use List::Util qw(max);

sub new {
	my $class = shift;
	my $A     = shift;

	check_matrix( $A );
	check_square( $A );

	my $self  = { };

	bless ($self, ref($class) || $class);
	
	my $n = $A->rows;

	# set up internals
	$self->{'_n'}                      = $n;
	$self->{'_V'}->[ $n - 1][ $n - 1 ] = undef;
	$self->{'_d'}->[ $n - 1]           = undef;
	$self->{'_e'}->[ $n - 1]           = undef;

	if (is_symmetric($A)) {
		my $i = -1;

		while (++$i < $n) {
			my $j = -1;
			while (++$j < $n ) {
				$self->{'_V'}->[ $i ][ $j ] = $A->get_quick( $i, $j );
			}
		}

		$self->_tridiagonal();
		$self->_tridiagonal_QL();	
	} else {
		$self->{'_H'}->[ $n - 1 ][ $n -1 ] = undef;
		$self->{'_ort'}->[ $n - 1 ]        = undef;

		my $i = -1;

		while (++$i < $n) {
			my $j = -1;
			while (++$j < $n) {
				$self->{'_H'}->[ $i ][ $j ] = $A->get_quick( $i, $j );
			}
		}

		trace_error("Actually, Non-symmetric matrix decomposition has not been implemented...");
	}

	return $self;
}

sub getD {
	my $self = shift;
	my $d    = $self->{'_d'};
	my $V    = $self->{'_V'};
	my $n    = $self->{'_n'};
	my $e    = $self->{'_e'};
	my $D    = [[]];
	
	my $i = -1;
	while ( ++$i < $n ) {

		my $j = -1;
		while ( ++$j < $n ) {
			$D->[$i][$j] = 0.0;
		}

		$D->[$i][$i] = $d->[$i];
		if ($e->[$i] > 0) {
			$D->[$i][$i + 1] = $e->[$i];
		} elsif ($e->[$i] < 0) {
			$D->[$i][$i-1] = $e->[$i];
		}
	}
	
	return Anorman::Data->matrix($D);
}

sub getV {
	my $self = shift;
	return $self->{'_V'};
}

sub getRealEigenvalues {
	my $self = shift;
	return wantarray ? @{ $self->{'_d'} } : $self->{'_d'};
}

sub getImagEigenvalues {
	my $self = shift;
	return wantarray ? @{ $self->{'_e'} } : $self->{'_e'};
}

sub _tridiagonal_QL {
	my $self = shift;
	my $d    = $self->{'_d'};
	my $V    = $self->{'_V'};
	my $n    = $self->{'_n'};
	my $e    = $self->{'_e'};

	my $i = 0;
	while (++$i < $n) {
		$e->[ $i - 1 ] = $e->[ $i ]; 
	}

	$e->[ $n - 1 ] = 0.0;

	my $f    = 0.0;
	my $tst1 = 0.0;

	# machine epsilon
	my $eps = 2**-52;

	my $l = -1;
	while (++$l < $n) {
		$tst1 = max($tst1,  abs($d->[ $l ]) + abs($e->[ $l ]) );


		# find first small subdiagonal element
		my $m = $l;
		while ($m < $n) {
			if (abs($e->[ $m ]) <= $eps * $tst1) {
				last;
			}
			$m++;
		}

		if ($m > $l) {

			# iterate until convergence
			while (abs( $e->[ $l ] ) > $eps * $tst1) {
				my $g = $d->[ $l ];
				my $p = ($d->[ $l + 1 ] - $g) / (2.0 * $e->[ $l ]);
				my $r = Anorman::Math::Common::hypot( $p, 1.0);

				if ($p < 0) {
					$r = -$r;
				} 

				$d->[ $l ]     = $e->[ $l ] / ($p + $r);
				$d->[ $l + 1 ] = $e->[ $l ] * ($p + $r);

				my $dl1 = $d->[ $l + 1 ];
				my $h   = $g - $d->[ $l ];

				my $i = $l+1;
				while (++$i < $n) {
					$d->[ $i ] -= $h; 
				}

				$f += $h;
			
				# Implicit QL transformation	
				$p      = $d->[ $m ];
				my $c   = 1.0;
				my $c2  = $c;
				my $c3  = $c;
				my $el1 = $e->[ $l + 1 ];
				my $s   = 0.0;
				my $s2  = 0.0;

				$i = $m;
				while (--$i >= $l) {
					$c3 = $c2;
					$c2 = $c;
					$s2 = $s;
					$g  = $c * $e->[ $i ];
					$h  = $c * $p;
					$r  = Anorman::Math::Common::hypot( $p, $e->[ $i ] );
					$e->[ $i + 1 ] = $s * $r;
					$s  = $e->[ $i ] / $r;
					$c  = $p / $r;
					$p  = $c * $d->[ $i ] - $s * $g;
					$d->[ $i + 1 ] = $h + $s * ($c * $g + $s * $d->[ $i ]);

					my $k = -1;
					while (++$k < $n) {
						$h = $V->[ $k ][ $i + 1 ];
						$V->[ $k ][ $i + 1 ] = $s * $V->[ $k ][ $i ] + $c * $h;
						$V->[ $k ][ $i ]     = $c * $V->[ $k ][ $i ] - $s * $h;
					}
				}
				
				$p = -$s * $s2 * $c3 * $el1 * $e->[ $l ] / $dl1;
				$e->[ $l ] = $s * $p;
				$d->[ $l ] = $c * $p; 
			}
		}
		$d->[ $l ] += $f;
		$e->[ $l ]  = 0.0;
	}

	# Sort eigenvalues and corresponidng vectors
	$i = -1;
	while (++$i < $n - 1) {
		my $k = $i;
		my $p = $d->[ $i ];

		my $j = $i;
		while (++$j < $n) {
			if ($d->[ $j ] < $p) {
				$k = $j;
				$p = $d->[ $j ];
			}
		}

		if ($k != $i) {
			$d->[ $k ] = $d->[ $i ];
			$d->[ $i ] = $p;

			$j = -1;
			while (++$j < $n) {
				$p = $V->[ $j ][ $i ];
				$V->[ $j ][ $i ] = $V->[ $j ][ $k ];
				$V->[ $j ][ $k ] = $p;
			}
		}
	}
}

sub _tridiagonal {
	my $self = shift;
	my $d    = $self->{'_d'};
	my $V    = $self->{'_V'};
	my $n    = $self->{'_n'};
	my $e    = $self->{'_e'};

	my $j = -1;
	while (++$j < $n) {
		$d->[ $j ] = $V->[ $n - 1 ][ $j ];
	}

	my $i = $n;
	while (--$i > 0) {
		
		# Scale to avoid under/overflow
		my $scale = 0.0;
		my $h     = 0.0;

		my $k = -1;
		while (++$k < $i) {
			$scale += abs($d->[ $k ]);
		}

		if ($scale == 0.0) {
			$e->[ $i ] = $d->[ $i - 1 ];

			my $j = -1;
			while (++$j < $i) {
				$d->[ $j ]       = $V->[ $i - 1 ][ $j ];
				$V->[ $i ][ $j ] = 0.0;
				$V->[ $j ][ $i ] = 0.0;
			}
		} else {

			# Generate Householder vector
			$k = -1;
			while (++$k < $i) {
				$d->[ $k ] /= $scale;
				$h         += ($d->[ $k ] * $d->[ $k ]); 
			}
			
			my $f = $d->[ $i - 1 ];
			my $g = sqrt( $h );

			$g             = -$g if ($f > 0);
			$e->[ $i ]     = $scale * $g;
			$h            -= $f * $g;
			$d->[ $i - 1 ] = $f - $g;

			$j = -1;
			while (++$j < $i) {
				$e->[ $j ] = 0.0;
			}
			
			# Apply similarity transformation to remaining columns
			$j = -1;
			while (++$j < $i) {
				$f = $d->[ $j ];
				$V->[ $j ][ $i ] = $f;
				$g = $e->[ $j ] + $V->[ $j ][ $j ] * $f;

				$k = $j;
				while (++$k <= $i - 1) {
					$g += $V->[ $k ][ $j ] * $d->[ $k ];
					$e->[ $k ] += $V->[ $k ][ $j ] * $f;
				}
				$e->[ $j ] = $g;
			}

			$f = 0.0;

			$j = -1;
			while (++$j < $i) {
				$e->[ $j ] /= $h;
				$f         += $e->[ $j ] * $d->[ $j ];
			}

			my $hh = $f / ($h + $h);

			$j = - 1;
			while (++$j < $i) {
				$e->[ $j ] -= $hh * $d->[ $j ];
			}

			$j = -1;
			while (++$j < $i) {
				$f = $d->[ $j ];
				$g = $e->[ $j ];

				$k = $j - 1;
				while (++$k <= $i - 1) {
					$V->[ $k ][ $j ] -= ( $f * $e->[ $k ] + $g * $d->[ $k ] );
				}

				$d->[ $j ] = $V->[ $i - 1 ][ $j ];
				$V->[ $i ][ $j ] = 0.0;
			}
				
		}

		$d->[ $i ] = $h;
	}

	# Accumulate transformations.
	$i = -1;
	while (++$i < $n - 1) {
		$V->[ $n - 1 ][ $i ] = $V->[ $i ][ $i ];
		$V->[ $i ][ $i ] = 1.0;

		my $h = $d->[ $i + 1 ];

		if ($h != 0.0) {
			my $k = -1;
			while (++$k <= $i) {
				$d->[ $k ] = $V->[ $k ][ $i + 1 ] / $h;
			}

			my $j = -1;
			while (++$j <= $i) {
				my $g = 0.0;

				$k = -1;
				while (++$k <= $i) {
					$g += $V->[ $k ][ $i + 1 ] * $V->[ $k ][ $j ];
				}
				
				$k = - 1;
				while (++$k <= $i) {
					$V->[ $k ][ $j ] -= $g * $d->[ $k ];
				}
			}	
		}

		my $k = -1;
		while (++$k <= $i) {
			$V->[ $k ][ $i + 1 ] = 0.0;
		}
	}

	my $j = -1;
	while (++$j < $n) {
		$d->[ $j ] = $V->[ $n - 1 ][ $j ];
		$V->[ $n - 1 ][ $j ] = 0.0;
	}

	$V->[ $n - 1 ][ $n - 1 ] = 1.0;
	$e->[ 0 ] = 0.0;
}

1;
