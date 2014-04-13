#!/usr/bin/env perl

use strict;
use warnings;

use Anorman::Data;
use Anorman::Math::VectorFunctions;

my $rand = sub{ rand(5) };
my $v1 = Anorman::Data->vector(10)->assign( $rand );
my $v2 = $v1->like->assign( $rand );

print "a: $v1\nb: $v2\n\n";

my $VF = Anorman::Math::VectorFunctions->new;

my @funcs = @Anorman::Math::VectorFunctions::DISTANCE_FUNCTIONS;

my $max_length = 0;

do { my $len = length($_); $max_length = $len > $max_length ? $len : $max_length } for @funcs ;
foreach my $func(@funcs) {
	my $padding = 1 + ($max_length - length($func));
	print ucfirst(lc($func)) . ' ' x $padding . ":" . sprintf("%g", $VF->$func->($v1,$v2)) . "\n";
}

