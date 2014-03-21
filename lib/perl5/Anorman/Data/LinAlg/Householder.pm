package Anorman::Data::LinAlg::Householder;

use strict;
use warnings;

use Anorman::Data::BLAS qw( :L1 );
use Anorman::Data::LinAlg::Property qw( :all );
use Anorman::Math::Common qw(hypot);


use vars qw(@ISA @EXPORTER @EXPORT_OK %EXPORT_TAGS);

@EXPORT_OK = qw(
	householder_transform
	householder_hm
	hoseholder_mh
	householder_hv
	householder_hm1
);

%EXPORT_TAGS = ( all => [ @EXPORT_OK ] );

@ISA       = qw(Exporter);

sub householder_transform ($) {
	my $v = shift;

	my $n = $v->size;

	return 0.0 if $n == 1;

	my ($alpha, $beta, $tau);

	my $x = $v->view_part(1, $n - 1);

	my $xnorm = blas_nrm2($x);

	return 0.0 if $xnorm == 0;

	$alpha = $v->get_quick(0);
	$beta  = - ($alpha >= 0.0 ? +1.0 : -1.0) * hypot($alpha, $xnorm);
	$tau   = ($beta - $alpha) / $beta;

	{
		my $s = ($alpha - $beta);

		if (abs($s) > 2.2250738585072014e-308) {
			blas_scal(1.0 / $s, $x);
			$v->set_quick(0, $beta);
		} else {
			blas_scal( 2.2204460492503131e-16 / $s, $x);
			blas_scal( 1.0 / 2.2204460492503131e-16, $x);
			$v->set_quick(0,$beta);
		}
	}

	return $tau;
}

sub householder_hm ($$$) {
	my ($tau, $v, $A) = @_;

	return if $tau == 0;

	my $v1 = $v->view_part(1, $v->size - 1);
	my $A1 = $A->view_part(1,0, $A->rows - 1, $A->columns);

	my $j = -1;
	while ( ++$j < $A->columns ) {
		my $A1j = $A1->view_column($j);
		my $wj  = $A1j->dot_product($v1);
		
		$wj += $A->get_quick(0,$j);

		{
			my $A0j = $A->get_quick(0,$j);
			$A->set_quick(0, $j, $A0j - $tau * $wj);
		}

		blas_axpy( -$tau * $wj, $v1, $A1j );
	}
}

sub householder_mh ($$$) {
	my ($tau, $v, $A) = @_;

	return if $tau == 0;

	my $v1 = $v->view_part(1, $v->size - 1);
	my $A1 = $A->view_part(0,1, $A->rows, $A->columns -1);

	my $i = -1;
	while ( ++$i < $A->rows ) {
		my $A1i = $A1->view_row($i);
		my $wi  = $A1i->dot_product( $v1 );
		$wi += $A->get_quick($i,0);

		{
			my $Ai0 = $A->get_quick($i,0);
			$A->set_quick($i,0, $Ai0 - $tau * $wi);
		}

		blas_axpy( -$tau * $wi, $v1, $A1i );
	}
	
}

sub householder_hv ($$$) {
	my ($tau, $v, $w) = @_;

	my $N = $v->size;

	return if $tau == 0;

	my $d0 = $w->get_quick(0);
	my $v1 = $v->view_part(1, $N - 1);
	my $w1 = $w->view_part(1, $N - 1);
	my $d1 = $v1->dot_product( $w1 );
	my $d  = $d0 + $d1;

	{
		my $w0 = $w->get_quick(0);
		$w->set_quick(0, $w0 - $tau * $d);
	}

	blas_axpy( -$tau * $d, $v1, $w1 );
}

sub householder_hm1 ($$) {
	my ($tau, $A) = @_;

	if ($tau == 0) {
		$A->set_quick(0,0,1.0);

		my $j = 0;
		while ( ++$j < $A->columns ) {
			$A->set_quick(0,$j, 0.0);
		}

		my $i = 0;
		while ( ++$i < $A->rows ) {
			$A->set_quick($i,0,0.0);
		}

		return;
	}

	{
		my $A1 = $A->view_part(1,0, $A->rows - 1, $A->columns);
		my $v1 = $A->view_column(0);
		
		my $j = 0;
		while ( ++$j < $A->columns ) {
			my $A1j = $A1->view_column($j);
			my $wj  = $A1j->dot_product( $v1 );

			$A->set_quick(0,$j, -$tau * $wj );
			blas_axpy( -$tau * $wj, $v1, $A1j );
		}

		blas_scal( -$tau, $v1 );

		$A->set_quick(0,0, 1.0 - $tau);
	}
}

 
1;
