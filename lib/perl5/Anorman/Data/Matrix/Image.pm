package Anorman::Data::Matrix::Image;

use warnings;
use strict;

use Anorman::Common;

# Sobel operator kernels (3x3 matrices in list form)
#my @GX = qw/-1 0 1 -2 0 2 -1 0 1/;
#my @GY = qw/1 2 1 0 0 0 -1 -2 -1/;

# Enhanced Sobel operators

# X-direction
my @GX   = ( 2, 3, 0,-3,-2,
             3, 4, 0,-4,-3,
             6, 6, 0,-6,-6,
             3, 4, 0,-4,-3,
             2, 3, 0,-3,-2 );

# 45-degree direction
my @G45  = ( 6, 2, 3, 2, 0,
             2, 6, 4, 0,-2,
             3, 4, 0,-4,-2,
             2, 0,-4,-6,-2,
             0,-2,-3,-2,-6 );

# Y-direction
my @GY   = ( 2, 3, 6, 3, 2,
             3, 4, 6, 4, 3,
             0, 0, 0, 0, 0,
            -3,-4,-6,-4,-3,
            -2,-3,-6,-3,-2 );

# 135-degree direction
my @G135 = ( 0, 2, 3, 2, 6,
            -2, 0, 4, 6, 2,
            -3,-4, 0, 4, 3,
            -2,-6,-4, 0, 2,
            -6,-2,-3,-2, 0 );


# edge enhance 3x3 kernel
my @US = (0.5,  1,0.5,
            1, -6,  1,
          0.5,  1,0.5 );

# Gaussian blur kernel (sigma=1)
my @GF     = ( 1, 4, 7, 4, 1,
               4,16,26,16, 4,
               7,26,41,26, 7,
               4,14,26,16, 4,
               1, 4, 7, 4, 1);

my $GF_SUM = 273;

use constant PI => 4 * atan2(1, 1);

sub histogram {
	# generates a histogram of grayscale values in the U-Matrix (0..255)
	my $self = shift;
	my @hist = (0) x 256;

	
	$hist[ $_ ]++ for map { 0xFF & (255 * $_) } $self->values;

	return \@hist;
}

sub gradient_image {

	# creates a gradient image of the U-matrix
	# based on the Sobel method
	my $self   = shift;
	my $data   = shift;

	$self->_check_data_size( $data ) if defined $data;

	my $grid   = $self->{'_grid'};

	my @magnitude = ();
	my @direction = ();
	my @mask      = ();

	#warn "Sniffing pixels...\n";
	while (defined (my $p = $self->iterate)) {
	
		my $sumX   = 0;
		#my $sum45  = 0;
		my $sumY   = 0;
		#my $sum135 = 0;

		my $i    = 0;

		foreach my $n( $grid->neighbors_XbyX( $p,5 ) ) {
			my $h = defined $data ? $data->[ $n ] : $self->get( $n );
			
			my ($x, $y) = ($grid->index2row( $n ), $grid->index2col( $n ));

			#warn "$n\t($x,$y)\t$h\t$i\t$GX[ $i ]\t$GY[ $i ]\n";

			$sumX   += $h * $GX[ $i ];
			#$sum45  += $h * $G45[ $i ];
			$sumY   += $h * $GY[ $i ];
			#$sum135 += $h * $G135[ $i ];
			
			$i++;
		}

		#my $maxG = 0;

		#warn "GX: $sumX GY: $sumY G45: $sum45 G135: $sum135\n";
		#my @locD =  ($sumX, $sum45, $sumY, $sum135);

		#print STDERR join ("\t", @locD), "\n";
		
		#my $D    = 0;
		#my $maxD = 0;

		#while ($D < 4) {
		#	if (abs($locD[ $D ]) > $maxG) {
		#		$maxD = $D;
		#		$maxG = abs($locD[$D]);
		#	} 
		#	$D++;
		#}

		my $G = sqrt( ($sumX * $sumX) + ($sumY * $sumY) );
		my $theta = atan2($sumY, $sumX);
		my $D = int( (4 * ($theta + PI) ) / PI );
		
		#warn "P: $p SUMX: $sumX SUMY: $sumY THETA: $theta G: $G D: $D\n\n";
		push @magnitude, $G;
		push @direction, $D;
		#exit;

	}
	return \@magnitude;
	
	warn "Normalizing magnitudes...\n";

	&Anorman::Math::Common::normalize_zero_to_one(\@magnitude);

	warn "Resniffing pixels...\n";

	while (defined (my $p = $self->iterate)) {
		my @neighM = map { $magnitude[ $_ ] } $grid->neighbors_XbyX( $p, 3 );

		# re-arrange neighbors to correspond with gradient directions
		my @dirM     = @neighM[7,6,3,0,1,2,5,8];
		my @rev_dirM = @neighM[1,2,5,8,7,6,3,0];

		my $locD     = $direction[ $p ];
		my $locM     = $magnitude[ $p ];
		my $mask_bit = ($locM > $dirM[ $locD ] && $locM > $rev_dirM[ $locD ]);

		#if ($locD == 0) {
		#	$mask_bit = ($locM > $neighM[1] && $locM > $neighM[7]);
		#} elsif ($locD == 1) {
		#	$mask_bit = ($locM > $neighM[0] && $locM > $neighM[8]);
		#} elsif ($locD == 2) {
		#	$mask_bit = ($locM > $neighM[3] && $locM > $neighM[5]);
		#} else {
		#	$mask_bit = ($locM > $neighM[2] && $locM > $neighM[6]);
		#}

		my $color = ($mask_bit && $locM > 0.05) ? $locD : -3;
		push @mask, $color;

	}
	return \@mask;
}

sub gaussian_noise_reduction {
	my $self   = shift;
	my $data   = shift if defined $_[0];
	
	$self->_check_size( $data ) if defined $data;

	my $grid   = $self->{'_grid'};
	my @values = ();

	while (defined (my $p = $self->iterate)) {
	
		my $i   = 0;
		my $sum = 0;
	
		foreach my $n( $grid->neighbors_XbyX( $p, 5) ) {
			my $A = defined $data ? $data->[ $n ] : $self->get( $n );

			$sum += $A * $GF[ $i ];

			$i++;
		}

		my $B = ( 1 / $GF_SUM ) * $sum;
		push @values, $B;
	}

	return \@values;
}

sub edge_enhance {
	my $self   = shift;
	my $data   = shift;

	$self->_check_data_size( $data ) if defined $data;

	my $grid   = $self->{'_grid'};
	my @values = ();

	while (defined (my $p = $self->iterate)) {

		my $i = 0;	
		my $B = 0;

		foreach my $n( $grid->neighbors_XbyX( $p,3 ) ) {
			my $A  = defined $data ? $data->[ $n ] : $self->get( $n );
			my $F  = $US[ $i ];

			$i++;
				
			#next if $A < 0.03;
			$B += $A * $F;
		}

		push @values, $B;

	}

	return \@values;
}

sub normalize {
	# normalize U-matrix heights to [0..1] values
	my $self = shift;

	&Anorman::Math::Common::normalize_zero_to_one( $self->{'values'} );
}

sub calculate_threshold {
	# gradient image edge detection threshold [0..1] based on sotu method
	my $self = shift;
	my $hist = $self->histogram;

	my $max_level_value = 0;
	
	my $sum = 0;
	foreach my $h(0..255) {
		$sum += $h * $hist->[ $h ];
		$max_level_value = $hist->[ $h ] if $hist->[ $h ] > $max_level_value;
	}

	my $sumB = 0;
	my $wB   = 0;
	my $wF   = 0; 

	my $varMax    = 0;
	my $threshold = 0;

	foreach my $t(0..255) {
		$wB += $hist->[ $t ];

		next if ($wB == 0);

		$wF = $self->{'_size'} - $wB;

		last if ($wF == 0);

		$sumB += $t * $hist->[ $t ];

		my $mB = $sumB / $wB;
		my $mF = ($sum - $sumB) / $wF;

		my $varBetween = $wB * $wF * ($mB - $mF) * ($mB - $mF);

		if ($varBetween > $varMax) {
			$varMax = $varBetween;
			$threshold = $t;
		}
	}

	return ($threshold / 255);
}

1;

