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
use Anorman::Data::LinAlg::Property qw( :matrix );
use Anorman::Math::VectorFunctions;

my $VF = Anorman::Math::VectorFunctions->new;

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

			# Assign to symemtric matrix
			$D->set_quick($i, $j, $cov);
			$D->set_quick($j, $i, $cov) unless ($i == $j); # cuz' it's symmetric
		}	
	}

	return $D;
}

1;
