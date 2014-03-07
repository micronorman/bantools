package Anorman::Common::Iterator;

# Iterator class for parsing text files that are
# read line-by-line

use strict;
use Anorman::Common;

BEGIN {
	require 5.12.0;
}

our $LIMITISFATAL = 0;

sub DESTROY {
	my $self = shift;

	$self->close;	
}

sub new {
	my $class    = shift;
	my %args     = @_;

	my $self     = { '_FH' => \*STDIN,     # filehande
			 '_I'  => 0,           # index counter
			 'FS'  => qr/\t/,      # field separator
			 'IG'  => qr/^\n/,     # ignore lines matching this regex
			 'HDR' => qr/^#\s?/,   # header marker
			 'RS'  => $/           # record separator
		       };
	if (%args) {
		@{ $self }{ keys %args } = values %args;
	}
	
	bless ($self, ref($class) || $class);
	return $self;
}

sub open {
	my $self = shift;
	my $fn   = shift;

	return unless $fn gt '';

	open (my $FH, '<', $fn) or $self->_error("Could not initialize filehandle for $fn. $!");

	$self->{'_FH'} = $FH;

	return 1;
}

sub close {
	my $self = shift;
	my $FH   = $self->{'_FH'};

	close $FH unless $FH eq \*STDIN;
	$self->FLUSH;
	$self->{'_FH'} = '';
}

sub INDEX {
	my $self = shift;
	return $self->{'_I'};
}

sub NEXT {
	my $self    = shift;
	my $FH      = $self->{'_FH'};
	my $ignore  = $self->{'IG'};
	local $/    = $self->{'RS'};

	$self->FLUSH;

	if (defined $self->{'_LIMIT'} && $self->{'_I'} > $self->{'_LIMIT'}) {
		warn "Line Iterator exceeded the limit (" . $self->{'_LIMIT'} . ")";
		exit 1 if $LIMITISFATAL;
		return;
	}

	while (defined (my $cache = <$FH>)) {
		next if $cache =~ m/$ignore/;
		chomp $cache;
		
		$self->{'_CACHE'} = $cache;
		last;
	}
	$self->{'_I'}++;
}

sub MORE { 
	my $self = shift;
	return '' ne $self->{'_CACHE'};
}

sub REGEX {
	my $self    = shift;
	my $pattern = shift;

	my @matches = $self->{'_CACHE'} =~ m/$pattern/g;

	if (@matches) {
		$self->{'_MATCH'} = [ @matches ];
		return 1;
	}
}

sub MATCH {
	my $self   = shift;

	return undef unless defined $self->{'_MATCH'};
	return wantarray ? @{ $self->{'_MATCH'} } : $self->{'_MATCH'};
}

sub STRING {
	my $self = shift;
	return $self->{'_CACHE'} if $self->{'_CACHE'} ne '';
}

sub ARRAY {
	my $self    = shift;
	my $pattern = defined $_[0] ? shift : $self->{'FS'};
	my $a       = [ split $pattern, $self->{'_CACHE'} ];

	return undef unless scalar @{ $a };
	return wantarray ? @{ $a } : $a;
}

sub HASH {
	my $self    = shift;

	$self->_error("No defined HASH keys") unless @_;
	
	my $h = {};
	@{ $h }{ @_ } = split $self->{'FS'}, $self->{'_CACHE'};

	return $h;
}

sub HEADER {
	my $self    = shift;
	my $pattern = $self->{'HDR'};
	my $FH      = $self->{'_FH'};
	my $ignore  = $self->{'IG'};

	my @header = ();

	while (defined (my $cache = <$FH>)) {
		next if $cache =~ m/$ignore/;
		chomp $cache;
		
		if ($cache =~ s/$pattern//) {
			push @header, $cache;
		} else {
			$self->{'_CACHE'} = $cache;
			last;
		}
	}
	return wantarray ? @header : \@header;
	
}

sub CALLBACK {
	my $self     = shift;
	my $callback = shift;
	my $data     = shift;;

	if (ref($callback) ne 'CODE') { 
		$self->_error("Invalid callback. Must be a CODE reference"); 
	}

	my $result = $callback->( $self, $data );

	return $result;
}

sub COUNTER {
	my $self = shift;
	return $self->{'_I'};
}

sub LIMIT {
	my $self = shift;
	return $self->{'_LIMIT'} unless defined $_[0];
	
	$self->{'_LIMIT'} = shift;
}
sub FLUSH {
	my $self = shift;
	$self->{'_CACHE'} = '';
	$self->{'_MATCH'} = undef;
}

sub _error {
	my $self = shift;
	trace_error(@_);
}

1;
