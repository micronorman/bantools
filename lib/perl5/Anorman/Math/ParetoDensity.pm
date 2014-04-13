package Anorman::Math::ParetoDensity;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Math::Common qw(multi_quantiles round);
use Anorman::Math::VectorFunctions;
use Anorman::Data;
use Anorman::Data::LinAlg::Property qw(check_matrix);

use List::Util qw(min max);

use parent 'Anorman::Math::Distances';

use Data::Dumper;

use constant {
	PARETO_SIZE => 0.2013
};

my @clF = (     1, 0.673655, 0.540071, 0.448394, 0.380795, 0.3263, 0.286768,
                0.25035, 0.225546, 0.202865, 0.185515, 0.170194, 0.157708,
                0.145808, 0.136427, 0.127417, 0.119922, 0.113884, 0.10755,
                0.102236, 0.097573, 0.09319, 0.088828, 0.085517, 0.081595,
                0.078621, 0.075995, 0.072974, 0.070437, 0.101487, 0.097475,
                0.09462, 0.091768, 0.089551, 0.08696, 0.084779, 0.082454,
                0.080437, 0.078333, 0.076277 );

sub new {
	my $that = shift;
	my $class = ref $that || $that;

	my $self = $class->SUPER::new();

	$self->{'distance_percentiles'} = undef;
	$self->{'radius'}               = 0;
	$self->{'clusters'}             = 6;
	$self->{'centers'}              = undef;
	$self->{'densities'}            = undef;
	$self->{'_maximum'}             = undef;
	$self->{'_minimum'}             = undef;
	$self->{'_density_quantiles'}   = undef;

	return $self;
}

sub data {
	my $self = shift;
	my $data = shift;

	if (!$data->equals( $self->{'data2d'} )) {
		$self->_reset;
		$self->SUPER::data($data);
	}
}

sub centers {
	my $self = shift;
	return $self->{'centers'} if @_ == 0;

	check_matrix($_[0]);
	if (defined $self->{'centers'} && !$self->{'centers'}->equals( $_[0] ) || !defined $self->{'centers'}) {
		$self->{'densities'} = undef;
		$self->{'centers'} = $_[0];	
	}
}

sub calculate_densities {
	my $self = shift;

	unless (defined $self->{'centers'}) {
		$self->{'densities'} = Anorman::Data->vector( $self->{'_n'} );

		my ($i,$j);

		$i = -1;
		while ( ++$i < $self->{'_n'} ) {
			my $sum = -1;
		
			$j = -1;
			while ( ++$j < $self->{'_n'} ) {
				$sum++ if ($self->get($i,$j) <= $self->{'radius'})
			}

			$self->{'densities'}->set( $i, $sum );
		}
	} else {
		my $centers = $self->{'centers'};
		my $data    = $self->{'data'};
		my $r       = $self->{'radius'};
		my $m       = $centers->rows;
		my $df = Anorman::Math::VectorFunctions->EUCLID_UPTO;

		$self->{'densities'} = Anorman::Data->vector($m);

		warn "Calculating Densities (radius: $r)\n" if $VERBOSE;
		my ($i,$j);

		$i = -1;
		while ( ++$i < $m ) {
			my $sum = -1;

			$j = -1;
			while ( ++$j < $self->{'_n'} ) {
				$sum++ if $df->( $centers->view_row($i), $data->[$j], $r) <= $r;
			}

			$self->{'densities'}->set( $i, $sum );
		}

	}
}

sub calculate_distances {
	my $self = shift;

	trace_error("Data matrix not set") if (!defined $self->{'data'});

	$self->SUPER::_calculate_distances;
	$self->_fill_percentiles;
}

sub _fill_percentiles {
	my $self = shift;

	my @values = sort { $a <=> $b } @{ $self->{'distances'} };
	my @phis   = map { $_ / 100 } (1 .. 100);

	my @quantiles = multi_quantiles( \@phis, \@values );

	$self->{'distance_percentiles'} = Anorman::Data->vector(\@quantiles);	
}

sub get_max {

}

sub get_min {

}

sub get_max_density_index {
	my $self = shift;
	my $densities = $self->{'densities'};
	unless (defined $densities) {
		$self->calculate_densities;
	}

	my $idx = 0;

	my $i = 0;
	while ( ++$i < $densities->size ) {
		if ($densities->get_quick($idx) < $densities->get_quick($i)) {
			$idx = $i;
		}
	}

	return $idx;
}

sub radius {
	my $self = shift;

	if (@_ == 1) {
		my $r = shift;
		if ($r =~ m/\d+\.\d+/) {
			if ($r != $self->{'radius'}) {
				$self->{'radius'} = $r;
				$self->{'densities'} = undef;
			}
		} else {
			unless (defined $self->{'distance_percentiles'}) {
				$self->{'densities'} = undef;
				$self->calculate_densities;
			}
			warn "set radius by percentile: $r\n" if $DEBUG;
			$self->radius( $self->{'distance_percentiles'}->get_quick($r - 1));
		}
	} else {
		return $self->{'radius'};
	}
}

sub get_pareto_radius {
	my $self = shift;

	unless (defined $self->{'distance_percentiles'}) {
		$self->calculate_distances;
	}

	return $self->_pareto_radius;
}

sub set_pareto_radius {
	my $self = shift;

	$self->radius( $self->get_pareto_radius );
}

sub _pareto_radius {
	my $self = shift;

	my $percentile = 18;
	my $last_percentile = $percentile;
	my $diff = 0.0;
	my $last_diff = 1.0;

	my $median_size;
	my $stop;

	my $upper_percentile = 50;
	my $lower_percentile  = 2;

	my $upper_size = 1.0;
	my $lower_size = 0.0;

	warn "Searching pareto radius...\n" if $VERBOSE;

	while (!$stop) {
		$self->{'radius'} = $self->{'distance_percentiles'}->get_quick($percentile);

		$self->calculate_densities();

		$median_size = Anorman::Math::VectorFunctions->median->( $self->{'densities'} ) / $self->{'_n'};

		warn "spheres for " . $percentile . "%-tile contain on average " 
			. round($median_size * 100) . "% of the data\n" if $VERBOSE;

		$diff = $median_size - PARETO_SIZE;

		$stop = (abs($percentile - $last_percentile) == 1)
			|| ($percentile == $upper_percentile)
			|| ($percentile == $lower_percentile);

		if (!$stop) {
		$last_percentile = $percentile;
		$last_diff       = $diff;

		if ($diff > 0) {
			$upper_percentile = $percentile;
			$upper_size = $median_size;
		} else {
			$lower_percentile = $percentile;
			$lower_size = $median_size;
		}
		
		my $pest = ((PARETO_SIZE - $lower_size) / ($upper_size
			- $lower_size) * ($upper_percentile - $lower_percentile))
			+ $lower_percentile;

		warn "estimated percentile $pest\n" if $DEBUG;

		my $step = $pest - $percentile;

		if ($step < 0) {
			$step = min($step, - 1);
		} else {
			$step = max( $step, 1);
		}

		warn "percentile step $step\n" if $DEBUG;
		$percentile += round($step);
		warn "$last_percentile%->$percentile%\n" if $DEBUG;

		} else {
			$percentile = $last_percentile if (abs($diff) > abs($last_diff));
		}
		
	}

	warn "$percentile%-tile chosen.\n" if $VERBOSE;

	warn "adjusting pareto radius for about $self->{'clusters'} clusters.\n" if $VERBOSE;
	$self->{'radius'} = $self->{'distance_percentiles'}->get_quick( $percentile ) * $clF[ $self->{'clusters'} + 1 ];

	return $self->{'radius'}
}

sub _reset {
	my $self = shift;

	$self->{'distance_percentiles'} = undef;
	$self->{'densities'}            = undef;
	$self->{'centers'}              = undef;
	$self->{'radius'}               = 0;
	$self->{'_density_quantiles'}   = undef;
	$self->{'_maximum'}             = 0;
	$self->{'_minimuim'}            = 0;
}

1;

   
