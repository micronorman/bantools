package Anorman::Data::List;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Math::Algorithm qw(binary_search);

use overload
	'""'  => '_stringify';

our $DEFAULT_SIZE = 10;

sub new {
	my $class = shift;
	my $size  = shift;

	my @self  = ();

	if ($size) { 	
		tie (@self, 'Anorman::Data::List::Bounded' , $size);
	} else {
		tie (@self, 'Anorman::Data::List::Std');
	}

	return bless \@self, $class;
}

sub get {
	my ($self,$index) = @_;
	return $self->[ $index ];
}

sub set {
	my ($self,$index,$value) = @_;

	$self->[ $index ] = $value;
}

sub add {
	my $self = shift;
	push @{ $self }, @_;
}

sub size {
	my $self = shift;
	return scalar @{ $self } if !defined $_[0];

	$#{ $self } = $_[0] - 1;
}

sub sort {
	...
}

sub contains {
	my $self = shift;
	
	trace_error("No element defined\n\nusage: " . __PACKAGE__ . "::contains( element  )") unless defined $_[0];

	my $element = shift;

	foreach my $i( 0 .. $#{ $self } ) {
		return $i if $self->[$i] == $element;
	}

	return undef;
}

sub _stringify {
	my $self = shift;
	my $string = "{" . join (",", map { defined $_ ? $_ : 'nan' } @{ $self }) . "}"
}

1;

package Anorman::Data::List::Std;

use Anorman::Common;
use Tie::Array;

our @ISA = 'Tie::StdArray';


1;

package Anorman::Data::List::Bounded;

use Anorman::Common;
use Tie::Array;

sub TIEARRAY {
	my $class = shift;
	my $size  = defined $_[0] ? shift : $Anorman::Data::List::DEFAULT_SIZE;

	trace_error("Wrong number of arguments\n\nusage: tie(\@array, " . __PACKAGE__ . " , max_size)") if @_ || $size =~ /\D/;
	trace_error("Size must be greater than or equal to 1") if $size < 1;

	my $BOUND = $size - 1;

	return bless ( { 'DATA' => [], 'BOUND' => $BOUND }, $class );

}

sub FETCH {
	my ($self,$index) = @_;
	
	if ($index > $self->{'BOUND'}) {
		trace_error("List index is out of bounds: $index > $self->{'BOUND'}");
	}

	return $self->{'DATA'}->[ $index ];
}

sub FETCHSIZE {
	my $self = shift;
	return $self->{'BOUND'} + 1;
}

sub STORESIZE {
	my ($self,$newsize) = @_;

	return if $newsize == $self->{'BOUND'} + 1;

	if ($newsize <= $self->{'BOUND'}) {
		$#{ $self->{'DATA'} } = $newsize - 1;
	} 
		
	$self->{'BOUND'} = $newsize - 1;	
}

sub STORE {
	my ($self,$index, $value) = @_;

	if ($index > $self->{'BOUND'}) {
		trace_error("List index is out of bounds: $index > $self->{'BOUND'}");
	}

	$self->{'DATA'}->[ $index ] = $value;
}

sub EXTEND {
	my ($self, $newsize) = @_;

	my $maxsize = $self->{'BOUND'} + 1;

	return if $newsize == $maxsize;

	trace_error("Cannot extend list beyond boundary ($maxsize)") if $newsize > $maxsize;

	$#{ $self->{'DATA'} } = $newsize - 1;

}

sub CLEAR {
	my $self = shift;

	foreach (@{ $self->{'DATA'} }) {
		$_ = undef;
	}
}

sub PUSH {
	my $self = shift;

	# test whether new data pushes boundary
	my $toobig = ($#{ $self->{'DATA'} } + scalar @_ > $self->{'BOUND'});

	trace_error("Cannot push elements beyond list boundary (" . ($self->{'BOUND'} + 1) . ")" ) if $toobig;
	
	return push @{ $self->{'DATA'} }, @_;
}

sub DELETE {
	my $self  = shift;
	my $index = shift;

	trace_error("List index ($index) out of bounds ($self->{'BOUND'})") if $index > $self->{'BOUND'};
	$self->{'DATA'}->[ $index ] = undef;
}

sub SPLICE {
	warn "NO SPLICING YET!\n";
}

sub EXISTS {
	my $self = shift;
	return $_[0] <= $self->{'BOUND'};
}

sub DESTROY {
	my $self = shift;
	@{ $self->{'DATA'} } = ();

}

1;
