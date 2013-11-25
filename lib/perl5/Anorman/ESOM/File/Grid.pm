package Anorman::ESOM::File::Grid;

use strict;
use warnings;

use parent 'Anorman::ESOM::File::Matrix';

use Anorman::Common;

sub _init {
	my $self = shift;

	if (@_ == 3) {
		my ($rows, $columns, $dim) = @_;
		$self->{'rows'}    = $rows;
		$self->{'columns'} = $columns;
		$self->{'dim'}     = $dim;
		$self->{'neurons'} = $rows * $columns;
	}

	$self->SUPER::_init( $self->{'neurons'}, $self->{'dim'} );
}

# Overwrite parent methods to prevent calls from Matrix class
sub rows    { $_[0]->{'rows'}    }
sub columns { $_[0]->{'columns'} }
sub neurons { $_[0]->{'neurons'} }

1;

