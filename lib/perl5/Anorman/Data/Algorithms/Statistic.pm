package Anorman::Data::Algorithms::Statistic;

use Exporter;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);
@EXPORT_OK = qw(
	covariance
	correlation
	distance
);

%EXPORT_TAGS = ( all => [ @EXPORT_OK ] );

use Anorman::Common;
use Anorman::Data::Matrix::Dense;
use Anorman::Data::Matrix::DensePacked;
use Anorman::Data::LinAlg::Property qw( :matrix );
use Anorman::Data::Functions::VectorVector qw(vv_covariance);
use Anorman::Data::Functions::Vector qw (v_variance);

sub correlation {
	my ($A) = @_;
	check_matrix($A);
	check_square($A);
	
	my $i = $A->columns;
	while ( --$i >= 0 ) {
		my $j = $i;
		while ( --$j >= 0 ) {
			my $std_dev1 = sqrt( $A->get_quick($i,$i));
			my $std_dev2 = sqrt( $A->get_quick($j,$j));
			my $cov      = $A->get_quick($i,$j);
			my $corr     = $cov / ($std_dev1 * $std_dev2);

			$A->set_quick($i,$j,$corr);
			$A->set_quick($j,$i,$corr);
		}
	}

	# Fill digonal with 1's
	do { $A->set_quick($_,$_,1) } for (0 .. $A->columns - 1);

	return $A;
}

sub covariance {
	# returns the covariance matrix of the given matrix
	my ($A) = @_;
	
	check_matrix($A);

	my $rows    = $A->rows;
	my $columns = $A->columns;

	
	my @sums = ();	
	my @cols = ();

	my $covariance;
	my $func;

	my ($i,$j);

	# Use optimized function if matrix is packed
	if (is_packed($A)) {
		$covariance = Anorman::Data::Matrix::DensePacked->new( $columns, $columns ); 		

		$i = $columns;
		while ( --$i >= 0 ) {
			$cols[ $i ] = $A->view_column($i);
		}

		$func       = \&vv_covariance;
 	} else {
		$covariance =  Anorman::Data::Matrix::Dense->new( $columns, $columns );

		$i = $columns;
		while ( --$i >= 0 ) {
			$cols[ $i ] = $A->view_column($i);
			$sums[ $i ] = $cols[$i]->sum;
		}

		$func       = sub { my $sop    = $_[0]->dot_product( $_[1] ); 
				    my $result = ($sop - $sums[ $i ] * $sums[ $j ] / $rows ) / $rows;
				    return $result; 
                                  };
	}

	# Fill covariance matrix
	$i = $columns;
	while ( --$i >= 0 ) {
		$j = $i + 1;
		while ( --$j >= 0 ) {
			my $cov = $func->($cols[$i], $cols[$j]);
		
			$covariance->set_quick($i,$j,$cov);
			$covariance->set_quick($j,$i,$cov) unless ($i == $j); # Symmetry
		}
	}
	
	return $covariance;
}

sub distance {
	check_matrix($_[0]);
	trace_error("Second argument must a blessed object containing the method \'apply\'") unless (defined $_[1] && $_[1]->can('apply'));

	my ($matrix, $distance_function) = @_;

	my $m = $matrix->columns;
	my $distance = is_packed($matrix) ? Anorman::Data::Matrix::DensePacked->new($m,$m) : Anorman::Data::Matrix::Dense->new($m,$m);

	my @cols = map { $matrix->view_column($_) } (0 .. $m - 1);

	warn "Calculating Distances...\n" if $VERBOSE;
	
	my $i = $m;
	while ( --$i >= 0) {

		my $j=$i;
		while ( --$j >= 0 ) {
			my $d = $distance_function->apply($cols[$i], $cols[$j]);
			$distance->set_quick($i,$j,$d);
			$distance->set_quick($j,$i,$d);
		}
	} 
	
	return $distance;
}

1;
