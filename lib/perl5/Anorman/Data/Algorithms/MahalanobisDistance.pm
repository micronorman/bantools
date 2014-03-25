package Anorman::Data::Algorithms::MahalanobisDistance;

# Calculates Mahalanobis distance between vectors
# DM(x) = sqrt( (x - µ)^T * S^-1 * (x - µ) ), where x is a multivariate
# vector, S is the covariance matrix of matrix M and µ is the mean vector of a set
#
# read more at http://en.wikipedia.org/wiki/Mahalanobis_distance
# Anders Norman September 2013, lordnorman@gmail.com

use strict;
use warnings;

use Anorman::Common;

use Anorman::Math::Common qw(quiet_sqrt);
use Anorman::Data::Algorithms::Statistic;
use Anorman::Data::LinAlg::CholeskyDecomposition;
use Anorman::Data::LinAlg::LUDecomposition;
use Anorman::Data::LinAlg::QRDecomposition;
use Anorman::Data::LinAlg::Property qw( :matrix check_vector );

sub new {
	my $that  = shift;
	my $class = ref $that || $that;
	my $self  = bless ( {}, $class );

	if (defined $_[0]) {
		check_matrix( $_[0] );

		my $M     = $_[0];
		my $m     = $M->rows;
		my $n     = $M->columns;
		my @means = ();

		warn "Calculating column means...\n" if $VERBOSE;

		my $j = $n;
		while ( --$j >= 0 ) {
			$means[ $j ] = $M->view_column( $j )->sum / $m;
		}
	
		$self->means( $M->like_vector($n)->assign( \@means ) );

		warn "Calculating covariance matrix from " . $M->_to_short_string . " data set...\n" if $VERBOSE;
		my $cov  = Anorman::Data::Algorithms::Statistic::covariance($M);

		$self->covariance( $cov );	
	};

	return bless ($self, $class);
}

sub covariance {
	my $self = shift;

	return $self->{'covariance'} if defined $self->{'covariance'};

	my $C = shift;
	check_matrix( $C );
	check_square( $C );

	if (defined $self->{'_n'}) {
		trace_error("Covariance matrix has wrong size") if ($C->rows != $self->{'_n'});
	} else {
		$self->{'_n'} = $C->rows;
	}

	warn "Performing Cholesky decomposition...\n" if $VERBOSE;
	my $chol = Anorman::Data::LinAlg::CholeskyDecomposition->new( $C );

	if ($chol->is_symmetric_positive_definite) {
		$self->{'_decomp'} = $chol;
	} else {
		warn "Matrix was not positive-definite. Trying LU decomposition...\n" if $VERBOSE;
		my $lu = Anorman::Data::LinAlg::LUDecomposition->new( $C );

		if (!$lu->singular) {
			$self->{'_decomp'} = $lu;
		}  else {
			warn "Matrix was singular. Trying QR decomposition...\n" if $VERBOSE;
			my $qr = Anorman::Data::LinAlg::QRDecomposition->new( $C );
			$self->{'_decomp'} = $qr;
		}
	}

	$self->{'covariance'} = $C;
}
	

sub means {
	my $self = shift;
	return $self->{'means'} if defined $self->{'means'};
	
	my $m = shift;
	
	check_vector($m);

	if (defined $self->{'_n'}) {
		trace_error("Means vector has the wrong length") if ($m->size != $self->{'_n'});
	} else {
		$self->{'_n'} = $m->size;
	}

	$self->{'means'} = $m;

}

sub MAHAL {
	# Mahalanobis Distance
	my ($self, $vector) = @_;

	return quiet_sqrt( $self->GSID( $vector ) );	
}

sub GSID {
	# Generalized squared interpoint distance
	my ($self, $v) = @_;

	check_vector($v);

	trace_error("Input vector has wrong length") if $v->size != $self->{'_n'};
	
	my $diff = $v - $self->{'means'};

	return $self->{'_decomp'}->solve( $diff )->dot_product( $diff );
}

1;
