package Anorman::Assembly::Graph::Components;

use parent 'Anorman::Assembly::Graph';

# disable filtering by default
my $FILTER = sub { return 1 };
my $INDEX  = 0;

sub new {
	my $class = shift;
	my $graph = shift;
	my $self  = bless( [], $class || ref $class);

	return $self;
}

sub add {
	my $self = shift;
	my $comp = shift;

	if (ref $comp eq 'ARRAY') {
		$comp =  Anorman::Assembly::Graph::Component->new( $comp );
	} 

	if ($self->filter( $comp )) {
		foreach ( $comp->nodes ) {
			$_->member_of( $INDEX );
		}

		$INDEX++;

		push @{ $self }, $comp 	
	}

}

sub get {
	my $self  = shift;
	my $index = shift;

	$self->_error("Component $index does not exists") unless defined $self->[ $index ];
	return $self->[ $index ];
}

sub size {
	my $self = shift;
	return scalar @{ $self };
} 

sub filter {
	my $self   = shift;
	my $filter = shift;
	my $data   = shift;

	if (defined $filter) {
		if (ref ($filter) eq 'CODE') {
			$FILTER = $filter;
		} elsif (ref $filter eq 'Anorman::Assembly::Graph::Component') {
			return $FILTER->( $filter, $data );
		} else {
			$self->_error("Filter argument must be either be a CODE block or a Component object");
		}
	} 
	
	return $FILTER;
}

1;

package Anorman::Assembly::Graph::Component;

use parent -norequire,'Anorman::Assembly::Graph';
use strict;

sub new {
	my $class = shift;
	my $nodes = shift;

	return bless ($nodes, $class || ref $class);
}

sub nodes {
	my $self = shift;
	return @{ $self };
}

sub size {
	my $self = shift;
	return scalar @{ $self };
}

sub length {
	my $self = shift;
	my $length = 0;

	foreach my $node( $self->nodes ) {
		$length += $node->length;
	}

	return $length;
}

sub avg_coverage {
	my $self = shift;
	my $component_length = $self->length;

	my $coverage = 0;

	foreach my $node( $self->nodes ) {
		$coverage += ($node->coverage * ($node->length / $component_length));
	}
	
	return $coverage;
}

sub num_edges {
	my $self = shift;
	my $num_edges = 0;

	foreach my $node( $self->nodes ) {
		$num_edges += $node->edges_out;
	}

	return $num_edges;
}

sub edges {
	my $self = shift;
	return map { $_->edges_out } $self->nodes
}

sub traverse {
	# TODO: a function that traverses the component
}
1;
