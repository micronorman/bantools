package Anorman::Math::UnionFind;

use strict;

use constant { 
	PARENT => 0,
	RANK   => 1
};

sub new {
	my $class = shift;
	return bless ( {} , ref ($class) || $class );
}

# add a new element to the Union-Find data structure
sub add {
	my $self    = shift;
	my $element = shift;

	$self->{ $element } = [ $element, 0 ] unless defined $self->{ $element };
}

# check if element has already been added to Union-Find
sub has {
	my $self    = shift;
	my $element = shift;

	return exists $self->{ $element };
}

# returns the parent of the element, if any 
sub _parent {
	my $self    = shift;
	my ($element, $parent) = @_;

	return undef unless defined $element;

	if (defined $parent) {
		$self->{ $element }->[ PARENT ] = $parent;
	} else {
		return $self->has( $element ) ? $self->{ $element }->[ PARENT ] : undef;
	}
}

sub _rank {
	my $self = shift;
	my ($element, $rank) = @_;

	return undef unless defined $element;

	if (defined $rank) {
		$self->{ $element }->[ RANK ] = $rank;
	} else {
		return $self->has( $element ) ? $self->{ $element }->[ RANK ] : undef;
	}
}

# Find root element of a stack
sub find {
	my $self = shift;
	my $x    = shift;

	my $parent = $self->_parent( $x );

	return unless defined $parent;

	$self->_parent( $x, $self->find( $parent ) ) if $parent ne $x;
	return $self->_parent( $x );
}

# merge two sets;
sub union {
	my $self = shift;
	my ($x, $y) = @_;

	# check if elements are aready in set
	$self->add( $x ) unless $self->has( $x );
	$self->add( $y ) unless $self->has( $y );

	# locate roots of both elements
	my $root_x = $self->find( $x );
	my $root_y = $self->find( $y );

	# quit if already in same component
	return if $root_x eq $root_y;

	# determine the rank of both elements
	my $rank_x = $self->_rank( $root_x );
	my $rank_y = $self->_rank( $root_y );

	# merge x and y if they are not in the same set
	if ( $rank_x > $rank_y ) {
		$self->_parent( $root_y, $root_x );
	} elsif ( $rank_y < $rank_x )  {
		$self->_parent( $root_x, $root_y );
	} else {
		$self->_parent( $root_y, $root_x );
		$self->_rank( $root_y, $rank_x + 1 );	
	}
}

# determine whether two elements are part of the same set
sub same {
	my $self    = shift;
	my ($u, $v) = @_; 

	my $root_u = $self->find( $u );

	return undef unless defined $root_u;

	my $root_v = $self->find( $v );

	return undef unless defined $root_v;

	return ($root_u eq $root_u); 	
}

1;
