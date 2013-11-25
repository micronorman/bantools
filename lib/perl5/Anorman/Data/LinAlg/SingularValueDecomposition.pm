package Anorman::Data::LinAlg::SingularValueDecomposition;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data::LinAlg::Property qw( :matrix );
use Anorman::Math::Common qw(hypot);

use List::Util qw(min max);
use Anorman::Data;

use overload
	'""' => \&_stringify;

sub new {
	my $class = shift;

	check_matrix($_[0]);
	check_rectangular($_[0]);

	# convert matrix to 2D array
	my $A = \@{ $_[0] };	

	my $m = $_[0]->rows;
	my $n = $_[0]->columns;

	my $nu = min($m,$n);

	my @s = ();
	my $U = Anorman::Data->matrix($m,$nu)->assign(0)->_to_array;
	my $V = Anorman::Data->matrix($n,$n )->assign(0)->_to_array;

	my @e    = ();
	my @work = ();

	my $wantu = 1;
	my $wantv = 1;

	my $nct = min($m-1,$n);
	my $nrt = max(0,min($n-2,$m));

	my $k = -1;
	while ( ++$k < max($nct,$nrt)) {
		if ($k < $nct) {
			# Compute the transformation for the k-th column and
			# place the k-th diagonal in s[k].
			# compute 2-norm of the k-th column without under/overflow.
			$s[$k] = 0;

			my $i = $k - 1;
			while ( ++$i < $m ) {
				$s[$k] = hypot($s[$k], $A->[$i][$k]);
			}

			if ($s[$k] != 0.0) {
				$s[$k] = -$s[$k] if ($A->[$k][$k] < 0.0);

				my $i = $k -1;
				while ( ++$i < $m) {
					$A->[$i][$k] /= $s[$k];
				}

				$A->[$k][$k]++;
			}

			$s[$k] = -$s[$k];
		}

		my $j = $k;
		while ( ++$j < $n) {
			if (($k < $nct) && ($s[$k] != 0.0)) {

				# Apply the transformation
				my $t = 0;

				my $i = $k - 1;
				while ( ++$i < $m ) {
					$t += $A->[$i][$k] * $A->[$i][$j];
				}

				$t = -$t/ $A->[$k][$k];

				$i = $k - 1;
				while ( ++$i < $m ) {
					$A->[$i][$j] += $t * $A->[$i][$k];
				}
			}

			# Place the k-th row of A into e for the
			# subsequent calculation of row transformation.
			$e[$j] = $A->[$k][$j];
		}

		if ($wantu && ($k < $nct)) {
			#Place the transformation in U for subsequent back
			# multiplication

			my $i = $k - 1;
			while ( ++$i < $m ) {
				$U->[$i][$k] = $A->[$i][$k];
			}
		}

		if ($k < $nrt) {
		
			# Compute the k-th row transformation and place the 
			# k-th superdiagonal in e[k].
			# Copmute 2-norm without under/overflow.
			$e[$k] = 0;

			my $i = $k;
			while ( ++$i < $n ) {
				$e[$k] = hypot($e[$k],$e[$i]);
			}

			if ($e[$k] != 0.0) {
				if ($e[$k + 1] < 0.0) {
					$e[$k] = -$e[$k];
				}

				my $i = $k;
				while ( ++$i < $n ) {
					$e[$i] /= $e[$k];
				}

				$e[ $k + 1 ]++;
			}

			$e[$k] = -$e[$k];

			if (($k+1 < $m) && ($e[$k] != 0.0)) {

				# Apply the transformation
				my $i = $k;
				while ( ++$i < $m ) {
					$work[ $i ] = 0.0;
				}

				my $j = $k;
				while ( ++$j < $n ) {

					my $i = $k;
					while ( ++$i < $m ) {
						$work[ $i ] += $e[$j] * $A->[$i][$j];
					}		
				}

				$j = $k;
				while ( ++$j < $n ) {

					my $t = -$e[$j]/$e[$k+1];
					my $i = $k;
					while ( ++$i < $m ) {
						$A->[$i][$j] += $t * $work[$i];
					}		
				}
			
			}

			if ($wantv) {
			
				# Place the transformation in V for subsequent
				# back multiplication

				my $i = $k;
				while ( ++$i < $n ) {
					$V->[$i][$k] = $e[$i];
				}
			}
		}
	}

	# Set up the final bidiagonal matrix or order p
	my $p = min($n,$m+1);

	$s[$nct]    = $A->[$nct][$nct] if ($nct   < $n);
	$s[ $p - 1] = 0.0              if ($m     < $p);
	$e[$nrt]    = $A->[$nrt][$p-1] if ($nrt+1 < $p);
	$e[$p-1]    = 0.0;

	# If required, generate U
	if ($wantu) {

		my $j = $nct - 1;
		while ( ++$j < $nu ) {
		
			my $i = -1;
			while ( ++$i < $m ) {
				$U->[$i][$j] = 0.0;
			}

			$U->[$j][$j] = 1.0;
		}


		my $k = $nct;
		while ( --$k >= 0 ) {
			if ($s[$k] != 0.0) {

				my $j = $k;
				while ( ++$j < $nu ) {
					my $t = 0;

					my $i = $k - 1;
					while ( ++$i < $m ) {
						$t += $U->[$i][$k] * $U->[$i][$j];
					}

					$t = -$t / $U->[$k][$k];

					$i = $k - 1;
					while ( ++$i < $m ) {
						$U->[$i][$j] += $t * $U->[$i][$k];
					}
				}

				my $i = $k -1;
				while ( ++$i < $m ) {
					$U->[$i][$k] = -$U->[$i][$k];
				}

				$U->[$k][$k]++;

				$i = -1;
				while ( ++$i < $k - 1) {
					$U->[$i][$k] = 0.0;
				}
			} else {
				my $i = -1;
				while ( ++$i < $m ) {
					$U->[$i][$k] = 0.0;
				}

				$U->[$k][$k] = 1;
			}
		}
	}

	# If required, generate V.
	if ($wantv) {
		
		my $k = $n;
		while ( --$k >= 0 ) {
			if (($k < $nrt) && ($e[$k] != 0.0)) {
				my $j = $k;	
				while ( ++$j < $n ) {
					my $t = 0;

					my $i = $k;
					while ( ++$i < $n ) {
						$t += $V->[$i][$k] * $V->[$i][$j];
					}

					$t = -$t / $V->[$k+1][$k];
					
					$i = $k;
					while ( ++$i < $n ) {
						$V->[$i][$j] += $t * $V->[$i][$k];
					}
				}
			}

			my $i = -1;
			while ( ++$i < $n ) {
				$V->[$i][$k] = 0.0;
			}

			$V->[$k][$k] = 1.0;
		}
	}

	# Main iteration loop for the singular values.
	my $pp  = $p - 1;
	my $eps = 2**-52;

	# Iteration cases, dispatch table
	
	### LOOP ###

	while ( $p > 0 ) {
		my $case = '';
		my $k = $p - 1;
		while ( --$k >= -1 ) {
			last if $k == -1;
			if (abs($e[$k]) <= $eps * (abs($s[$k] + abs($s[$k+1])))) {
				$e[$k] = 0.0;
				last;
			}
		}

		if ($k == $p-2) {
			$case = 'case_4';
		} else {
			my $ks = $p-2;
			while ( --$ks >= $k ) {
				last if ($ks == $k);

				my $t = ($ks != $p ? abs($e[$ks]) : 0.0) + ($ks != $k + 1 ? abs($e[$ks - 1]) : 0.0);

				if (abs($s[$ks]) <= $eps * $t) {
					$s[$ks] = 0.0;
					last;
				}
			}
		
			if ($ks == $k) {
				$case = 'case_3';
			} elsif ($ks == $p-1) {
				$case = 'case_1';
			} else {
				$case = 'case_2';
				$k = $ks;
			}
		}

		$k++;

		my %cases = (

		# Case 1; if s(p) and e[k-1] are negligible and k<p
		'case_1' => sub {
			my $f = $e[$p-2];

			$e[$p-2] = 0.0;

			my $j = $p - 1;
			while ( --$j >= $k ) {
				my $t  = hypot($s[$j],$f);
				my $cs = $s[$j] / $t;
				my $sn = $f / $t;
				
				$s[$j] = $t;

				if ( $j != $k ) {
					$f       = -$sn * $e[$j-1];
					$e[$j-1] =  $cs * $e[$j-1];
				}

				if ($wantv) {
					my $i = -1;
					while ( ++$i < $n ) {
						my $t = $cs * $V->[$i][$j] + $sn * $V->[$i][$p-1];

						$V->[$i][$p-1] = -$sn * $V->[$i][$j] + $cs * $V->[$i][$p-1];
						$V->[$i][$j]   =  $t; 
					}
				}
			}
		},

		# Case 2: if s(k) is negligible and k<p
		'case_2' => sub {
			my $f = $e[$k-1];
			$e[$k-1] = 0.0;

			my $j = $k - 1;
			while ( ++$j < $p ) {
				my  $t = hypot($s[$j],$f);
				my $cs = $s[$j] / $t;
				my $sn = $f / $t;

				$s[$j] = $t;
				$f     = -$sn * $e[$j];

				if ($wantu) {

					my $i = - 1;
					while ( ++$i < $m ) {
						my $t = $cs * $U->[$i][$j] + $sn * $U->[$i][$k-1];

						$U->[$i][$k-1] = -$sn * $U->[$i][$j] + $cs * $U->[$i][$k-1];
						$U->[$i][$j]   = $t;
					}
				}	
			}
		},

		# Case 3: if e[k-1] is negligible, k<p, and
		#         s(k0, ..., s(p) are not negligible (qr step)
		'case_3' => sub {

			# Calculate the shift
			my $scale = max( max( max( max( abs($s[$p-1]), abs($s[$p-2])),abs($e[$p-2])), abs($s[$k])), abs($e[$k]));
			
			my $sp    = $s[$p-1]/$scale;
			my $spm1  = $s[$p-2]/$scale;
			my $epm1  = $e[$p-2]/$scale;
			my $sk    = $s[$k]/$scale;
			my $ek    = $e[$k]/$scale;
			my $b     = (($spm1 + $sp) * ($spm1 - $sp) + $epm1 * $epm1) / 2.0;
			my $c     = ($sp * $epm1) * ($sp * $epm1);
			my $shift = 0.0;

			if (($b != 0.0) || ($c != 0.0)) {
				$shift = sqrt($b * $b + $c);

				if ($b < 0.0) {
					$shift = -$shift;
				}

				$shift = $c / ($b + $shift);
			}

			my $f = ($sk + $sp) * ($sk - $sp) + $shift;
			my $g = $sk * $ek;

			# Chase zeros.
			my $j = $k - 1;
			while ( ++$j < $p-1 ) {

				my $t  = hypot( $f,$g);
				my $cs = $f / $t;
				my $sn = $g / $t;

				if ($j != $k) {
					$e[$j-1] = $t;
				}

				$f       = $cs * $s[$j] + $sn * $e[$j];
				$e[$j]   = $cs * $e[$j] - $sn * $s[$j];
				$g       = $sn * $s[$j+1];
				$s[$j+1] = $cs * $s[$j+1];

				if ($wantv) {
					my $i = -1;
					while ( ++$i < $n ) {

						my $t = $cs * $V->[$i][$j] + $sn * $V->[$i][$j+1];

						$V->[$i][$j+1] = -$sn * $V->[$i][$j] + $cs * $V->[$i][$j+1];
						$V->[$i][$j]   = $t
					}
				}

				$t       =  hypot($f,$g);
				$cs      =  $f / $t;
				$sn      =  $g / $t;
				$s[$j]   =  $t;
				$f       =  $cs * $e[$j] + $sn * $s[$j+1];
				$s[$j+1] = -$sn * $e[$j] + $cs * $s[$j+1];
				$g       =  $sn * $e[$j+1];
				$e[$j+1] =  $cs * $e[$j+1];

				if ($wantu && ($j < $m - 1)) {
				
					my $i = -1;
					while ( ++$i < $m ) {
						my $t = $cs * $U->[$i][$j] + $sn * $U->[$i][$j+1];
		
						$U->[$i][$j+1] = -$sn * $U->[$i][$j] + $cs * $U->[$i][$j+1];
						$U->[$i][$j]   = $t;
					}
				}
			}
			
			$e[$p-2] = $f;
		},

		# Case 4: if e(p-1) if negligible (convergence)
		'case_4' => sub {

			# Make the singular values positive
			if ($s[$k] <= 0.0) {
				$s[$k] = ($s[$k] < 0.0 ? -$s[$k] : 0.0);

				if ($wantv) {
			
					my $i = -1;
					while ( ++$i <= $pp ) {
						$V->[$i][$k] = -$V->[$i][$k];
					}
				}
			}

			# Order the singular values
			while ( $k < $pp ) {
				last if ($s[$k] >= $s[$k+1]);

				($s[$k],$s[$k+1]) = ($s[$k+1],$s[$k]);

				if ($wantv && ($k < $n-1)) {
					
					my $i = -1;
					while ( ++$i < $n ) {
						($V->[$i][$k+1], $V->[$i][$k]) = ($V->[$i][$k], $V->[$i][$k+1]);
					}
				}

				if ($wantu && ($k < $m-1)) {
					
					my $i = -1;
					while ( ++$i < $m ) {
						($U->[$i][$k+1], $U->[$i][$k]) = ($U->[$i][$k], $U->[$i][$k+1]);
					}
				}
				$k++;

			}

			$p--;
		}

		);

		# execute case from dispatch table
		$cases{ $case }->();
	}

	my $self = {
		'_U' => $U,
		'_V' => $V,
		'_s' => \@s,
		'_m' => $m,
		'_n' => $n
	};

	return bless ( $self, ref $class || $class );

}

sub cond {
	my $self = shift;
	my $s    = $self->{'_s'};
	my $m    = $self->{'_m'};
	my $n    = $self->{'_n'};

	return $s->[0] / $s->[ min($m, $n) - 1];
}

sub S {
	my $self = shift;
	my $S    = [[]];

	my $i = -1;
	while ( ++$i < $self->{'_n'} ) {
		my $j = -1;
		while ( ++$j < $self->{'_n'} ) {
			$S->[$i][$j] = 0.0;
		}
		$S->[$i][$i] = $self->{'_s'}->[$i];
	}

	return Anorman::Data->matrix($S);
}

sub singular_values {
	my $self = shift;
	
	return wantarray ? @{ $self->{'_s'} } : $self->{'_s'};
}

sub U {
	my $self = shift;

	return Anorman::Data->matrix( $self->{'_U'} )->view_part(0,0,$self->{'_m'}, min( $self->{'_m'} + 1, $self->{'_n'}) );
}

sub V {
	my $self = shift;

	return Anorman::Data->matrix($self->{'_V'});
}

sub norm2 {
	my $self = shift;

	return $self->{'_s'}->[0];
}

sub rank {
	my $self = shift;
	my ($m,$n,$s) = @{ $self }{ qw/_m _n _s/ };
	my $eps = 2**-52;
	my $tol = max($m,$n) * $s->[0] * $eps;

	my $r = 0;
	my $i = -1;
	while ( ++$i < scalar @{ $s }) {
		$r++ if $s->[$i] > $tol;
	}

	return $r;
}

sub _stringify {
	my $self   = shift;
	my $string = '';

	$string .= "----------------------------\n";
	$string .= "Singular Value Decomposition\n";
	$string .= "----------------------------\n";
	$string .= "cond = "    . $self->cond;
	$string .= "\nrank = "  . $self->rank;
	$string .= "\nnorm2 = " . $self->norm2;
	$string .= "\n\nU:\n"   . $self->U;
	$string .= "\n\nS:\n"   . $self->S;
	$string .= "\n\nV:\n"   . $self->V;

	return $string;
}

1;
