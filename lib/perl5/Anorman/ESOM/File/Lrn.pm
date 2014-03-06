package Anorman::ESOM::File::Lrn;

use strict;
use warnings;

use parent 'Anorman::ESOM::File::Matrix';

use Anorman::Common;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new();

	if (@_ == 1) {
		$self->filename( shift );
	} elsif (@_ == 2) {
		$self->_init(@_);
	}

	$self->{'column_types'} = [];
	$self->{'var_names'}    = [];
	$self->{'key_column'}   = -1;
	$self->{'class_column'} = -1;
	

	return $self;
}

sub _init {
	my $self = shift;

	my ($rows, $columns) = @_;

	if (@_ != 2) { 
		$rows    = $self->{'datapoints'};
		$columns = $self->{'dim'};	
	} else {
		$self->{'datapoints'} = $rows;
		$self->{'dim'}        = $columns;
	}

	$self->SUPER::_init( $self->{'datapoints'}, $self->{'dim'} );
	$self->{'keys'} = Anorman::Data::List->new($rows);
	@{ $self->{'keys'} } = (1 .. $rows);
}

sub var_names {
	my $self = shift;

	return wantarray ? @{ $self->{'var_names'} } : $self->{'var_names'} unless defined $_[0];

}

sub col_types {
	my $self = shift;

	return wantarray ? @{ $self->{'col_types'} } : $self->{'col_types'} unless defined $_[0];
}

sub get_by_index {
	my $self = shift;
	my $index = shift;

	if ($self->{'keys'}->contains( $index )) {
		return $self->{'data'}->view_row( $self->{'keys'}->index_of( $index ) );
	} else {
		return undef;
	}
}

sub keys {
	my $self = shift;

	return $self->{'keys'} unless defined $_[0];

	if ($self->{'key_column'} < 0) {
		unshift @{ $self->{'key_column'} }, 9;
		$self->{'key_column'} = 0;
		$self->{'key_column_name'} = 'Keys';
	}

	$self->{'keys'} = $_[0];
}

sub rows {
	# Prevents matrix class from returning rows
}

sub columns {
	# Prevents matrix class from returning columns

}

sub neurons {

}

sub _usage {
	my $usage = "\n\nUsage:";
	my $prefix = "\n" . __PACKAGE__ . "::new( ";

	
	return $usage . $prefix . " filename )" . $prefix . " rows, columns )";
}

1;

