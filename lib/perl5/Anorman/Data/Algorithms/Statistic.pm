package Anorman::Data::Algorithms::Statistic;

use strict;
use warnings;

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
use Anorman::Data;
use Anorman::Data::Functions::Vector;
use Anorman::Data::LinAlg::Property qw( :matrix );
#use Anorman::Data::Functions::VectorVector qw(vv_covariance);

my $VF = Anorman::Data::Functions::Vector->new;

=head OLD_STUFF
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
=cut

sub covariance {
	return &distance( $_[0], $VF->covariance );
}

sub correlation {
	return &distance( $_[0], $VF->correlation );
}

sub distance {
	trace_error("Second argument must be a subroutine reference") unless (defined $_[1] && ref $_[1] eq 'CODE');
	
	my ($A, $distance_function) = @_;

	check_matrix($A);

	my $N = $A->columns;

	# Cache columns
	my @cols = map { $A->view_column( $_ ) } ( 0 .. $N - 1);

	# Set up resulting distance matrix
	my $D   = Anorman::Data->matrix($N,$N);

	my ($i,$j);

	$i = $N;
	while ( --$i >= 0 ) {
		$j = $i + 1;
		while ( --$j >= 0 ) {

			# Calculate vector distance
			my $cov = $distance_function->($cols[$i], $cols[$j]);

			$D->set($i, $j, $cov);
			$D->set($j, $i, $cov) unless ($i == $j); # cuz' it's symmetric
		}	
	}

	return $D;
}

1;
