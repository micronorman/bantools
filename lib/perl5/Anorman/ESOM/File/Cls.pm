package Anorman::ESOM::File::Cls;

use strict;
use warnings;

use parent 'Anorman::ESOM::File::Map';

use Anorman::Common;

sub new {
	my $class = shift;

	my $filename = shift;
	my $self     = $class->SUPER::new( $filename );

	$self->{'keys'}    = Anorman::Data::List->new;
	$self->{'classes'} = Anorman::ESOM::ClassTable->new();

	return $self;
}

sub add_class {

}


sub classes {
	my $self = shift;
	
	return $self->{'classes'} unless defined $_[0];

	$self->{'classes'} = shift;
	$self->{'_indexed'} = undef;
}

sub add {
	my $self = shift;
	my ($index, $cls) = @_;

	return unless defined $cls;

	unless (exists $self->{'map'}->{ $index }) {
		$self->{'keys'}->add( $index );
		$self->{'data'}->add( $cls );
		$self->{'map'}->set( $index, $self->{'keys'}->size - 1);
	} else {
		$self->{'data'}->set( $self->{'map'}->get( $index ), $cls );
	}
}
sub get { ... }

sub set {
	my $self = shift;
	$self->add( $_[0], $_[1] );
}

sub get_by_index {
	my $self = shift;
	
	my $i = $self->{'map'}->get( $_[0] );

	return undef if !defined $i;
	return $self->{'data'}->[ $i ];
}

sub remove {

}

sub member_index {
	my $self = shift;

	$self->_fill_classes unless defined $self->{'_indexed'};

	return { map { $_->index => scalar $_->members } $self->classes };
}

sub correct_subseqs {
	my $self  = shift;
	my $names = shift;

	trace_error("Requires a name file as input") unless (defined $names && $names->isa("Anorman::ESOM::File::Names"));

	my $corrections  = 0;
	my $subseq_index = $names->subseq_index;	

	while (my ($seqid, $indices) = each %{ $subseq_index }) {

		# Map out class membership for each subsequence
		my %h = map { $self->get_by_index( $_ ), 0 } @{ $indices };

		if (scalar keys %h != 1) {
			
			foreach my $i(@{ $indices }) { 
				my $name_item = $names->map->get( $i );
				my $name      = $name_item->name( $_ );
				my $class     = $self->get_by_index( $i );
				my $length    = ($2 - $1 + 1) if $name =~ m/\s+(\d+)-(\d+)$/;

				$h{ $class } += $length;
			}

			my @classes   = sort{ $h{ $b } <=> $h{ $a } || (0) } keys %h;
			my $new_class = shift @classes; 
			
			foreach my $i(grep { $self->get_by_index( $_ ) != $new_class } @{ $indices }) {

				my $class = $self->get_by_index( $i );
				my $name_item =  $names->map->get( $i );

				my $name   = $name_item->name;
				my $index  = $name_item->index;

				warn "Moving $name from class $class to class $new_class\n";

				if ($new_class) {
					$self->set( $index, $new_class );
				} 
				
				$corrections++;
			}
		}
	}

	return $corrections;	
}

sub _fill_classes {
	my $self  = shift;
	my %class_index = ();

	foreach my $class( $self->classes ) {
		$class->clear;
	}

	while (my ($index,$cls) = $self->map->iterate ) {
		$self->classes->[ $cls ]->add_members( $index );
	}

	$self->{'_indexed'} = 1;	
}

1;

