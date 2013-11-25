package Anorman::ESOM::File::Matrix;

use strict;
use warnings;

use parent 'Anorman::ESOM::File';

use Anorman::Common;
use Anorman::Data::LinAlg::Property qw(check_matrix);

our $PACKDATA       = 1;

sub data {
	my $self = shift;
	return $self->{'data'} unless defined $_[0];

	check_matrix($_[0]);	
	$self->{'data'} = shift;

}

sub rows {
	my $self = shift;
	return $self->{'data'}->rows;
}

sub columns {
	my $self = shift;
	return $self->{'data'}->columns;
}

sub neurons {
	my $self = shift;
	return $self->{'data'}->size;
}

sub size {
	my $self = shift;
	return $self->{'data'}->rows;
}

sub _init {
	my $self = shift;

	my ($rows,$columns) = @_;

	if (@_ != 2) {
		$rows    = $self->{'rows'};
		$columns = $self->{'columns'};
	}

	trace_error("Invalid matrix dimensions") unless (defined $rows && defined $columns);

	$self->{'data'} = $PACKDATA ? Anorman::Data->packed_matrix($rows, $columns) : Anorman::Data->matrix($rows,$columns);
}

1;

