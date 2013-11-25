package Anorman::Data::LinAlg::LUDecomposition;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data::LinAlg::Property qw( :matrix );
use Anorman::Data::LinAlg::Algebra qw( permute_rows );
use List::Util qw(min);

use overload
	'""' => \&_to_string;

sub new {
	my $class = shift;
	my $A     = shift;

	check_matrix( $A );

	my $self = { 'LU'              => undef,
	             'piv'             => [],
		     'pivsign'         => undef,
		     'is_non_singular' => undef,
	};

	bless ( $self, ref $class || $class );

	$self->decompose( $A->copy );

	return $self;
}

sub decompose {
	my ($self, $A) = @_;

	check_matrix( $A );

	my ($LU, $m, $n) = ($A, $A->rows, $A->columns);
	my $pivot = $self->{'piv'};
	
	if (!defined $pivot || @{ $pivot } != $m) {
		@{ $pivot } = (0 .. $m - 1);
	}

	$self->{'pivsign'} = 1;

	# cached row views
	my @LU_rows = map { $LU->view_row($_) } (0 .. $m - 1); 
	my $LU_colj = $LU->view_column(0)->like();

	# gaussiean elimination with partial pivoting
	my $j = -1;
	while ( ++$j < $n ) {
		$LU_colj->assign( $LU->view_column( $j ) );

		# Apply previous transformation
		my $i = -1;
		while (++$i < $m) {
			my $kmax   = min( $i, $j);
			my $s      = $LU_rows[ $i ]->dot_product($LU_colj ,0, $kmax);
			my $before = $LU_colj->get_quick( $i );
			my $after  = $before -$s;
			
			$LU_colj->set_quick( $i, $after);
			$LU->set_quick( $i, $j, $after);
		}	

		# Find pivot and exchange if necessary
		my $p = $j;
		if ($p < $m) {
			my $max = abs( $LU_colj->get_quick( $p ) );
			$i = $j;
			while ( ++$i < $m ) {
				my $v = abs($LU_colj->get_quick( $i ));
				if ($v > $max) {
					$p = $i;
					$max = $v;
				}
			}
		}
		
		# swap
		if ($p != $j) {
			$LU_rows[ $p ]->swap( $LU_rows[ $j ] );
			($pivot->[ $p ], $pivot->[ $j ]) = ($pivot->[ $j ], $pivot->[ $p ]);
			$self->{'pivsign'} = -$self->{'pivsign'};
		}

		my $jj = $LU->get_quick($j,$j);

		if ($j < $m && $jj != 0) {
			$LU->view_column($j)->view_part($j+1, $m-($j+1) )->assign( sub { $_[0] / $jj } );
		}
	}

	$self->set_LU($LU);
}

sub set_LU {
	my ($self, $LU) = @_;
	$self->{'LU'} = $LU;
	$self->{'is_non_singular'} = $self->is_non_singular($LU);
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
	my ($m, $n) = ($self->_m, $self->_n);

	trace_error("Illegal Argument: Matrix must be square") if ($m != $n);

	my $det = $self->{'pivsign'};
	
	my $j = -1;
	while ( ++$j < $n ) {
		$det *= $self->{'LU'}->get_quick($j,$j);
	}

	return $det;
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

	#$A->view_part(0,$min,$rows,$cols->$min)->assign(0) if ($cols > $rows);
	
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

	#$A->view_part(0,$min,$rows,$cols->$min)->assign(0) if ($cols > $rows);
	
	return $A;

}

sub is_non_singular {
	my ($self, $matrix) = @_;
	return $self->{'is_non_singular'} if !defined $matrix;

	my $m = $matrix->rows;
	my $n = $matrix->columns;

	my $j = min($m,$n);
	while ( --$j >= 0) {
		return undef if $matrix->get_quick($j,$j) == 0;
	}

	return 1;
}

sub pivot {
	my $self = shift;
	return $self->{'piv'};
}

sub _m {
	my $self = shift;
	return $self->{'LU'}->rows;
}

sub _n {
	my $self = shift;
	return $self->{'LU'}->columns;
}

sub solve {
	my ($self,$B) = @_;
	
	check_matrix($B);

	my $LU = $self->{'LU'};

	check_rectangular($LU);

	my $m = $self->_m;
	my $n = $self->_n;

	trace_error("Matrix row dimensions must agree") if ($B->rows != $m);
	trace_error("Matrix is singular") if !$self->is_non_singular;

	# permute matrix according to pivot vector
	Anorman::Data::LinAlg::Algebra::permute_rows($B, $self->{'piv'});

	my $nx = $B->columns;
	my @B_rows = map { $B->view_row( $_ ) } (0 .. $n - 1);

	my $B_rowk = is_packed($B) ? Anorman::Data->packed_vector($nx) : Anorman::Data->vector($nx);

	# solve L * Y = B(piv,:)
	my $k = -1;
	while (++$k < $n ) {
		$B_rowk->assign($B_rows[ $k ]);

		my $i = $k;
		while ( ++$i < $n ) {
			my $mult = -$LU->get_quick($i,$k);
			if ($mult != 0) {
				$B_rows[ $i ]->assign( $B_rowk, sub{ $_[0] + $_[1] * $mult } );
			}
		}
	}

	# Solve U*B = Y
	$k = $n;
	while ( --$k >= 0 ) {
		my $div = $LU->get_quick($k,$k);
		$B_rows[ $k ]->assign( sub{ $_[0] / $div } );

		$B_rowk->assign($B_rows[$k]);

		my $i = -1;
		while ( ++$i < $k) {
			my $mult = -$LU->get_quick($i,$k);
			if ($mult != 0) {
				$B_rows[$i]->assign( $B_rowk, sub{ $_[0] + $_[1] * $mult } );
			}
		}
	}

	return $B;
}

sub _to_string {
	my $self = shift;
	
	my $string = '';

	$string .= "------------------------------\n";
	$string .= "LU-Decomposition of Matrix (A)\n";
	$string .= "------------------------------\n";
	$string .= "A is non-singular: " . $self->is_non_singular . "\n";
	$string .= "\ndet(A): " . $self->det . "\n";
	$string .= "\npivot: " . join ("," , @{ $self->{'piv'} }) . "\n";
	$string .= "\n\nL:\n" . $self->L;
	$string .= "\n\nU:\n" . $self->U;
	$string .= "\n\ninverse(A):\n" . $self->solve( Anorman::Data->identity_matrix( $self->{'LU'} ) );
}

1;
