package Anorman::Data::Hash;

# A class that adds isome OO syntactic-sugar to perl hashes

use strict;
use warnings;

use overload
	'""' => \&_stringify;

our $DELIMITER = ",";
our $SEPARATOR = "";
our $SPACER    = " ";

sub new { 
	my $class = shift;
	my %self  = ();

	tie (%self, 'Anorman::Data::Hash::Std');

	%self = @_;

	return bless ( \%self, $class );
}

sub get { 
	my ($self, $key) = @_;
	return undef unless defined $key;
	return $self->{ $key };
}

sub set {
	my ($self, $key, $value) = @_;
	$self->{ $key } = $value;
}

sub has {
	my ($self, $key) = @_;
	return exists $self->{ $key };
}

sub size {
	my $self = shift;
	return scalar keys %{ $self };
}

sub clear {
	my $self = shift;
	%{ $self } = ();
}

sub iterate {
	my $self = shift;
	return each %{ $self };
}

sub _stringify {
	my $self = shift;
	
	my $string =  "{" . $SEPARATOR . $SPACER . join ($DELIMITER . $SEPARATOR . $SPACER , map { "$_ -> $self->{$_}" } keys %{ $self }) . $SEPARATOR . "}";

	return $string;
}

1;

package Anorman::Data::Hash::Std;

use Tie::Hash;

our @ISA = 'Tie::StdHash';

1;
