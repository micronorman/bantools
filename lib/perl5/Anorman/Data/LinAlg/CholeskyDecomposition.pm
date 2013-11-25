package Anorman::Data::LinAlg::CholeskyDecomposition;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data;

use Anorman::Data::LinAlg::Property qw( :matrix );
use List::Util qw(max);


use overload 
	'""' => \&_stringify;

sub new {
	my $class  = shift;
	my $A      = shift;

	check_matrix($A);
	check_square($A);

	my $n = $A->rows;
	my $L = $A->like($n,$n);
	my $symposdef = ($A->columns == $n);

	my @Lrows = map { $L->view_row($_) } (0 .. $n - 1);

	my $j = -1;
	while ( ++$j < $n ) {
		my $d = 0.0;

		my $k = -1;
		while ( ++$k < $j ) {
			my $s = $Lrows[$k]->dot_product( $Lrows[ $j ],0,$k );
			my $t = $L->get_quick($k,$k);

			unless ( $t == 0 ) {
				$s = ($A->get_quick($j,$k) - $s) / $t;
				$Lrows[$j]->set_quick($k,$s);
				$d += $s * $s;
			}

			# check for symmetry
			$symposdef = $symposdef && ($A->get_quick($k,$j) == $A->get_quick($j,$k));
		}

		$d = $A->get_quick($j,$j) - $d;
		$symposdef = $symposdef && ($d > 0.0);
		$L->set_quick($j,$j, sqrt( max($d,0.0) ) ); 
		
		$k = $j;
		while ( ++$k < $n ) {
			$L->set_quick( $j, $k, 0.0);
		}
	}

	my $self = { '_L' => $L,
		     '_n' => $n,
		     '_is_symmetric_positive_definite' => $symposdef
	};

	return bless ( $self, ref $class || $class );
}

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
	$string .= "\n\ninverse(A):\n" . $self->solve(Anorman::Data->identity_matrix( $self->{'_L'}->rows )) if $self->is_symmetric_positive_definite;

	return $string;
}

1;
