package Anorman::Math::Algorithm;

use strict;

use Scalar::Util qw(looks_like_number);
use Anorman::Common;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use Exporter;

$VERSION     = 0.4;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(	binary_search
			golden_section_search
			generic_permute
		);

use constant { TAU     => 1e-6,
	       PHI     => 1.6180339887498949,
               EPSILON => 2.22044604925031308e-16,
               RESPHI  => 0.381966011250105097
};

my %CACHE = ();

my $GRS_FUNC;
my $GRS_TAU;
my $GRS_ITER      =   0;
my $GRS_MAX_ITERS = 100;

sub binary_search ($$;$$&) {
	# NOTE: list MUST be sorted prior to binary search
	my ($array, $key, $from, $to, $cmp_func) = @_;

	trace_error("First argument must be an ARRAY reference") unless ref ($array) eq 'ARRAY';
	
	my ($low, $high);
	
	if (!defined $to) {
		$low  = 0;
		$high = $#{ $array };
	} else {
		$low  = $from;
		$high = $to;
	}

	if (!defined $cmp_func) {
		# default comparison
		$cmp_func = looks_like_number( $key ) ? 
			sub{ return $_[0] <=> $_[1] } : 
			sub{ return $_[0] cmp $_[1] };

	} elsif (ref $cmp_func ne 'CODE') {
		trace_error("Not a CODE reference");
	}

	while( $low <= $high ) {
		my $mid     = int ($low + (($high - $low) / 2) );
		my $mid_val = $array->[ $mid ];
		my $result   = $cmp_func->($mid_val, $key);
		
		# DEBUG : warn "MV: $mid_val KEY: $key FROM: $from TO: $to RESULT: $result\n";
 
		if ($result < 0) { 
			$low  = $mid + 1;
		} elsif ($result > 0) { 
			$high = $mid - 1;
		} else { 
			return $mid 
		}
	}

	# return negative index if key was not found
	# in this way, a close match ( > key )can be
	# picked from (-index -1) 
	return -($low + 1);
}

sub golden_section_search {

	trace_error("golden_section_search must be passed a CODE reference as its first argument") unless ref $_[0] eq 'CODE';

	$GRS_FUNC = shift;
	
	# initialize limits and midpoint
	my $min   = defined $_[0] ? $_[0] : -10;
	my $max   = defined $_[1] ? $_[1] : 10;
	my $mid   = $min + RESPHI * ($max - $min);
	
	# define tolerance 'tau' of the search
	$GRS_TAU  = defined $_[2] ? $_[2] : TAU;

	%CACHE    = ();
	$GRS_ITER = 0;
	
	return &_recursive_golden_section_search( $min, $mid, $max );
}

sub _recursive_golden_section_search {

	# recursive part of the golden section search
	my $l_delta = ($_[1] - $_[0]);
	my $r_delta = ($_[2] - $_[1]);

	# termination condition #1
	if (++$GRS_ITER >= $GRS_MAX_ITERS) {
		return ($_[2] + $_[0]) / 2;
	}
	
	# calculate new probe point
	my $x4 = ($r_delta > $l_delta) ? 
		$_[1] + RESPHI * $r_delta :
                $_[1] - RESPHI * $l_delta;
	
	my $x_delta = abs($_[2] - $_[0]);


	# termination condition #2
	if ( $x_delta < $GRS_TAU * ( abs($_[1]) + abs($x4) ) ) {
		return ($_[2] + $_[0]) / 2;
	} 

	my $f_x2;
	my $f_x4 = $GRS_FUNC->( $x4 );

	$CACHE{ $x4 } = $f_x4;
	
	# check whether results have been cached, otherwise calculate
	if (exists $CACHE{ $_[1] }) {
		$f_x2 = $CACHE{ $_[1] };
	} else {
		$f_x2 = $GRS_FUNC->( $_[1] );
		$CACHE{ $_[1] } = $f_x2;
	}
	
	my $f_delta = abs($f_x4 - $f_x2);

	# termination condition #3
	if (EPSILON > $f_delta) {
		return ($_[2] + $_[0]) / 2;
	}

 	warn "ITER: $GRS_ITER f($_[2]) = $f_x2 f($x4) = $f_x4 f_delta: $f_delta x_delta: $x_delta\n";
	
	return ($f_x4 > $f_x2) ?
		($r_delta > $l_delta) ?
			&_recursive_golden_section_search( $_[1],   $x4, $_[2] )
			:
			&_recursive_golden_section_search( $_[0],   $x4, $_[1] )  
		:
		($r_delta > $l_delta) ?
			&_recursive_golden_section_search( $_[0], $_[1], $x4   )
			:
			&_recursive_golden_section_search( $x4  , $_[1], $_[2] );
}

sub generic_permute {
	my ($indexes, $swapper) = @_;

	trace_error("Second argument must be a CODE reference") unless ref $swapper eq 'CODE';
	
	my $size    = @{ $indexes };
	my @tracks  = (0 .. $size - 1);
	my @pos     = @tracks;

	my $i = -1;
	while ( ++$i < $size ) {
		my $index = $indexes->[ $i ];
		my $track = $tracks[ $index ];

		if ($i != $track) {
			$swapper->($i, $track);
			$tracks[ $index ]   = $i;
			$tracks[ $pos[$i] ] = $track;

			($pos[ $i ], $pos[ $track ]) = ($pos[ $track ],$pos[ $i ]);
		}	
	}
}

1;
