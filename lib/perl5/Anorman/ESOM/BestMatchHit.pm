package Anorman::ESOM::BestMatchHit;

# a class for managing aggregated bestmatch hits during ESOM training
# mean returns the means of all vector values based on the number of bestmatch
# hits

#NOTE: deprecated

use strict;

use Anorman::Math::C;

my $SAME_HITS;

sub new {
	my $class  = shift;
	my $vector = shift;

	my $self = { '_sum'      => $vector,
	             '_size'     => (length($vector) / 8),
		     '_hitcount' => 1 
		   };

	$SAME_HITS++;
	return bless ( $self, $class || ref $class);
}

sub add {
	my $self   = shift;
	my $vector = shift;

	Anorman::Math::C::vectorvector_add( $self->{'_size'}, $self->{'_sum'}, $vector );
	$self->{'_hitcount'}++;
	$SAME_HITS++;
}

sub mean {
	my $self = shift;
	my $mean = $self->{'_sum'};	
	
	if ($self->{'_hitcount'} > 1) {
		Anorman::Math::C::vector_divide( $self->{'_size'}, $mean, $self->{'_hitcount'} );
	}

	return $mean;
}

sub hits {
	my $self = shift;
	$self->{'_hitcount'} = shift if defined $_[0];
	return $self->{'_hitcount'};
}

sub same_hits {
	return $SAME_HITS;
}

1;
