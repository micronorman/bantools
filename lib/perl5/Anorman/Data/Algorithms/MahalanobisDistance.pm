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
use Anorman::Math::VectorFunctions;
use Anorman::Data::Algorithms::Statistic;
use Anorman::Data::LinAlg::CholeskyDecomposition;
use Anorman::Data::LinAlg::LUDecomposition;
use Anorman::Data::LinAlg::QRDecomposition;
use Anorman::Data::LinAlg::Property qw( :matrix check_vector );

my $VF = Anorman::Math::VectorFunctions->new;

sub new {
	my $that  = shift;
	my $class = ref $that || $that;
	my $self  = bless ( {}, $class );

	if (defined $_[0]) {
		check_matrix( $_[0] );

		my $A     = $_[0];
		my $m     = $A->rows;
		my $n     = $A->columns;
		my @means = ();

		$self->{'_m'} = $m;
		$self->{'_n'} = $n;

		warn "Calculating column means...\n" if $VERBOSE;

		my $j = $n;
		while ( --$j >= 0 ) {
			$means[ $j ] = $A->view_column( $j )->sum / $m;
		}
	
		$self->means( $A->like_vector($n)->assign( \@means ) );

		warn "Calculating covariance matrix from " . $A->_to_short_string . " data set...\n" if $VERBOSE;
		my $cov  = Anorman::Data::Algorithms::Statistic::covariance($A);

		$self->covariance( $cov );	
	};

	return bless ($self, $class);
}

sub covariance {
	return $_[0]->{'covariance'} unless @_ > 1;
	
	my $self = shift;

	# New covariance matrix
	my $C = shift;

	check_matrix( $C );
	check_square( $C );

	if (defined $self->{'_n'}) {
		trace_error("Covariance matrix has the wrong size: " . $C->_to_short_string . " vs " . $self->{'_n'} ) if ($C->rows != $self->{'_n'});
	} else {
		$self->{'_n'} = $C->rows;
	}

	if (is_identity( $C )) {
		$self->{'_func'} = $VF->EUCLID;
	} else {	
		warn "Performing Cholesky decomposition...\n" if $VERBOSE;
		my $chol = Anorman::Data::LinAlg::CholeskyDecomposition->new( $C );

		if ($chol->is_symmetric_positive_definite) {
			$self->{'_func'} = $VF->MAHALANOBIS( $chol );
		} else {
			warn "Matrix was not positive-definite. Trying LU decomposition...\n" if $VERBOSE;
			my $lu = Anorman::Data::LinAlg::LUDecomposition->new( $C );

			if (!$lu->singular) {
				$self->{'_func'} = $VF->MAHALANOBIS( $lu );
			}  else {
				warn "Matrix was singular. Trying QR decomposition...\n" if $VERBOSE;
				my $qr = Anorman::Data::LinAlg::QRDecomposition->new( $C );
				$self->{'_func'} = $VF->MAHALANOBIS( $qr );
			}
		}
	}

	$self->{'covariance'} = $C;
}
	
sub size {
	return $_[0]->{'_m'} unless @_ > 1;

	# The size of the original dataset (i.e. no. of rows in the input matrix);
	$_[0]->{'_m'} = $_[1];
}

sub means {
	return $_[0]->{'means'} unless @_ > 1;

	# Vector of column means
	my $self = shift;
	my $m    = shift;
	
	check_vector($m);

	if (defined $self->{'_n'}) {
		trace_error("Means vector has the wrong length") if ($m->size != $self->{'_n'});
	} else {
		$self->{'_n'} = $m->size;
	}

	$self->{'means'} = $m;

}

sub distance {
	my $self = shift;

	my ($v, $u) = @_;

	return $self->{'_func'}->($v, $u);
}

sub get_function {
	return $_[0]->{'_func'};
}

1;
