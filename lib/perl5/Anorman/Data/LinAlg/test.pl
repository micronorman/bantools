#!/usr/bin/env perl

use strict;
use warnings;

$Anorman::Common::VERBOSE = 1 if (@ARGV && $ARGV[0] eq '-v');
$Anorman::Data::Config::PACK_DATA = 1;

use Anorman::Common;

use Anorman::Data;
use Anorman::Data::LinAlg::BLAS qw( :L3 );
use Anorman::Data::LinAlg::QRDecomposition; 
use Anorman::Data::LinAlg::CholeskyDecomposition;
use Anorman::Data::LinAlg::LUDecomposition;

use Data::Dumper;

my $EPSILON = 2.2204460492503131e-16;

my $tests  = 0;
my $passed = 0;
my $failed = 0;

my $m11 = Anorman::Data->general_matrix(1,1);
my $m51 = Anorman::Data->general_matrix(5,1);

my $m35 = Anorman::Data->general_matrix(3,5);
my $m53 = Anorman::Data->general_matrix(5,3);
my $m97 = Anorman::Data->general_matrix(9,7);

my $hilb2 = Anorman::Data->hilbert_matrix(2);
my $hilb3 = Anorman::Data->hilbert_matrix(3);
my $hilb4 = Anorman::Data->hilbert_matrix(4);
my $hilb12 = Anorman::Data->hilbert_matrix(12);

my $vander2 = Anorman::Data->vandermonde_matrix(2);
my $vander3 = Anorman::Data->vandermonde_matrix(3);
my $vander4 = Anorman::Data->vandermonde_matrix(4);
my $vander12 = Anorman::Data->vandermonde_matrix(12);

my $hilb2_solution  = [-8.0, 18.0];
my $hilb3_solution  = [27.0, -192.0, 210.0];
my $hilb4_solution  = [-64.0, 900.0, -2520.0, 1820.0];
my $hilb12_solution = [-1728.0, 245388.0, -8528520.0,
                       127026900.0, -1009008000.0, 4768571808.0,
                       -14202796608.0, 27336497760.0, -33921201600.0,
                       26189163000.0, -11437874448.0, 2157916488.0 ];

my $vander2_solution  = [1.0, 0.0];
my $vander3_solution  = [0.0, 1.0, 0.0];
my $vander4_solution  = [0.0, 0.0, 1.0, 0.0];
my $vander12_solution = [0.0, 0.0, 0.0, 0.0,
                         0.0, 0.0, 0.0, 0.0,
                         0.0, 0.0, 1.0, 0.0];

&test(&test_LU_solve(),        "LU Decomposition and solver");
&test(&test_QR_decomp(),       "QR Decomposition");
&test(&test_QR_solve(),        "QR Solve");
&test(&test_cholesky_decomp(), "Cholesky Decomposition");
&test(&test_cholesky_solve(),  "Choleksy Solver");
&test(&test_cholesky_invert(), "Cholesky Inverse");
&summary();

sub test_LU_solve {
	my $f;
	my $s = 0;
	
	$f = &test_LU_solve_dim($hilb2, $hilb2_solution, $EPSILON);
	&test($f,"  LU_solve hilbert(2)");
	$s += $f;

	$f = &test_LU_solve_dim($hilb3, $hilb3_solution, 32 * $EPSILON);
	&test($f,"  LU_solve hilbert(3)");
	$s += $f;

	$f = &test_LU_solve_dim($hilb4, $hilb4_solution, 2048.0 * $EPSILON);
	&test($f,"  LU_solve hilbert(4)");
	$s += $f;

	$f = &test_LU_solve_dim($hilb12, $hilb12_solution, 0.5);
	&test($f,"  LU_solve hilbert(12)");
	$s += $f;

	$f = &test_LU_solve_dim($vander2, $vander2_solution, 8.0 * $EPSILON);
	&test($f,"  LU_solve vander(2)");
	$s += $f;

	$f = &test_LU_solve_dim($vander3, $vander3_solution, 64.0 * $EPSILON);
	&test($f,"  LU_solve vander(3)");
	$s += $f;

	$f = &test_LU_solve_dim($vander4, $vander4_solution, 1024.0 * $EPSILON);
	&test($f,"  LU_solve vander(4)");
	$s += $f;

	$f = &test_LU_solve_dim($vander12, $vander12_solution, 0.05);
	&test($f,"  LU_solve vander(12)");
	$s += $f;

	return $s;
}

sub test_LU_solve_dim {
	my ($m, $actual, $eps) = @_;

	my $s = 0;
	my $signum;
	my $dim = $m->rows;
	my $i;

	my $lu  = Anorman::Data::LinAlg::LUDecomposition->new( $m );
	my $rhs = $m->like_vector($dim);
	do { $rhs->set($_, $_ + 1.0 ) } for (0 .. $dim - 1);

	my $x = $lu->solve( $rhs );

	$i = -1;
	while ( ++$i < $dim ) {
		my $foo = &check( $x->get($i), $actual->[$i], $eps) ? 1 : 0;
		if($foo) {
			printf("%3lu[%lu]: %22.18g  %22.18g\n", $dim, $i, $x->get($i), $actual->[$i]);
		}
		$s += $foo;
	}

	#FIXME: Gives weird results
	#$lu->refine($m, $rhs, $x);

	#$i = -1;
	#while ( ++$i < $dim ) {
	#	my $foo = &check( $x->get($i), $actual->[$i], $eps) ? 1 : 0;
	#	if($foo) {
	#		printf("%3lu[%lu]: %22.18g  %22.18g (improved)\n", $dim, $i, $x->get($i), $actual->[$i]);
	#	}
	#	$s += $foo;
	#}

	return $s;	
}


sub test_QR_decomp {
	my $f;
	my $s = 0;
	
	$f = &test_QR_decomp_dim($m35, 2 * 8.0 * $EPSILON);
	&test($f,"  QR_decomp m(3,5)");
	$s += $f;

	$f = &test_QR_decomp_dim($m53, 2 * 64.0 * $EPSILON);
	&test($f,"  QR_decomp m(5,3)");
	$s += $f;

	$f = &test_QR_decomp_dim($hilb2, 2 * 8.0 * $EPSILON);
	&test($f,"  QR_decomp hilbert(2)");
	$s += $f;

	$f = &test_QR_decomp_dim($hilb3, 2 * 64.0 * $EPSILON);
	&test($f,"  QR_decomp hilbert(3)");
	$s += $f;

	$f = &test_QR_decomp_dim($hilb4, 2 * 1024.0 * $EPSILON);
	&test($f,"  QR_decomp hilbert(4)");
	$s += $f;

	$f = &test_QR_decomp_dim($hilb12, 2 * 1024.0 * $EPSILON);
	&test($f,"  QR_decomp hilbert(12)");
	$s += $f;

	$f = &test_QR_decomp_dim($vander2, 8.0 * $EPSILON);
	&test($f,"  QR_decomp vander(2)");
	$s += $f;

	$f = &test_QR_decomp_dim($vander3, 64.0 * $EPSILON);
	&test($f,"  QR_decomp vander(3)");
	$s += $f;

	$f = &test_QR_decomp_dim($vander4, 1024.0 * $EPSILON);
	&test($f,"  QR_decomp vander(4)");
	$s += $f;

	$f = &test_QR_decomp_dim($vander12, 1024.0 * $EPSILON);
	&test($f,"  QR_decomp vander(12)");
	$s += $f;

	return $s;
}

sub test_QR_decomp_dim {
	my ($m, $eps) = @_;
	my $s = 0;

	my ($i,$j);
	my $M = $m->rows;
	my $N = $m->columns;

	my $a = $m->like;
	
	my $qr = Anorman::Data::LinAlg::QRDecomposition->new( $m );

	blas_gemm(BlasNoTrans, BlasNoTrans, 1.0, $qr->Q, $qr->R, 0.0, $a);

	for($i=0; $i<$M; $i++) {
		for ($j=0; $j<$N; $j++) {
			my $aij = $a->get_quick($i,$j);
			my $mij = $a->get_quick($i,$j);
			my $foo = &check($aij, $mij, $eps) ? 1 : 0;

			if ($foo) {
				printf("(%3lu,%3lu)[%lu,%lu]: %22.18g  %22.18g\n", $M, $N, $i, $j, $aij, $mij);
			}
			$s += $foo;
		}
	}

	return $s;
}

sub test_QR_solve {
	my $f;
	my $s = 0;

	$f = &test_QR_solve_dim($hilb2, $hilb2_solution, 2 * 8.0 * $EPSILON );
	&test($f, "  QR_solve hilbert(2)");
	$s += $f;

	$f = &test_QR_solve_dim($hilb3, $hilb3_solution, 2 * 64.0 * $EPSILON );
	&test($f, "  QR_solve hilbert(3)");
	$s += $f;

	$f = &test_QR_solve_dim($hilb4, $hilb4_solution, 2 * 1024.0 * $EPSILON );
	&test($f, "  QR_solve hilbert(4)");
	$s += $f;

	$f = &test_QR_solve_dim($hilb12, $hilb12_solution, 0.1 );
	&test($f, "  QR_solve hilbert(12)");
	$s += $f;

	$f = &test_QR_solve_dim($vander2, $vander2_solution, 2 * 8.0 * $EPSILON );
	&test($f, "  QR_solve vander(2)");
	$s += $f;

	$f = &test_QR_solve_dim($vander3, $vander3_solution, 2 * 64.0 * $EPSILON );
	&test($f, "  QR_solve vander(3)");
	$s += $f;

	$f = &test_QR_solve_dim($vander4, $vander4_solution, 2 * 1024.0 * $EPSILON );
	&test($f, "  QR_solve vander(4)");
	$s += $f;

	$f = &test_QR_solve_dim($vander12, $vander12_solution, 2 * 1024.0 * $EPSILON );
	&test($f, "  QR_solve vander(12)");
	$s += $f;

	return $s;
}

sub test_QR_solve_dim {
	my ($m, $actual, $eps) = @_;
	
	my $s = 0;
	my $dim = $m->rows;

	my $qr  = Anorman::Data::LinAlg::QRDecomposition->new( $m );
	my $rhs = $m->like_vector($dim);

	do { $rhs->set_quick($_, $_ + 1.0) } for (0 .. $dim - 1);

	my $x = $qr->solve($rhs);
	
	my $i = -1;
	while ( ++$i < $dim ) {
		my $foo = &check( $x->get($i), $actual->[$i], $eps ) ? 1 : 0;
		if ($foo) {
			printf("%3lu[%lu]: %22.18g  %22.18g\n", $dim, $i, $x->get($i), $actual->[$i]);
		}
		$s += $foo
	}

	return $s;
}
	
sub test_cholesky_decomp {
	my $f;
	my $s = 0;

	$f = &test_cholesky_decomp_dim($hilb2, 2 * 8.0 * $EPSILON);
	&test($f, "  cholesky_decomp hilbert(2)");
	$s += $f;

	$f = &test_cholesky_decomp_dim($hilb3, 2 * 64.0 * $EPSILON);
	&test($f, "  cholesky_decomp hilbert(3)");
	$s += $f;

	$f = &test_cholesky_decomp_dim($hilb4, 2 * 1024.0 * $EPSILON);
	&test($f, "  cholesky_decomp hilbert(4)");
	$s += $f;

	$f = &test_cholesky_decomp_dim($hilb12, 2 * 1024.0 * $EPSILON);
	&test($f, "  cholesky_decomp hilbert(12)");
	$s += $f;

	return $s;
}

sub test_cholesky_decomp_dim {
	my ($m, $eps) = @_;

	my $s = 0;
	my ($i,$j);

	my $M = $m->rows;
	my $N = $m->columns;

	my $v  = $m->copy;
	my $a  = $m->like;

	my $chol = Anorman::Data::LinAlg::CholeskyDecomposition->new( $m );

	my $l  = $chol->L;
	my $lt = $chol->LT;

	blas_gemm(BlasNoTrans, BlasNoTrans, 1.0, $l, $lt, 0.0, $a);

	for ($i=0; $i < $M; $i++ ) {
		for ($j = 0; $j < $N; $j++) {
			my $aij = $a->get($i,$j);
			my $mij = $m->get($i,$j);
			my $foo = &check($aij, $mij, $eps) ? 1 : 0;
			if ($foo) {
				printf("(%3lu,%3lu)[%lu,%lu]: %22.18g  %22.18g\n", $M, $N, $i,$j, $aij, $mij);
			}

			$s += $foo;
		}
	}

	return $s;
}

sub test_cholesky_solve {
	my $f;
	my $s = 0;

	$f = &test_cholesky_solve_dim($hilb2, $hilb2_solution, 2 * 8.0 * $EPSILON);
	&test($f,"  choolesky_solve hilbert(2)");
	$s += $f;
	
	$f = &test_cholesky_solve_dim($hilb3, $hilb3_solution, 2 * 64.0 * $EPSILON);
	&test($f,"  choolesky_solve hilbert(3)");
	$s += $f;
 
	$f = &test_cholesky_solve_dim($hilb4, $hilb4_solution, 2 * 1024.0 * $EPSILON);
	&test($f,"  choolesky_solve hilbert(4)");
	$s += $f;
 
	$f = &test_cholesky_solve_dim($hilb12, $hilb12_solution, 0.5);
	&test($f,"  choolesky_solve hilbert(12)");
	$s += $f;

	return $s; 
}

sub test_cholesky_solve_dim {
	my ($m, $actual, $eps) = @_;
	my $s = 0;
	my $i;
	my $dim = $m->rows;

	my $chol  = Anorman::Data::LinAlg::CholeskyDecomposition->new( $m );
	my $rhs = $m->like_vector($dim);

	do { $rhs->set_quick($_, $_ + 1.0) } for (0 .. $dim - 1);

	my $x = $chol->solve( $rhs );
	
	for ($i = 0; $i < $dim; $i++) {
		my $foo = &check($x->get($i), $actual->[$i], $eps);
		if ($foo) {
			printf("%3lu[%lu]: %22.18g   %22.18g\n", $dim, $i, $x->get($i), $actual->[$i]);
		}

		$s += $foo;
	}

	return $s;
}

sub test_cholesky_invert {
	my $f;
	my $s = 0;

	$f = &test_cholesky_invert_dim($hilb2, 2 * 8.0 * $EPSILON);
	&test($f,"  choolesky_invert hilbert(2)");
	$s += $f;
	
	$f = &test_cholesky_invert_dim($hilb3, 2 * 64.0 * $EPSILON);
	&test($f,"  choolesky_invert hilbert(3)");
	$s += $f;
 
	$f = &test_cholesky_invert_dim($hilb4, 2 * 1024.0 * $EPSILON);
	&test($f,"  choolesky_invert hilbert(4)");
	$s += $f;
 
	$f = &test_cholesky_invert_dim($hilb12, 0.1);
	&test($f,"  choolesky_invert hilbert(12)");
	$s += $f;

	return $s; 
}

sub test_cholesky_invert_dim {
	my ($m,$eps) = @_;

	my $s = 0;
	my ($i,$j);
	my $N = $m->rows;

	my $chol = Anorman::Data::LinAlg::CholeskyDecomposition->new( $m );
	my $v    = $chol->invert;
	my $c    = $m->like;

	blas_symm(BlasLeft, BlasUpper, 1.0, $m, $v, 0.0, $c);

	for ($i=0; $i < $N; $i++) {
		for ($j=0; $j < $N; $j++) {
			my $cij = $c->get($i,$j);
			my $expected = ($i == $j) ? 1.0 : 0.0;
			my $foo = &check( $cij, $expected, $eps);

			if ($foo) {
				printf("(%3lu,%3lu)[%lu,%lu]: %22.18g  %22.18g\n", $N, $N, $i,$j, $cij, $expected);
			}
			
			$s += $foo;
		}
	}

	return $s;
}

sub check {
	my ($x, $actual, $eps) = @_;

	if ($x == $actual) {
		return 0;
	} elsif ($actual == 0) {
		return abs($x) > $eps;
	} else {
		my $r = abs($x - $actual)/abs($actual);
		return $r > $eps;
	}
}

sub test {
	my ($status, $msg) = @_;

	&update($status);


	if ($status || $VERBOSE) {
		print ($status ? "FAIL: " : "PASS: ");
		print $msg;

		printf(" [%u]", $tests) if ($status && !$VERBOSE);

		print "\n";
	}
}

sub update {
	my $s = shift;
	$tests++;

	if ($s == 0) {
		$passed++;
	} else {
		$failed++;
	}
}

sub summary {
	if ($VERBOSE) {
		printf ("%d tests, passed %d, failed %d.\n", $tests, $passed, $failed);
	} else {
		printf("Completed [%d/%d]\n", $passed, $tests);
	}

}
