package Anorman::ESOM::Descriptives;

use strict;

use Anorman::Common;
use Anorman::Data;
use Anorman::Data::LinAlg::Property qw( :matrix );
use Anorman::Data::LinAlg::EigenValueDecomposition;
use Anorman::Data::Algorithms::Statistic;

sub new {
	my $that  = shift;
	my $class = ref $that || $that;
	my $data  = shift;
	
	check_matrix( $data );

	my $self = { '_data'   => $data,
                     '_maxima' => undef,
		     '_minima' => undef,
		     '_means'  => undef,
		     '_stdevs' => undef,
		     '_cov'    => undef,
		     '_ev'     => undef,
		     '_evd'    => undef
	};

	bless ( $self, ref $class || $class);

	$self->_calculate_descriptives;
	return $self;
}

sub maxima { $_[0]->{'_maxima'} }
sub minima { $_[0]->{'_minima'} }
sub stdevs { $_[0]->{'_stdevs'} }
sub means  { $_[0]->{'_means'}  }
sub size   { $_[0]->{'_size'}   }

sub covariance {
	my $self = shift;

	$self->_calc_pca unless defined $self->{'_cov'};

	return $self->{'_cov'};
}

sub eigenvalue {
	my $self = shift;
	my $i    = shift;

	return $self->eigenvalues->get( $self->{'_data'}->columns - $i - 1 );
}

sub first_eigenvalue {
	my $self = shift;
	
	return $self->eigenvalue(0);
}

sub second_eigenvalue {
	my $self = shift;

	return $self->eigenvalue(1);
}

sub third_eigenvalue {
	my $self = shift;
	return $self->eigenvalue(2);
}

sub eigenvalues {
	my $self = shift;
	
	$self->_calc_pca unless defined $self->{'_evd'};

	return $self->{'_evd'}->getRealEigenvalues;
}

sub eigenvectors {
	my $self = shift;
	
	$self->_calc_pca unless defined $self->{'_ev'};

	return $self->{'_ev'};
}

sub eigenvector {
	my $self = shift;
	my $i    = shift;
	return $self->eigenvectors->view_column( $self->{'_data'}->columns - $i - 1);
}

sub first_eigenvector {
	my $self = shift;
	return $self->eigenvector(0);
}

sub second_eigenvector {
	my $self = shift;
	return $self->eigenvector(1);
}

sub third_eigenvector {
	my $self = shift;
	return $self->eigenvector(2);
}

sub projection {
	my $self = shift;
	my $i    = shift;

	$self->_calc_pca unless defined $self->{'_evd'};

	my $ev = $self->get_eigenvector($i);

}

sub _calculate_descriptives {
	my $self = shift;
	my $A    = $self->{'_data'};

	my $M = $A->columns;
	my $N = $A->rows;
	my $v = $A->like_vector( $M );

	# this pre-loads first row into minima, maxima and sums
	my $row0   = [ @{ $A->view_row(0) } ];
	my $sums   = [ @{ $row0 } ];
	my $minima = [ @{ $row0 } ];
	my $maxima = [ @{ $row0 } ];

	my $stdevs = [];
	my $means  = [];

	my ($i,$j);
	
	warn "Calculating descriptives...\n" if $VERBOSE;

	$i = $N;

	# skips first row, since it was already loaded
	while ( --$i > 0 ) {
	
		$j = $M;
		while ( --$j >= 0 ) {
			my $val   = $A->get_quick( $i, $j );

			$sums->[ $j ]  += $val;
			$minima->[ $j ] = $minima->[ $j ] < $val ? $minima->[ $j ] : $val;
			$maxima->[ $j ] = $maxima->[ $j ] > $val ? $maxima->[ $j ] : $val;
		}

	}
	
	$j = $M;
	while ( --$j >= 0 ) {
		$means->[ $j ] = $sums->[ $j ] / $N;
	}
	
	$i = $N;
	while ( --$i >= 0 ) {
	
		$j = $M;
		while ( --$j >= 0 ) {
			my $diff = $means->[ $j ] - $A->get_quick( $i, $j );

			$stdevs->[ $j ] += ($diff * $diff);
		}

	}

	foreach (@{ $stdevs }) { $_ = sqrt( $_ / ($N - 1) )};

	$self->{'_minima'} = $v->like->assign( $minima );
	$self->{'_maxima'} = $v->like->assign( $maxima );
	$self->{'_means'}  = $v->like->assign( $means  );
	$self->{'_stdevs'} = $v->like->assign( $stdevs );
	$self->{'_size'}   = $N;
}

sub _calc_pca {
	my $self = shift;
	my $data = $self->{'_data'};

	warn "Calculating Covariance matrix...\n" if $VERBOSE;
	$self->{'_cov'} = Anorman::Data::Algorithms::Statistic::covariance( $data );

	warn "Calculating Eigenvalues...\n" if $VERBOSE;
	$self->{'_evd'} = Anorman::Data::LinAlg::EigenValueDecomposition->new( $self->{'_cov'} );
	$self->{'_ev'}  = $self->{'_evd'}->getV;
}

1;
