package Anorman::ESOM::Class;
# Class for ESOM-classes as used in the Databionics ESOM-program

use strict;
use warnings;

use Anorman::Common;
use Anorman::Math::Algorithm qw(binary_search);

sub new {
	my $class = shift;
	my %opt   = @_;

	my $self = { 'number'  => 0,
		     'name'    => 'NO_CLASS',
		     'color'   => [255,255,255],
		     'members' => []
		  };

	while (my ($k,$v) = each %opt) {
		trace_error("Unknown option \'$k\'") unless exists $self->{ $k };
	}

	$self = bless ( $self, ref $class || $class );
	
	$self->color( $opt{'color'} ) if exists $opt{'color'};
	$self->name( $opt{'name'} ) if exists $opt{'name'};
	$self->number( $opt{'number'} )if exists $opt{'number'};
	$self->members( $opt{'members'}) if exists $opt{'members'};
	
	return $self;
}

sub name {
	return $_[0]->{'name'} if (!defined $_[1]);
	
	my $self = shift;
	$self->{'name'} = $_[0];
}

sub number {
	return $_[0]->{'number'} if (!defined $_[1]);

	my $self = shift;
	$self->{'number'} = $_[0];
}

sub members {
	return wantarray ? @{ $_[0]->{'members'} } : $_[0]->{'members'} if (!defined $_[1]);

	my $self = shift;
	
	trace_error("Argument Error: List of new Class members must be passed as an array reference")
		unless ref $_[0] eq 'ARRAY';

	if (@{ $_[0] } > 1) {
		# make sure members are a sorted list
		my $members = [ sort { $a <=> $b } @{ $_[0] } ];
		trace_error("STOP");
		$self->{'members'} = $members;  
	}
}

sub size {
	my $self = shift;
	return scalar @{ $self->{'members'} };
}

sub clear {
	my $self = shift;
	@{ $self->{'members'} } = ();
}

sub color {
	return wantarray ? @{ $_[0]->{'color'} } : $_[0]->{'color'} if (!defined $_[1]);

	my $self = shift;

	trace_error("Color definition must be an array reference containing exactly three values (red,green,blue)")
		unless (ref $_[0] eq 'ARRAY' && @{ $_[0] } == 3);
	$self->{'color'} = $_[0];
}

sub add_member {
	my ($self, $key) = @_;
	trace_error("No key specified") if !defined $key;
	
	my $index = binary_search( $self->{'members'}, $key );

	return $index if $index >= 0;

	my $insert_idx = -$index - 1;
	splice @{ $self->{'members'} }, $insert_idx, 0, $key;
	return $insert_idx; 
}

sub delete_member {
	my ($self, $key) = @_;
	trace_error("No key specified") if !defined $key;

	my $index = binary_search( $self->{'members'}, $key );

	return undef if $index < 0;

	splice @{ $self->{'members'} }, $index, 1;
	return 1;
}

1;

