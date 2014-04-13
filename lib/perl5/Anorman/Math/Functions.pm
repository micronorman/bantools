package Anorman::Math::Functions;

my %UNARY_FUNCTIONS = (
	'identity'	=> sub { $_[0] },
	'abs'		=> sub { abs($_[0]) },
	'square'	=> sub { $_[0] * $_[0] },
	'sqrt'		=> sub { sqrt $_[0] },
	'quiet_sqrt'	=> sub { $_[0] >=0 ? sqrt($_[0]) : 'NAN' },
	
);

my %BINARY_FUNCTIONS = ( 
	'plus'		=> sub { $_[0] + $_[1] },
	'minus'		=> sub { $_[0] - $_[1] },
	'mult'		=> sub { $_[0] * $_[1] },
	'div'		=> sub { $_[0] / $_[1] },
	'min'		=> sub { $_[0] < $_[1] ? $_[0] : $_[1] },
	'max'		=> sub { $_[0] > $_[1] ? $_[0] : $_[1] },
	'equals'	=> sub { $_[0] == $_[1] ? 1 : 0 },
	'cmp'		=> sub { $_[0] <=> $_[1] },
	'pow'		=> sub { $_[0] ** $_[1] }
);

# Set up function aliases

# Unary functions
while (my ($k,$v) = each %UNARY_FUNCTIONS) {
	*$k = sub { return $v };
}

# Binary functions. If provided an argument this binds
# it to the second argument of the function
while (my ($k,$v) = each %BINARY_FUNCTIONS) {
	*$k = sub { 
		    if (defined $_[1]) {
                      my $arg2 = $_[1]; 
                      
                      return sub { $v->( $_[0], $arg2 ) }
                    } else { return $v }};
}

sub randint { my $max = $_[1]; return sub { int( rand($max) ) } }

sub new {
	my $class = ref $_[0] || $_[0];
	my $self  = {};

	return bless ( $self, $class );
}

sub plusmult { 
	my $self = shift;

	# Returns function x = A + MULT * B
	my $MULT = shift; 
	
	if ($MULT == 0) {
		return &identity;
	} elsif ($MULT == -1) {
		return &minus;
	} elsif ($MULT == 1) {
		return &plus;	
	} else {
		return sub { $_[0] + $MULT * $_[1] }
	}
}

sub bind_arg1 {
	my $self     = shift;
	my $function = shift;

	trace_error("Not a CODE block") if (ref $function ne 'CODE');

	my $c = shift;

	return sub { $function->( $c, $_[0] ) } 
}

sub bind_arg2 {
	my $self     = shift;
	my $function = shift;

	trace_error("Not a CODE block") if (ref $function ne 'CODE');

	my $c = shift;

	return sub { $function->( $_[0], $c ) } 
}


sub chain {
	my $self  = shift;
	my @chain = @_;

	if (@chain == 2) {
		return sub { $chain[0]->( $chain[1]->(@_) ) };
	} elsif (@chain == 3) {
		return sub { $chain[0]->( $chain[1]->($_[0]), $chain[2]->($_[1]) ) }
	} else {
		trace_error("Wrong number of arguments");
	}
}

1;
