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

use Anorman::Data;
use Anorman::Data::Algorithms::Statistic qw(covariance);
use Anorman::Data::Functions::VectorVector qw(vv_minus_assign);
use Anorman::Data::LinAlg::Algebra qw(rank);
use Anorman::Data::LinAlg::CholeskyDecomposition;
use Anorman::Data::LinAlg::LUDecomposition;
use Anorman::Data::LinAlg::Property qw( :matrix check_vector );

sub new {
	my $class = ref $_[0] ? ref shift : shift;

	my $self = { '_inv_covar_matrix' => undef,
		     '_covarance_matrix' => undef,
		     '_means'            => undef,
		     '_n'                => 0, 
	};

	if (defined $_[0]) {
		check_matrix( $_[0] );
		my $M     = $_[0];
		my $m     = $M->columns;
		my $n     = $M->rows;
		my @means = ();

		my $j = $m;
		while ( --$j >= 0 ) {
			$means[ $j ] = $M->view_column( $j )->sum / $n;
		}
		
		$self->{'_means'} = $M->like_vector($m)->assign(\@means);
		$self->{'_n'}     = $m;

		# Perform Cholesky Decomposition
		my $cov  = covariance($M);
		$self->{'_covariance_matrix'} = $cov;

		my $inv_covar;

		# Generate identity matrix
		my $identity = Anorman::Data->identity_matrix($m);
		$identity = is_packed($cov) ? $identity->pack : $identity;

		# Attempt Cholesky Decomposition
		my $chol =  Anorman::Data::LinAlg::CholeskyDecomposition->new( $cov );

		if ( $chol->is_symmetric_positive_definite ) {

			# Calculate invese covariance matrix
			$inv_covar = $chol->solve( $identity );
		} else {
			warn "WARNING: Covariance Matrix was not Symmetric Positive-Definite. LU factorization was used instead of Cholesky\n";

			my $lu = Anorman::Data::LinAlg::LUDecomposition->new( $cov );

			$inv_covar = $lu->solve( $identity );
		}

		$self->{'_inv_covar_matrix'} = $inv_covar;
	};

	return bless ($self, $class);
}

sub get_covariance {
	my $self = shift;
	return $self->{'_covariance_matrix'};
}

sub get_inverse_covariance {
	my $self = shift;
	return $self->{'_inv_covar_matrix'};
}

sub set_inverse_covariance {
	# provide a pre-calculated covariance matrix
	my $self = shift;

	check_square($_[0]);
	check_matrix($_[0]);

	my ($M, $invert) = @_;

	if (defined $self->{'_means'}) {
		trace_error("Means vector is incompatible (" . $self->{'_n'} . ") with covariance matrix " . $M->_to_short_string ) 
		if ($M->rows != $self->{'_n'});
	} else {
		$self->{'_n'} = $M->rows;
	}

	if ($invert) {
		my $identity = Anorman::Data->identity_matrix($M);
		$identity = $identity->pack if is_packed($M);
		$self->{'_inv_covar_matrix'} = Anorman::Data::LinAlg::CholeskyDecomposition->new($M)->solve( $identity );
	} else {
		$self->{'_inv_covar_matrix'} = $M->copy;
	}
}

sub get_means {
	my $self = shift;
	return $self->{'_means'};
}

sub set_means {
	my $self = shift;

	check_vector($_[0]);

	my $means = shift;

	if (defined $self->{'_inv_covar_matrix'}) {

		# check vector size against covariance matrix
		trace_error("Means vector is incompatible (" . $means->size . ") with covariance matrix " . 
			$self->{'_inv_covar_matrix'}->_to_short_string ) if ($means->size != $self->{'_n'});
	} else {
		$self->{'_n'} = $means->size;
	}

	$self->{'_means'} = $means;
}

sub distance {
	# Mahalanobis Distance
	my ($self, $x_vec, $y_vec) = @_;

	# sanity checks
	trace_error("No inverse covariance matrix defined") if !defined $self->{'_inv_covar_matrix'};
	check_vector($x_vec);
	trace_error("Vector has incompatible size (" . $x_vec->size . ") with covariance matrix " 
		. $self->{'_inv_covar_matrix'}->_to_short_string ) if ($x_vec->size != $self->{'_n'});

	# pick matrix means if no second vector was provided
	#if (defined $y_vec) {
	##	$x_vec->check_size($y_vec);
	#} else {
	#	trace_error("No means defined. You must provide a second vector") unless defined $self->{'_means'};
		$y_vec = $self->{'_means'};
	#}

	my $diff  = $x_vec->copy;

	# use fast subtraction if both vectors are packed
	if (is_packed($diff) && is_packed($y_vec)) {
		vv_minus_assign( $diff, $y_vec );
	# otherwise use the pure perl (slow) method
	} else {
		$diff->assign( $y_vec, sub { $_[0] - $_[1] } );
	}

	return sqrt( $self->{'_inv_covar_matrix'}->mult( $diff )->dot_product( $diff )) || 'err';	
}

sub GSID {
	# Generalized squared interpoint distance
	my ($self, $vector) = @_;
	my $diff = $vector->copy;
	vv_minus_assign( $diff, $self->{'_means'} );

	return $self->{'_inv_covar_matrix'}->mult( $diff )->dot_product( $diff );
}

1;
