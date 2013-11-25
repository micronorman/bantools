package Anorman::Assembly::Graph::Nodes;

use parent 'Anorman::Assembly::Graph';

# pass-all filter
my $FILTER = sub { return 1 };

sub new {
	my $class = shift;
	
	return bless ( {}, $class || ref $class );
}

sub get {
	my $self = shift;
	my $node = shift;

	return undef unless exists $self->{ $node };
	return $self->{ $node }; 
}

sub add {
	my $self = shift;
	my $node = shift;

	if (ref $node eq 'HASH') {
		$node = Anorman::Assembly::Graph::Node->new( $node );
	}

	$self->_error("Not a valid Node object") unless ref $node eq 'Anorman::Assembly::Graph::Node';

	if ($self->filter( $node )) {
		$node->degree( 0 );
		$self->{ $node->name } = $node;
		return 1;
	}
}

sub size {
	my $self = shift;
	return scalar keys %{ $self };
}

sub remove {
	my $self = shift;
	my $node = shift;
	$self->{ $node }->DESTROY;
	delete $self->{ $node };
}

sub filter {
	my $self   = shift;
	my $filter = shift;
	my $data   = shift;

	if (defined $filter) { 
		if (ref $filter eq 'CODE') {
			$FILTER = $filter;
		} elsif (ref $filter eq 'Anorman::Assembly::Graph::Node') {
			return $FILTER->( $filter, $data );
		} else {
			$self->_error("Filter argument must be either be a CODE block or a Node object");
		}
	} 

	return $FILTER;
}

sub iterate {
	my $self = shift;
	return each %{ $self };
}

sub list {
	my $self = shift;
	return map { $self->get( $_ ) } sort { $a <=> $b } keys %{ $self };
}

1;

package Anorman::Assembly::Graph::Node;

use parent -norequire,'Anorman::Assembly::Graph';

sub new {
	my $class = shift;
	my $node  = defined $_[0] ? shift : {};

	return bless( $node, ref $class || $class );	
}

sub name {
	my $self = shift;
	$self->{'name'} = shift if defined $_[0];
	return $self->{'name'};
}

sub seqid {
	my $self = shift;
	$self->{'seqid'} = shift if defined $_[0];
	return $self->{'seqid'};
}

sub coverage {
	my $self = shift;
	$self->{'coverage'} = shift if defined $_[0];
	return $self->{'coverage'};
}

sub degree {
	my $self = shift;
	$self->{'degree'} = shift if defined $_[0];
	return $self->{'degree'};
}

sub length {
	my $self = shift;
	$self->{'seqid'} = shift if defined $_[0];
	return $self->{'length'};
}

sub edges_in {
	my $self = shift;
	return @{ $self->{'_EDGES_IN'} };
}

sub edges_out {
	my $self = shift;
	return @{ $self->{'_EDGES_OUT'} };
}

sub member_of {
	my $self      = shift;
	$self->{'member_of'} = shift if defined $_[0];
	return $self->{'member_of'};
}

sub merge {

}

sub neighbors {
	my $self = shift;
	
	my @neighbors = ();
	foreach my $edge( $self->edges_out ) {
		push @neighbors, $edge->node2->name;
	}
	
	foreach my $edge( $self->edges_in ) {
		push @neighbors, $edge->node1->name;
	}
	
	return @neighbors;
}

sub _attach_in_edge {
	my $self = shift;
	my $edge = shift;

	$self->_error("Not a valid edge object") unless ref $edge eq 'Anorman::Assembly::Graph::Edge';

	push @{ $self->{'_EDGES_IN'} }, $edge;

	$self->{'degree'}++;
}

sub _attach_out_edge {
	my $self = shift;
	my $edge = shift;

	$self->_error("Not a valid edge object") unless ref $edge eq 'Anorman::Assembly::Graph::Edge';

	push @{ $self->{'_EDGES_OUT'} }, $edge;

	$self->{'degree'}++;
}

1;
