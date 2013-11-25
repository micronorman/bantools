package Anorman::ESOM::Descriptives;

use strict;

use Anorman::Common;
use Anorman::Data::Matrix::Dense;
use Anorman::Data::LinAlg::Property qw( :matrix );
use Anorman::Data::LinAlg::EigenValueDecomposition;
use Anorman::Data::Algorithms::Statistic;

use Data::Dumper;

sub new {
	my $class     = shift;
	my $data      = shift;
	
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

sub maxima {
	my $self = shift;
	return $self->{'_maxima'};
}

sub minima {
	my $self = shift;
	return $self->{'_minima'};
}

sub stdevs {
	my $self = shift;
	return $self->{'_stdevs'};
}

sub means {
	my $self = shift;
	return $self->{'_means'};
}

sub covariance {
	my $self = shift;

	$self->_calc_pca unless defined $self->{'_cov'};

	return $self->{'_cov'};
}

sub eigenvalue {
	my $self = shift;
	my $i    = shift;

	return $self->eigenvalues->[ $self->{'_columns'} - $i - 1 ];
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

sub projection {
	my $self = shift;
	$self->_calc_pca unless defined $self->{'_evd'};


}

sub _calculate_descriptives {
	my $self = shift;
	my $data = $self->{'_data'};

	my $columns = $data->columns;
	my $rows    = $data->rows;

	# this pre-loads first row into minima, maxima and sums
	my $row0   = [ @{ $data->view_row(0) } ];
	my $sums   = [ @{ $row0 } ];
	my $minima = [ @{ $row0 } ];
	my $maxima = [ @{ $row0 } ];

	my $stdevs = [];
	my $means  = [];

	my ($i,$j);
	
	warn "Calculating descriptives...\n";

	$i = $rows;

	# skips first row, since it was already loaded
	while ( --$i > 0 ) {
	
		$j = $columns;
		while ( --$j >= 0 ) {
			my $val   = $data->get_quick( $i, $j );

			$sums->[ $j ]  += $val;
			$minima->[ $j ] = $minima->[ $j ] < $val ? $minima->[ $j ] : $val;
			$maxima->[ $j ] = $maxima->[ $j ] > $val ? $maxima->[ $j ] : $val;
		}

	}
	
	$j = $columns;
	while ( --$j >= 0 ) {
		$means->[ $j ] = $sums->[ $j ] / $rows;
	}
	
	$i = $rows;
	while ( --$i >= 0 ) {
	
		$j = $columns;
		while ( --$j >= 0 ) {
			my $val   = $data->get_quick( $i, $j );
			my $diff   = $means->[ $j ] - $data->get_quick( $i, $j );

			$stdevs->[ $j ] += ($diff * $diff);
		}

	}

	foreach (@{ $stdevs }) { $_ = sqrt( $_ / ($rows - 1) )};
	
	$self->{'_minima'} = $minima;
	$self->{'_maxima'} = $maxima;
	$self->{'_means'}  = $means;
	$self->{'_stdevs'} = $stdevs;
}

sub _calc_pca {
	my $self = shift;
	my $data = $self->{'_data'};

	warn "Calculating Covariance matrix...\n";
	$self->{'_cov'} = Anorman::Data::Algorithms::Statistic::covariance( $data );

	warn "Calculating Eigenvalues...\n";
	$self->{'_evd'} = Anorman::Data::LinAlg::EigenValueDecomposition->new( $self->{'_cov'} );
	$self->{'_ev'}  = $self->{'_evd'}->getV;
}

sub _error {
	shift;
	trace_error(@_);
}

1;
