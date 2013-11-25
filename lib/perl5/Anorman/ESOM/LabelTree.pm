package Anorman::ESOM::LabelTree;

use warnings;
use strict;

use Anorman::Common;

sub new {
	my $class     = shift;
	my $threshold = defined $_[0] ? shift : 0;

	my $self      = { 'threshold' => $threshold,
			  'top_label' => ($threshold - 1),
			  'labels'    => []
                        };

	bless $self, $class;

	return $self;
}

sub merge {
	my $self   = shift;
	
	if (@_ == 2) {
		my ($a, $b) = @_;
		
		$self->{'top_label'}++;

		my $i = 2 * ( $self->{'top_label'} - $self->{'threshold'} );

		$self->{'labels'}->[ $i ]     = $a;
		$self->{'labels'}->[ $i + 1 ] = $b;

		return $self->{'top_label'};
	} elsif (@_ > 2) {
		my @labels = @_;
		my $l1     = shift @labels;
		
		while (defined (my $l2 = shift @labels)) {
			$l1 = $self->merge($l1, $l2);
		}
		
		return $l1; 
	}
}

sub is_leaf {
	# checks whether node is a leaf
	my $self = shift;
	my $n    = shift;

	warn "I'm being passed bullshit ($n)\n" unless defined $n;

	return ($n < $self->{'threshold'});
}

sub leaf_value {
	my $self = shift;
	my $n    = shift;

	trace_error("Node is $n not a leaf") if !$self->is_leaf($n);

	return $n;
}

sub left {
	my $self = shift;
	my $n    = shift;

	trace_error("Assertion failure") if $self->is_leaf($n);
	
	my $i = $n - $self->{'threshold'};

	return $self->{'labels'}->[ 2 * $i ];
}

sub right {
	my $self = shift;
	my $n    = shift;

	trace_error("Assertion failure") if $self->is_leaf($n);
	
	my $i = 2 * ( $n - $self->{'threshold'} );

	return $self->{'labels'}->[ $i + 1 ];
}

sub top {
	my $self = shift;
	return $self->{'top_label'};
}

sub members {
	# find all members of tree from node n down
	my $self = shift;
	my $n    = shift;

	return () if $self->is_leaf( $n );
	
	my @queue   = ($n);
	my @members = ();

	while (defined (my $i = shift @queue)) {

		my $l = $self->left( $i );
		my $r = $self->right( $i );

		if ( !$self->is_leaf( $l ) ) {
			push @queue, $l;
		} else {
			push @members, $self->leaf_value( $l );
		}

		if ( !$self->is_leaf( $r ) ) {
			push @queue, $r;
		} else {
			push @members, $self->leaf_value( $r );
		}
	}


	return @members;
}

sub size {
	my $self = shift;
	return ($self->{'top_label'} - $self->{'threshold'} + 1);
}

1;
