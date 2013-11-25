package Anorman::Data::LinAlg::QRDecomposition;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data::LinAlg::Property qw( :matrix );
use Anorman::Math::Common qw(hypot);
use Anorman::Data;

use overload
	'""' => \&_stringify;

sub new {
	my $class = shift;
	
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
	my $Q    = $self->{'_QR'}->like;
	my $n    = $self->{'_n'};
	my $m    = $self->{'_m'};

	my $k = $n;
	while ( --$k >= 0 ) {
		my $QR_colk = $QR->view_column($k)->view_part($k, $m - $k);
		$Q->set_quick($k,$k,1);
		
		my $j = $k - 1;
		while ( ++$j < $n ) {
			unless ($QR->get_quick($k,$k) == 0) {
				my $Q_colj = $Q->view_column($j)->view_part($k, $m - $k);
				my $s = $QR_colk->dot_product($Q_colj);
				$s = -$s / $QR->get_quick($k,$k);
				$Q_colj->assign( $QR_colk, sub {  $_[0] + $_[1] * $s } ); 
			}
		}
	}
	return $Q;
}

sub R {
	my $self  = shift;
	my $QR    = $self->{'_QR'};
	my $n     = $self->{'_n'};
	my $R     = $self->{'_QR'}->like($n,$n);
	my $Rdiag = $self->{'_Rdiag'};

	my $i = -1;
	while ( ++$i < $n ) {
		my $j = -1;
		while ( ++$j < $n ) {
			if ($i < $j) {
				$R->set_quick($i,$j, $QR->get_quick($i,$j));
			} elsif ($i == $j) {
				$R->set_quick($i,$j, $Rdiag->get_quick($i));
			} else {
				$R->set_quick($i,$j,0);
			}
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

