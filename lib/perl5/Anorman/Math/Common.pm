package Anorman::Math::Common;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

use Exporter;

@EXPORT_OK = qw(log10 log2 hypot quiet_sqrt round trmean multi_quantiles quantile);

@ISA = qw(Exporter);

use List::Util;
use Anorman::Math::Algorithm qw(golden_section_search);
use Anorman::Common;
use POSIX;

#====== COMMON MATHS FUNCTIONS ====

#sub log10 { return (log $_[0] / log 10) };

sub log2  { return (log $_[0] / log 2) };

sub hypot {
	my ($a,$b) = @_;
	my $r;

	if (abs( $a ) > abs( $b )) {
		$r = $b / $a;
		$r = abs( $a ) * sqrt(1 + $r * $r);
	} elsif ($b != 0) {
		$r = $a / $b;
		$r = abs( $b ) * sqrt(1 + $r * $r);
	} else {
		$r = 0.0;
	}

	return $r;
}

sub round {
	return $_[0] >= 0 ? POSIX::floor( $_[0] + 0.5 ) : POSIX::ceil( $_[0] - 0.5 );
}

sub quiet_sqrt {
	return $_[0] >= 0 ? sqrt ($_[0]) : 'NAN'
}

#====== STATISTICS FUNCTIONS ======

sub trmean {
    my $phis   = [ 0.1, 0.9 ];
    my ($l,$u) = &multi_quantiles($phis, [ sort { $a <=> $b }@_ ] );

    my $s = 0;
    my $c = 0;

    foreach (grep{ $_ > $l && $_ < $u } @_) {
	$s += $_;
	$c++;
    }
    return 'nan' unless $c;
    return ($s/$c);
}

sub multi_quantiles {
    my ($phis,$ref) = @_;
    return map { &quantile( $_, $ref ) }@{ $phis };
}

sub quantile {
    # returns a quantile from a sorted array
    return undef unless @{ $_[1] } > 1;

    my $index = $_[0] * $#{ $_[1] };
    my $lhs   = int($index);
    my $delta = $index - $lhs;

    return $delta ? ((1 - $delta) * $_[1]->[ $lhs ]) + ($delta * $_[1]->[ $lhs + 1 ]) : $_[1]->[ $lhs ];
   
}

sub stats_quick {
	# calculates statistics that only require a single pass
	# and has no requirement for sorted values
	return undef unless @_ >= 1;
	
	my $n = scalar @_;
	
	my $min    = inf;
	my $max    = -inf;
	my $nz_min = inf;
	my $sum    = 0;

	foreach (@_) {
		$min = $min < $_ ? $min : $_;
		$max = $max > $_ ? $max : $_;
		$sum += $_;

		next unless $_ > 0;
		$nz_min = $nz_min < $_ ? $nz_min : $_;
	}

	my $mean = $sum / $n;

	return ( { _n => $n, _min => $min, _nz_min => $nz_min, _max => $max, _sum => $sum, _mean => $mean } );
}

sub stats_lite {
	# calculates the same as quick stats but also calculates variance and standard deviation
	# requires two passes, as the mean value needs to be calculated first
	return undef unless @_ > 1;
	
	my $r        = &stats_quick(@_);
	my $mean     = $r->{'_mean'};
	my $n        = $r->{'_n'};

	my $variance = 0;
	my $stdev    = 0;
	my $avdev    = 0;
	
	foreach (@_) {
		my $d1 = $_ - $mean;
		my $d2 = $d1**2;

		$avdev    += abs($d1);
		$variance += $d2;
	}

	$variance /= ($n - 1);
	$avdev    /= $n;
	$stdev     = sqrt($variance);

	$r->{'_stdev'}    = $stdev;
	$r->{'_avdev'}    = $avdev;
	$r->{'_variance'} = $variance;

	return $r;
}

sub stats_full {
	return undef unless @_ > 1;
	
	my $r        = &stats_quick(@_);
	my $mean     = $r->{'_mean'};
	my $n        = $r->{'_n'};

	my $variance = 0;
	my $kurtosis = 0;
	my $skew     = 0;
	my $stdev    = 0;
	my $avdev    = 0;
	my $geomean;
	
	foreach (@_) {
		my $d1 = $_ - $mean;
		my $d2 = $d1*$d1;
		my $d3 = $d2*$d1;
		my $d4 = $d3*$d1;

		$avdev    += abs($d1);
		$variance += $d2;
		$skew     += $d3;
		$kurtosis += $d4;
		$geomean  += log ($_) if $r->{'_min'} > 0;
	}

	$variance  /= ($n - 1);
	$avdev     /= $n;
	$geomean   /= $n;
	$geomean    = exp($geomean);
	$stdev      = sqrt($variance);

	if ($variance) {
		$skew    /= ($n * $variance * $stdev);
		$kurtosis = $kurtosis / ($n * $variance * $variance) - 3.0;
	}

	my ($Q1, $Q2, $Q3) = &multi_quantiles( [ 0.25, 0.5, 0.75 ], [ sort { $a <=> $b }  @_ ] );

	$r->{'_Q1'}       = $Q1;
	$r->{'_median'}   = $Q2;
	$r->{'_Q3'}       = $Q3;
	$r->{'_IQR'}      = $Q3 - $Q1;
	$r->{'_stdev'}    = $stdev;
	$r->{'_avdev'}    = $avdev;
	$r->{'_variance'} = $variance;
	$r->{'_skew'}     = $skew;
	$r->{'_kurtosis'} = $kurtosis;
	$r->{'_geomean'}  = $geomean;

	return $r;
}

sub stats_robust {
 	return undef unless @_ >= 1;
	
	my $r       = &stats_full(@_);
	my $median  = $r->{'_median'};
	my @abs_dev = map { abs( $_ - $median) } @_;

	$r->{'_MAD'}      = &quantile( 0.5, [ sort { $a <=> $b } @abs_dev ]);
	$r->{'_trmean'}   = &trmean(@_);
        $r->{'_rstdev'}   = List::Util::min( $r->{'_IQR'} / 1.349, $r->{'_stdev'} );
                       
	return $r;
}

#====== NORMALIZATION FUCNTIONS =======

sub normalize_sum ($;$) {
	my $ref   = shift;
	my $sum   = defined $_[0] ? shift : List::Util::sum( derefify ( $ref ) );

	return if $sum == 0;
	foreach (@{ $ref }) { $$_ /= $sum };
}

sub normalize_zero_to_one ($;$) {
	my $ref        = shift;
	my $stats      = defined $_[0] ? $_[0] : &stats_quick( derefify ( $ref ) );
	my ($min,$max) = @{ $stats }{ qw/_min _max/ };
	my $range      = ($max - $min) || 0.5;

	my @data = ref($ref->[0]) eq 'SCALAR' ? @{ $ref } : map { \$_ } @{ $ref };

	foreach (@data) { $$_ -= $min; $$_ /= $range }
}

sub normalize_BoxCox ($;$$) {
	my $data_r   = shift;
	my $lambda1  = defined $_[0] ? $_[0] : 0;
	my $lambda2  = defined $_[1] ? $_[1] : &_calc_lambda2( derefify( $data_r ) );

	# check that data contains scalar references (so that data is transformed 'in place')
	# otherwise convert
	my @data    = ref($data_r->[0]) eq 'SCALAR' ? @{ $data_r } : map { \$_ } @{ $data_r };

	if (abs($lambda1) > epsilon) {
		foreach (@data) { $$_ += $lambda2; $$_**= $lambda1; $$_--; $$_ /= $lambda1  };
	} else {
		foreach (@data) { $$_ += $lambda2; $$_ = log $$_ };
	}
}

sub optimize_BoxCox_lambda {
	my $data_r  = shift;
	my $lmin    = shift;
	my $lmax    = shift;
	my $lambda2 = defined $_[0] ? shift : &_calc_lambda2( derefify( $data_r) );

	$lmin = -1 unless defined $lmin;
	$lmax =  1 unless defined $lmax;
        
	trace_error("Lmin <$lmin> must be smaller than Lmax <$lmax>") unless $lmin < $lmax;
	
	warn "Optimize BoxCox lambda: ($lmin, $lmax)\n";
	warn "\nlambda1\tlambda2\tLmax\n";
	warn "-------\t-------\t----\n";

	my $func = sub { my $lambda1 = shift; return &_BoxCox_lambda_likelihood( $data_r, $lambda1, $lambda2 ) };
	my $tau  = 1e-3;
	
	return golden_section_search( $func, $lmin, $lmax, $tau );
}

sub optimize_BoxCox_shift_parameter {
	my $data_r  = shift;
	my $lambda1 = shift;

	my $amin = abs( List::Util::min (derefify ($data_r) ) );
	my $amax = $amin + 2;
	my $acen = ($amin + $amax) * (2 - phi);

	my $func = sub { my $lambda2 = shift; return &BoxCox_lambda_likelihood( $data_r, $lambda1, $lambda2 ) };

	return golden_section_search( $func, $amin, $amax );
}

sub _BoxCox_lambda_likelihood {
	my $data_r     = shift; 
	my $lambda1    = shift;
	my $lambda2    = shift;
	my @vec        = derefify( $data_r );

	my $log_sum    = 0;
	
	foreach (@vec) {
		$log_sum += log ($_ + $lambda2);
	}

	&normalize_BoxCox( \@vec, $lambda1, $lambda2 );
	
	my $stat       = &stats_lite(@vec);
	my $N          = $stat->{'_n'};
	my $var        = $stat->{'_variance'};

	my $Lmax = -( ($N - 1)  / 2 ) * log( $var )  + ( $lambda1 - 1 ) * ( ($N - 1) / $N ) * $log_sum;
	
	printf STDERR ("%4.3f\t%4.3f\t%d\n", $lambda1, $lambda2, $Lmax );	
	
	return $Lmax;
}

sub _calc_lambda2 {
	my $s = &stats_quick(@_);
	
	return $s->{'_min'} > 0 ? 0 : 1 + abs( $s->{'_min'} );
}

#====== DATA STRUCTURES ======
sub derefify {
    # dereferences a data structure so that an array of references is returned
    # as an array of scalar values and an array reference is returned as an array.
    # If a normal array has been passed it is returned unchanged
    if (ref($_[0][0]) eq 'SCALAR') {
        my @a = map { $$_ } @{$_[0]};
        return @a;
    } elsif (ref($_[0]) eq 'ARRAY') {
        return @{$_[0]};
    } else {
        return @_;
    }
}

sub refify {
	
}

1;
