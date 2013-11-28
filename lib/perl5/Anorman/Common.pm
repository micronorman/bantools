package Anorman::Common;

# commonly used routines such as error reporting 
use 5.012_00;

use strict;
use warnings;

use vars qw($VERSION);

$VERSION = 0.45;


use Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK);

@ISA = qw(Exporter);

BEGIN {
	use vars qw($DEBUG $VERBOSE);

	if ($Anorman::Common::DEBUG) {
		warn "Debug Mode: ON\n";
		$Anorman::Common::VERBOSE = 1;
	}

	@EXPORT    = qw(trace_error $VERBOSE $DEBUG);
	@EXPORT_OK = qw(
		trace_error
		call_stack
		sniff_scalar
		is_null
		check_hash_arg
		whoami
		whowasi
		usage
		$DEBUG
		$VERBOSE
	)

}

use vars qw($AN_TMP_DIR $AN_SRC_DIR);

$AN_TMP_DIR = exists $ENV{'AN_TMP'} ? $ENV{'AN_TMP'} : $ENV{'TMPDIR'};
$AN_SRC_DIR = exists $ENV{'AN_SRC'} ? $ENV{'AN_SRC'} : $ENV{'HOME'} . "/src/anorman";

use Scalar::Util qw(looks_like_number blessed reftype);

# SUBROUTINES #

sub trace_error {
	$DEBUG = 1;
        # Graceful fatal error messages with stack trace      
        my $err_msg     = shift;
	my $ext_status  = defined $_[0] ? shift : 1;
	my $err_string  = '';
	my @call_stack  = call_stack();
	my $last_call   = shift @call_stack;

	if ($VERBOSE || $DEBUG) {
		$err_string .= "\nModule $last_call->[0] caused a fatal error in line $last_call->[2]";
	} else {
		$err_string .= "\nFATAL ERROR";
	}
	
	if ($err_msg) {
		chomp $err_msg;
		$err_string .= ": " . $err_msg;
      	}
 
	if ($DEBUG) {
	
		$err_string .=  "\n\nStack Trace:";

		if (@call_stack) {
			foreach my $call(reverse @call_stack) {
				my ($cmd, $script, $line) = @{ $call }[3,1,2];
				$err_string .= "\n$cmd called by $script line $line";
			}
		} else {
			$err_string .= "stack empty";
		}
	}

	print STDERR "$err_string\n";

	exit $ext_status;
}

sub usage {
	
}

sub method_usage_string {
	my $call = caller(0);

	return $call->[0] . "::" . $call->[3] . "( " . join (", ", @_) . " )"; 
}

sub call_stack () {
	# establish a stack trace
        my @call_stack = ();
        my $i          = 0;

        while (my @c = caller( ++$i)) {
                push @call_stack, [ @c[ 0..4 ] ];
        }
        return @call_stack;
}

sub check_hash_args  {
	# check a hash for user arguments against a list (in the form of a hash) of allowed arguments
	# accepts two hash references
	my ($user,$allowed_args) = @_;

	trace_error("List of allowed arguments was empty") unless @{ $allowed_args };
	
	# Identify caller
	my $caller = (caller(2))[3];


	# Compile list of legal arguments
	my %args_map = map { $_ => 1 } @{ $allowed_args };


	# Check the user's list of arguments
	while (my ($arg, $v) = each %{ $user }) {
		trace_error("Illegal argument \'$arg\'. Function \'$caller\' only accepts the following arguments: " . join (",", keys %args_map) )
			unless exists $args_map{ $arg };
	}

	return 1;
}

sub sniff_scalar ($) {
	# identifies a scalar as either 'NUMBER', '(n)D_MATRIX' or 
	# returns the normal output of the native perl ref command
	# see http://perldoc.perl.org/functions/ref.html for info


	if (!ref $_[0]) {
		return looks_like_number($_[0]) ? 'NUMBER' : undef;
	}
	
	my $ref  = $_[0];
	my $type = ref $_[0];

	if ($type eq 'ARRAY') {

		if (defined $ref->[0] && ref $ref->[0] eq 'ARRAY') {
			my $dims = 1;

			while (defined (my $next = $ref->[0]) ) {
				last unless ref $next eq 'ARRAY';
				$dims++;
				$ref = $next;
			}

			return "${ dims }D_MATRIX"; 
		} else {
			return 'ARRAY';
		}
	} 

	return blessed $ref ? 'OBJECT' : $type;
}

sub is_null ($) {
	return 1 unless (defined (my $reftype = reftype($_[0]) ) );
	
	return !defined(${ $_[0] }) if ($reftype eq 'SCALAR');
	return !(%{ $_[0] }) if ($reftype eq 'HASH');
	return !(@{ $_[0] }) if ($reftype eq 'ARRAY');

}

sub whoami {
	my $whoami = (caller(1))[3];
	warn "$whoami\n";
}

sub whowasi {
	my $whowasi = (caller(2))[3];
	warn "$whowasi\n";
}

1;

