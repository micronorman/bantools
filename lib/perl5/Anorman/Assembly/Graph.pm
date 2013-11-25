package Anorman::Assembly::Graph;

use strict;

use Anorman::Common qw(trace_error);
use Anorman::Common::Iterator;

use Anorman::Assembly::Graph::Nodes;
use Anorman::Assembly::Graph::Edges;
use Anorman::Assembly::Graph::Components;
use Anorman::Math::UnionFind;

our $DEBUG = 1;

sub new {
	warn "Initializing Object\n" if $DEBUG;

	my $class = shift;
	my $self  = bless ( { @_ }, $class );
	
	$self->{'_NODES'} 	= Anorman::Assembly::Graph::Nodes->new;
	$self->{'_EDGES'} 	= Anorman::Assembly::Graph::Edges->new;
	$self->{'_UNION'} 	= Anorman::Math::UnionFind->new;
	$self->{'_COMPONENTS'} 	= Anorman::Assembly::Graph::Components->new;	
	
	return $self;
}

sub edges {
	my $self = shift;
	
	return wantarray ? @{ $self->{'_EDGES'} } : $self->{'_EDGES'};
}

sub nodes {
	my $self = shift;
	return $self->{'_NODES'};
}

sub components {
	my $self = shift;
	return wantarray ? @{ $self->{'_COMPONENTS'} } : $self->{'_COMPONENTS'};
}

sub unionfind {
	my $self = shift;
	return $self->{'_UNION'};
}

sub edge_file {

}

sub node_file {

}

sub seqid2index {
	my $self  = shift;
	my $seqid = shift;

	return undef unless exists $self->{'_seqid_cache'}->{ $seqid };
	return $self->{'_seqid_cache'}->{ $seqid };
}

sub init {
	my $self = shift;
	my $iter = Anorman::Common::Iterator->new( 'IG' => qr/^[#\n]/ );

	(exists $self->{'node_file'} or $self->_error("No nodes file specified"));
	(exists $self->{'edge_file'} or $self->_error("No edges file specified"));
	
	my $counter = 0;
	
	warn "Adding nodes...\n" if $DEBUG;
	$iter->open( $self->{'node_file'} );

		$iter->NEXT;
		$counter++;

		my @node_fields = qw/name seqid length coverage degree/;
		while ($iter->MORE) {
			$self->nodes->add( $iter->HASH(@node_fields) );
			$iter->NEXT;
			$counter++;
		}

	$iter->close;
	$self->_cache_seqids;

	print $self->nodes->size, " nodes (out of $counter)\n";
	
	warn "Adding edges...\n" if $DEBUG;
	$iter->open( $self->{'edge_file'} );

		$iter->NEXT;

		my @edge_fields = qw/node1 node2 type connections ratio score/;

		while ($iter->MORE) {
			my $edge = Anorman::Assembly::Graph::Edge->new( $iter->HASH(@edge_fields), $self->nodes );
			my $connected = $self->edges->connect( $edge, $self->nodes );

			if ($connected) {
				my $key1 = $edge->node1->name;
				my $key2 = $edge->node2->name;
				
				$self->unionfind->union( $key1, $key2 );
			}
			$iter->NEXT;
		}

	$iter->close;

	print $self->edges->size, " edges\n";
	
	warn "Construct connected components\n";
	$self->_make_components;

	warn $self->components->size, " components created\n";
}

sub _make_components {
	my $self = shift;
	
	my %disjoint_sets = ();
	my @orphans = ();

	while (my ($key, $node) = $self->nodes->iterate) {
			if ( $self->unionfind->has( $key ) ) {
				my $set = $self->unionfind->find( $key );
				push @{ $disjoint_sets{ $set } }, $key;
			} else {
				push @orphans, $node;
			}	
	}

	# create connected components in descending order of size
	foreach my $set( sort { @{ $b } <=> @{ $a } } values %disjoint_sets ){
		my @cc = map { $self->nodes->get( $_ ) } @{ $set };
	
		$self->components->add( \@cc );
	}

	warn scalar @orphans, " orphan nodes\n";
}

sub _cache_seqids {
	my $self = shift;
	my %index = ();

	while (my ($key, $node) =  $self->nodes->iterate ) {
		$index{ $node->seqid } = $key;
	}

	$self->{'_seqid_cache'} = \%index;	
}

sub _error {
	shift;
	trace_error( @_ );
}

1;
