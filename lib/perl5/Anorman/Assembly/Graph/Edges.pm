package Anorman::Assembly::Graph::Edges;

use parent 'Anorman::Assembly::Graph';

my $FILTER = sub { return 1 };

sub new {
	my $class = shift;

	return bless( [], $class || ref $class );
}

sub connect {
	my $self  = shift;
	my $edge  = shift;
	my $nodes = shift;
	

	if (ref $edge eq 'HASH') {
		$self->_error("Need nodes passed if handed a hash instead of edge object") unless defined $nodes;
		$edge = Anorman::Assembly::Graph::Edge->new( $edge );
	} 
	
	$self->_error("Not a valid edge object") unless ref $edge eq 'Anorman::Assembly::Graph::Edge';

	return 0 unless ($nodes->get( $edge->node1) && $nodes->get( $edge->node2 ) );

	if ($FILTER->( $edge )) {
		$edge->_attach_nodes( $edge->nodes, $nodes );
		push @{ $self }, $edge;
		return 1;
	} else {
		undef $edge;
		return 0;
	}
}

sub size {
	my $self = shift;
	return scalar @{ $self };
}

sub filter {
	my $self = shift;
	
	if (defined $_[0]) { 
		if (ref $_[0] eq 'CODE') {
			$FILTER = shift;
		} elsif (ref $_[0] eq 'Anorman::Assembly::Graph::Edge') {
			return $FILTER->(@_);
		} else {
			$self->_error("Filter argument must be either be a CODE block or an Edge object");
		}
	} 

	return $FILTER;
}

sub get {
	my $self  = shift;
	my $index = shift;

	return $self->[ -1 ] unless defined $index;
	$self->_error("Index ($index) out of bounds. No such Edge exists") if $index > $self->size;
	
	return $self->[ $index ];
}

1;

package Anorman::Assembly::Graph::Edge;

use parent -norequire,'Anorman::Assembly::Graph';

sub new {
	my $class = shift;
	my $edge  = defined $_[0] ? shift : {};

	return bless( $edge, ref $class || $class );
}

sub node1 {
	my $self = shift;
	$self->{'node1'} = $_[0] if defined $_[0];
	return $self->{'node1'};	
}

sub node2 {
	my $self = shift;
	$self->{'node2'} = $_[0] if defined $_[0];
	return $self->{'node2'};
}

sub nodes {
	my $self = shift;
	return ($self->{'node1'}, $self->{'node2'});
}

sub connections {
	my $self = shift;
	return $self->{'connections'};	
}

sub type {
	my $self = shift;
	return $self->{'type'};
}

sub score {
	my $self = shift;
	return $self->{'score'};	
}

sub weight {
	my $self = shift;
	return $self->{'weight'};
}

sub ratio {
	my $self = shift;
	$self->{'ratio'} = $_[0] if defined $_[0];
	return $self->{'ratio'};
}

sub merge {

}

sub DESTROY {
	my $self  = shift;

	my $node1 = $self->node1;
	my $node2 = $self->node2;

	$node1->{'degree'}--;
	$node2->{'degree'}--;

	undef %{ $self };
}

sub _attach_nodes {
	my $self = shift;
	my ($node1, $node2, $nodes) = @_;

	# attach node1
	$node1 = $nodes->get( $self->node1 );

	$self->_error("Cannot connect: node1 is not a valid Node Object",1)
		unless ref $node1 eq 'Anorman::Assembly::Graph::Node';
	$node1->_attach_out_edge( $self );
	$self->node1( $node1 );
	
	# attach node 2
	$node2 = $nodes->get( $self->node2 );
	$self->_error("Cannot connect: node2 is not a valid Node Object",1)
		unless ref $node2 eq 'Anorman::Assembly::Graph::Node';

	$node2->_attach_in_edge( $self );
	$self->node2( $node2 );
}

1;

