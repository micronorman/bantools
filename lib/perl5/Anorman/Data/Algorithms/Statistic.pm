package Anorman::Data::Algorithms::Statistic;

use Exporter;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);
@EXPORT_OK = qw(
	covariance
	distance
);

%EXPORT_TAGS = ( all => [ @EXPORT_OK ] );

use Anorman::Common;
use Anorman::Data::Matrix::Dense;
use Anorman::Data::Matrix::DensePacked;
use Anorman::Data::LinAlg::Property qw( :matrix );

sub covariance {
	# returns the covariance matrix of the given matrix
	my ($A) = @_;
	
	check_matrix($A);

	my $rows    = $A->rows;
	my $columns = $A->columns;

	my $covariance = is_packed($A) ? Anorman::Data::Matrix::DensePacked->new( $columns, $columns ) :  Anorman::Data::Matrix::Dense->new( $columns, $columns );
	
	my @sums = ();	
	my @cols = ();

	my $i = $columns;
 
	# cache column views and sums
	while ( --$i >= 0 ) {
		$cols[ $i ] = $A->view_column($i);
		$sums[ $i ] = $cols[$i]->sum;
	}

	$i = $columns;
	while ( --$i >= 0 ) {
		my $j = $i + 1;
		while ( --$j >= 0 ) {
			my $sum_of_products = $cols[$i]->dot_product( $cols[ $j ] );
			my $cov             = ($sum_of_products - $sums[ $i ] * $sums[ $j ] / $rows) / $rows;
			
			$covariance->set_quick($i,$j,$cov);
			$covariance->set_quick($j,$i,$cov);
		}
	}	
	return $covariance;
}

sub distance {
	check_matrix($_[0]);
	trace_error("Second argument must an object containing the method \'apply\'") unless ($_[1]->can('apply'));

	my ($matrix, $distance_function) = @_;

	my $m = $matrix->columns;
	my $distance = is_packed($matrix) ? Anorman::Data::Matrix::DensePacked->new($m,$m) : Anorman::Data::Matrix::Dense->new($m,$m);

	my @cols = map { $matrix->view_column($_) } (0 .. $m - 1);

	warn "Calculating Distances...\n";
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
