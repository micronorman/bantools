package Anorman::Data::Matrix::Abstract;

use strict;
use warnings;

use parent 'Anorman::Data::Abstract';

use Anorman::Common;
use Anorman::Data::Config qw($MAX_ELEMENTS);

use Scalar::Util qw(refaddr);

# Basic constructor

sub new {
	my $class = ref $_[0] || $_[0];
	my $self  = $class->SUPER::new();

	@{ $self }{ qw(rows columns r0 c0 rstride cstride) } = (0) x 6;

	return $self;
}


# Universal object accesors

sub _elements  {  $_[0]->{'_ELEMS'} }
sub _is_view   {  $_[0]->{'_VIEW'}  }
sub _is_noview { !$_[0]->{'_VIEW'}  }


# Basic object accessors

sub rows           { $_[0]->{'rows'}    }
sub columns        { $_[0]->{'columns'} }
sub _row_stride    { $_[0]->{'rstride'} }
sub _column_stride { $_[0]->{'cstride'} }
sub _row_zero      { $_[0]->{'r0'}      }
sub _column_zero   { $_[0]->{'c0'}      }


# Derived matrix properties

sub size           { $_[0]->{'rows'} * $_[0]->{'columns'} }
sub _row_rank      { $_[0]->{'r0'} + $_[1] * $_[0]->{'rstride'} }
sub _row_offset    { $_[1] }
sub _column_rank   { $_[0]->{'c0'} + $_[1] * $_[0]->{'cstride'} } 
sub _column_offset { $_[1] }
sub _index         { $_[0]->_row_offset($_[0]->_row_rank($_[1]))
                     + $_[0]->_column_offset($_[0]->_column_rank($_[2])) }


# Setup fresh matrix or create a matrix view

sub _setup {
	my $self = shift;
	my ($rows, $columns, $row_zero, $column_zero, $row_stride, $column_stride) = @_;

	trace_error("Matrix too large") if ($rows * $columns) > $MAX_ELEMENTS;
	
	if (@_ == 2) {
		($row_zero,
                 $column_zero,
                 $row_stride,
                 $column_stride) = (0,0,$columns,1);
	}
	
	$self->{'rows'}    = $rows;
	$self->{'columns'} = $columns;
	$self->{'r0'}      = $row_zero;
	$self->{'c0'}      = $column_zero;
	$self->{'rstride'} = $row_stride;
	$self->{'cstride'} = $column_stride;

}


# Consistency checks

sub _check_row {
	if ($_[1] < 0 || $_[1] >= $_[0]->{'rows'}) {
		my ($self, $row) = @_;
		trace_error("Row number ($row) out of bounds " . $self->_to_short_string);
	}
}

sub _check_column {
	if ($_[1] < 0 || $_[1] >= $_[0]->{'columns'}) {
		my ($self, $column) = @_;
		trace_error("Column number ($column) out of bounds " . $self->_to_short_string );
	}
}

sub _check_box {
	my $self = shift;
	my ($row, $column, $height, $width) = @_;

	trace_error("Out of bounds. " . $self->_to_short_string . ", column: $column, row: $row, width: $width, height: $height")
	if ($column < 0 || $width < 0 || $column + $width > $self->{'columns'} ||
		$row < 0 || $height < 0 || $row + $height > $self->{'rows'});
}

sub check_shape {
	my $self = shift;
	my $columns = $self->columns;
	my $rows    = $self->rows;

	foreach my $other(@_) {
		if ($columns != $other->columns || $rows != $other->rows) {
			trace_error("Incompatible dimensions " . $self->_to_short_string . " and " . $other->_to_short_string);
		}
	}
}

# Mutators 

sub _v_dice {
	my $self = shift;

	# Flip rows and columns internally to produce dice view
	($self->{'rows'},$self->{'columns'})    = ($self->{'columns'},$self->{'rows'});
	($self->{'r0'},$self->{'c0'})           = ($self->{'c0'},$self->{'r0'});
	($self->{'rstride'},$self->{'cstride'}) = ($self->{'cstride'},$self->{'rstride'});

	return $self;
}

sub _v_part {
	my $self = shift;

	my ($row,$column,$height,$width) = @_;

	$self->_check_box($row,$column,$height,$width);

	$self->{'r0'}     += $self->{'rstride'} * $row;
	$self->{'c0'}     += $self->{'cstride'} * $column;
	$self->{'rows'}    = $height;
	$self->{'columns'} = $width;

	return $self;
}

1;
