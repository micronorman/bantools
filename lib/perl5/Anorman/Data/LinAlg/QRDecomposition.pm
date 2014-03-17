package Anorman::Data::LinAlg::QRDecomposition;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data::BLAS qw( :L2 );
use Anorman::Data::LinAlg::Property qw( :all );
use Anorman::Data::LinAlg::Householder qw( :all );
use Anorman::Math::Common qw(hypot min);
use Anorman::Data;

use overload
	'""' => \&_stringify;

sub new {
	my $class = ref $_[0] || $_[0];
	my $self  = bless( {}, $class );

	$self->decompose( $_[1] ) if @_ > 1;

	return $self;

=head	
	check_matrix($_[0]);
	check_rectangular($_[0]);

	my $QR = $_[0]->copy;
	my $m  = $_[0]->rows;
	my $n  = $_[0]->columns;

	my $Rdiag = $_[0]->like_vector($n);

	my @QR_columns      = map { $QR->view_column( $_ ) } ( 0 .. $n - 1);
	my @QR_columns_part = map { $QR->view_column( $_ )->view_part($_, $m - $_) } ( 0 .. $n - 1);

	my $k = -1;
	while ( ++$k < $n ) {

		my $nrm = 0.0;

		my $i = $k - 1;
		while ( ++$i < $m ) {
			$nrm = hypot($nrm, $QR->get_quick($i,$k));
		}

		unless ( $nrm == 0) {
			$nrm = -$nrm if $QR->get_quick($k,$k) < 0;
			$QR_columns_part[ $k ]->assign( sub { $_[0] / $nrm } );
			$QR->set_quick($k,$k, $QR->get_quick($k,$k) + 1);

			my $j = $k;
			while ( ++$j < $n ) {
				my $QR_colj = $QR->view_column($j)->view_part($k, $m - $k);
				my $s = $QR_columns_part[$k]->dot_product($QR_colj);
				$s = -$s / $QR->get_quick($k,$k);

				my $i = $k - 1;
				while ( ++$i < $m ) {
					$QR->set_quick($i,$j, $QR->get_quick($i,$j) + $s * $QR->get_quick($i,$k));
				}
			} 
		}

		$Rdiag->set_quick($k, -$nrm);
	}
	my $self = {
		'_QR'    => $QR,
		'_Rdiag' => $Rdiag,
		'_m'     => $m,
		'_n'     => $n
	};

	return bless ( $self, ref $class || $class );
=cut
}

sub decompose {
	my $self = shift;
	my $A    = shift;

	#warn "IN:\n$A\n";

	check_matrix($A);

	my $M = $A->rows;
	my $N = $A->columns;

	my $n = min($M,$N);
	my $tau = $A->like_vector($n);

	my $QR = $A->copy;

	my $i = -1;
	while ( ++$i < $n ) {

		# Compute the Householder transformation to reduce the j-th
		# column of the matrix to a multiple of the j-th unit vector

		my $c_full = $QR->view_column($i);
		my $c      = $c_full->view_part($i, $M - $i);

		my $tau_i = householder_transform( $c );

		$tau->set_quick( $i, $tau_i );

		if ( $i + 1 < $N ) {
			my $m = $QR->view_part($i, $i + 1, $M - $i, $N - ($i + 1));
			householder_hm( $tau_i, $c, $m );
		}
	}

	$self->{'_QR'}  = $QR;
	$self->{'_tau'} = $tau;

	my $Q = $self->Q;
	my $R = $self->R;

	#print "QR:\n$QR\nTAU:\n$tau\n\nQ:\n$Q\nR:\n$R\n";
}


sub H {
	my $self    = shift;
	my $H       = $self->{'_QR'}->copy;
	my $rows    = $H->rows;
	my $columns = $H->columns;

	my $r = $rows;
	while ( --$r >= 0 ) {
		my $c = $columns;
		while ( --$c >= 0 ) {
			$H->set_quick($r,$c,0) if ($r < $c);
		}
	}

	return $H;
}

sub Q {
	my $self = shift;
	my $QR   = $self->{'_QR'};
	my $tau  = $self->{'_tau'};

	my $M = $QR->rows;
	my $N = $QR->columns;

	my $Q = Anorman::Data->identity_matrix( $M );

	my ($i,$j);

	$i = min($M,$N);
	while ( --$i >= 0 ) {
		my $c  = $QR->view_column($i);
		my $h  = $c->view_part($i, $M - $i);
		my $m  = $Q->view_part($i, $i, $M - $i, $M - $i);
		my $ti = $tau->get_quick($i);

		householder_hm($ti, $h, $m);
	}	

	return $Q;
}

sub R {
	my $self  = shift;
	my $QR    = $self->{'_QR'};

	my $M = $QR->rows;
	my $N = $QR->columns;

	my $R = $self->{'_QR'}->like($M,$N);
	
	my ($i,$j);

	$i = -1;
	while ( ++$i < $M ) {
		$j = -1;
		while ( ++$j < $i && $j < $N ) {
			$R->set_quick($i,$j,0);
		}

		$j = $i - 1;
		while ( ++$j < $N ) {
			$R->set_quick($i,$j, $QR->get_quick($i,$j))
		}
	}

	return $R;
}

sub has_full_rank {
	my $self  = shift;
	my $Rdiag = $self->{'_Rdiag'};
	my $n     = $self->{'_n'};
	
	my $j = -1;
	while ( ++$j < $n ) {
		return undef if $Rdiag->get_quick($j) == 0;
	}
	return 1;
}

sub solve {
	my $self = shift;
	my $b    = shift;

	check_vector($b);

	my $QR  = $self->{'_QR'};

	trace_error("Matrix size must match b size") if ($QR->rows != $b->size);

	my $x = $b->copy;

	$self->svx($x);

	return $x;	
}

sub svx {
	my $self = shift;
	my $x    = shift;

	check_vector($x);

	my $QR = $self->{'_QR'};

	trace_error("Matrix size must match x/rhs size") if ($QR->rows != $x->size);

	# Compute rhs = Q^T b
	$self->QT_vec($x);

	# Solve R x = rhs, storing x in-place
	blas_trsv( BlasUpper, BlasNoTrans, BlasNonUnit, $QR, $x);
		
}

sub QT_vec {
	my $self = shift;
	my $v    = shift;

	my $QR  = $self->{'_QR'};
	my $M   = $QR->rows;

	trace_error("Vector size must be M") if $v->size != $M;

	my $tau = $self->{'_tau'};

	my $i = -1;
	while ( ++$i < $tau->size ) {
		my $c = $QR->view_column($i);
		my $h = $c->view_part($i, $M - $i);
		my $w = $v->view_part($i, $M - $i);

		my $ti = $tau->get_quick($i);

		householder_hv( $ti, $h, $w );
	}
}

=head
sub solve {
	my $self = shift;
	
	check_matrix($_[0]);
	trace_error("Matrix row dimensions must agree.") unless $_[0]->rows == $self->{'_m'};
	trace_error("Matrix is rank deficient.") unless $self->has_full_rank;

	my $QR    = $self->{'_QR'};
	my $n     = $self->{'_n'};
	my $m     = $self->{'_m'};
	my $Rdiag = $self->{'_Rdiag'};

	my $nx = $_[0]->columns;
	my $X  = $_[0]->copy;


	my $k = -1;
	while ( ++$k < $n ) {
		my $j = -1;
		while ( ++$j < $nx ) {
			my $s = 0.0;

			my $i = $k - 1;
			while ( ++$i < $m ) {
				$s += $QR->get_quick($i,$k) * $X->get_quick($i,$j);
			}

			$s = -$s / $QR->get_quick($k,$k);

			$i = $k - 1;
			while ( ++$i < $m ) {
				$X->set_quick($i,$j, $X->get_quick($i,$j) + $s * $QR->get_quick($i,$k));
			}
		}
	}

	$k = $n;
	while ( --$k >= 0 ) {
		my $j = -1;
		while ( ++$j < $nx ) {
			$X->set_quick($k,$j, $X->get_quick($k,$j) / $Rdiag->get_quick($k));
		}
		
		my $i = -1;
		while ( ++$i < $k ) {
			my $j = -1;
			while ( ++$j < $nx ) {
				$X->set_quick($i,$j, $X->get_quick($i,$j) - $X->get_quick($k,$j) * $QR->get_quick($i,$k));
			}
		}
	}		
	
	return $X->view_part(0,0,$n,$nx);
}
=cut

sub _stringify {
	my $self   = shift;
	my $string = '';

	$string .= "----------------\n";
	$string .= "QR Decomposition\n";
	$string .= "----------------\n";
	$string .= "has full rank = " . ($self->has_full_rank ? 'YES' : 'NO');
	$string .= "\n\nH:\n"   . $self->H;
	$string .= "\n\nQ:\n"   . $self->Q;
	$string .= "\n\nR:\n"   . $self->R;
	$string .= "\n\nPseudo-inverse(A):\n" . $self->solve( Anorman::Data->identity_matrix( $self->{'_QR'} ) );
	
	return $string;
}

1;

