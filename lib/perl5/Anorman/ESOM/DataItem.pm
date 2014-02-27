package Anorman::ESOM::DataItem;

use strict;
use warnings;

use Anorman::Common;

use overload
	'""' => \&_stringify;

our $DELIM = "\t";

sub new {
	my $class = shift;

	trace_error("Wrong number of arguments\n" . $class->_usage ) unless @_ == 1;

	my $index = shift;
	my $self  = [ $index ];

	return bless ( $self, ref $class || $class );
}

sub index {
	my $self = shift;

	return $self->[0] unless defined $_[0];

	$self->[0] = $_[0];
}

sub _stringify {
	my $self = shift;

	return join ($Anorman::ESOM::DataItem::DELIM, @{ $self });
}

sub _usage {
	my $self = shift;

	return "\nUsage:\n" . __PACKAGE__ . "::new( index )\n";
}

1;

package Anorman::ESOM::DataItem::BestMatch;

use strict;
use warnings;

use Anorman::Common;

use parent -norequire,'Anorman::ESOM::DataItem';

sub new {
	my $class = shift;
	my ($index,$row,$column, $distance)   = @_;

	my $self = $class->SUPER::new( $index );
	
	$self->[1] = $row;      # BestMatch Row
	$self->[2] = $column;   # BestMarch Column
	$self->[3] = $distance; # Arbitrary distance to bestmatch neuron

	return $self;
}

sub row {
	# Retreive or set row value
	return $_[0]->[1] unless defined $_[1];
	$_[0]->[1] = $_[1];
}

sub column {
	# Retrieve or set column value
	return $_[0]->[2] unless defined $_[1];
	$_[0]->[2] = $_[1];
}

sub distance {
	# Retrieve or set distance value
	return $_[0]->[3] unless defined $_[1];
	$_[0]->[3] = $_[1];
}

1;

package Anorman::ESOM::DataItem::Class;

use strict;
use warnings;

use parent -norequire,'Anorman::ESOM::DataItem';

use Anorman::Math::Set;

use Anorman::Common;
use overload 
	'""' => \&_stringify,
	'==' => \&_equals;

sub new {
	my $class = shift;

	my ($index,$name,$color) = @_;

	my $self = $class->SUPER::new($index);

	$self->name( $name );
	$self->color( $color );

	tie (my @members, 'Anorman::Math::Set');
	$self->members( \@members );

	return $self;
}

sub name {
	my $self = shift;
	return $self->[1] unless defined $_[0];
	$self->[1] = $_[0];
}

sub color {
	my $self = shift;
	return wantarray ? @{ $self->[2] } : $self->[2] unless defined $_[0];

	$self->[2] = $_[0];
}

sub members {
	my $self = shift;
	return wantarray ? @{ $self->[3] } : $self->[3] unless defined $_[0];

	$self->[3] = $_[0];
}

sub clear {
	@{ $_[0]->[3] } = ();
}

sub size {
	my $self = shift;
	return scalar @{ $self->[3] };
}

sub add_members {
	my $self = shift;
	return push @{ $self->[3] }, @_;
}

sub delete_members {
	my $self = shift;
	return delete @{ $self->[3] }[@_];
}

sub _stringify {
	my $self = shift;

	trace_error("NO");
	return join ($Anorman::ESOM::DataItem::DELIM, $self->[0], $self->[1], @{ $self->[2] });
}

sub _equals {
	my ($self,$other) = @_;

	return undef if !($self->index == $other->index);
	return undef if !($self->name  eq $other->name);
	return undef if !($self->color == $other->color);

	1; 
}

1;

package Anorman::ESOM::DataItem::KeyName;

use parent -norequire, 'Anorman::ESOM::DataItem';

use Anorman::Common;

sub new {
	my $class = shift;
	my ($index, $name, $description) = @_;
	
	my $self = $class->SUPER::new($index);

	trace_error("Wrong number of arguments\n" . $self->_usage ) unless (@_ == 2 || @_ == 3);

	$self->name($name);
	$self->description($description);
	
	return $self;
}

sub name {
	return $_[0]->[1] unless defined $_[1];

	$_[0]->[1] = $_[1];
}

sub description {
	return $_[0]->[2] unless defined $_[1];

	$_[0]->[2] = $_[1];
}

sub _usage {
	my $self = shift;

	my $usage = $self->SUPER::_usage();

	$usage .= __PACKAGE__ . "::new( index, name, description )\n";

	return $usage;
}

1;

