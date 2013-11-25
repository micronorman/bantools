package Anorman::Data::Matrix::Dense;

use strict;
use parent 'Anorman::Data::Matrix';

use Anorman::Common qw(trace_error sniff_scalar);
use Anorman::Data::Vector::Dense;
use Anorman::Data::Matrix::SelectedDense;

# saves having to identify data type more than once when assigning
# new data to a matrix
my %ASSIGN_DISPATCH = (
	'NUMBER'        => \&_assign_DenseMatrix_from_NUMBER,
	'2D_MATRIX'     => \&_assign_DenseMatrix_from_2D_MATRIX,
	'OBJECT'        => \&_assign_DenseMatrix_from_OBJECT,
	'OBJECT+CODE'	=> \&_assign_DenseMatrix_from_OBJECT_and_CODE,	
	'CODE'          => \&_assign_DenseMatrix_from_CODE
);

sub new {
	my $class = ref ($_[0]) ? ref shift : shift;

	if (@_ != 1 && @_ != 2 && @_ != 7) {
		$class->_error("Wrong number of arguments");
	}
	
	my $self = $class->SUPER::new();
	my ( $rows,
             $columns,
             $row_zero,
             $column_zero,
             $row_stride,
             $column_stride
           );
	
	if (@_ == 1) {
		if (sniff_scalar($_[0]) eq '2D_MATRIX') {
			$rows    = @{ $_[0] };
			$columns = @{ $_[0] } == 0 ? 0 : @{ $_[0]->[0] };

			$self->_setup( $rows, $columns );
			$self->_allocate_elements( $rows, $columns );

			$self->_assign_DenseMatrix_from_2D_MATRIX( $_[0] );
		} else {
			$self->_error("Single argument must be a reference to Array of Arrays\n" );
		}
	} elsif (@_ == 2) {
		($rows, $columns ) = @_[0,1];
		$self->_setup( $rows, $columns );	
		$self->_allocate_elements( $rows, $columns );
	} else {
		$self->_error("Cannot set up view on non-object reference") unless sniff_scalar($_[0]) eq 'OBJECT';
		( $rows,
             	  $columns,
             	  $row_zero,
             	  $column_zero,
             	  $row_stride,
             	  $column_stride
                ) = @_[0,1,3..6];

		$self->_setup( $rows, $columns, $row_zero, $column_zero, $row_stride, $column_stride );
		$self->_assign_from_OBJECT( $_[0] );
	}

	return $self;
}

sub assign {
	my $self = shift;
	my $type = sniff_scalar($_[0]);

	# determine type of data passed
	if (@_ == 2) {
		my $arg2_type = sniff_scalar( $_[1] );
		unless ($type eq 'OBJECT' && $arg2_type eq 'CODE') {
			$self->_error("Invalid arguments. Argument 2 is not a CODE block ($type,$arg2_type)");
		}
		$type = 'OBJECT+CODE';
	}

	# execute from dispatch table
	$ASSIGN_DISPATCH{ $type }->( $self, @_ ) || $self->_error("Assigment error");

	return $self;
}

sub set_quick {
	my $self = shift;
	my ($r, $c, $value) = @_;

	$self->{'_ELEMS'}->[ $self->{'r0'} + $r * $self->{'rstride'} + $self->{'c0'} + $c * $self->{'cstride'} ] = $value;
}

sub get_quick {
	my $self = shift;
	my ($r, $c) = @_;

	return $self->{'_ELEMS'}->[ $self->{'r0'} + $r * $self->{'rstride'} + $self->{'c0'} + $c * $self->{'cstride'} ];
}

sub like {
	my $self  = shift;
	my ($rows, $columns);

	if (@_ == 2) {
		($rows, $columns) = @_;
	} else {
		$rows    = $self->rows;
		$columns = $self->columns;
	}

	return $self->new($rows, $columns);
}

sub _allocate_elements {
	my ($self, $rows, $columns) = @_;
	@{ $self->{'_ELEMS'} } = (0) x ($rows * $columns);
}

sub _index {
	my $self = shift;
	my ($r, $c) = @_;
	return ($self->{'r0'} + $r * $self->{'rstride'} + $self->{'c0'} + $c * $self->{'cstride'});
}

sub like_vector {
	my $self = shift;
	
	if (@_ == 1) {
		return Anorman::Data::Vector::Dense->new($_[0])
	} else {
		trace_error("Wrong number of arguments");
	}
}

sub _like_vector {
	my $self  = shift;
	my ($size, $zero, $stride) = @_;

	return Anorman::Data::Vector::Dense->new($size, $self, $zero, $stride)
}

sub _assign_DenseMatrix_from_2D_MATRIX {
	# assign array of arrays as matrix (copy into single indexed array structure)

	my ($self, $M) = @_;

	if ($self->_is_noview) {
		$self->_error("Must have same number of rows (" . $self->rows . ") as matrix object. Rows=" . @{ $M } ) 

		if @{ $M } != $self->rows;

		my $i   = $self->columns * ($self->rows - 1);
		my $row = $self->rows;

		while (--$row >= 0) { 
			my $row_ref = $M->[ $row ];

			# Column length sanity check
			$self->_error("Column length error") if (@{ $row_ref } != $self->columns );
			splice (@{ $self->{'_ELEMS'} }, $i, $self->columns, @{ $row_ref });
			
			$i -= $self->columns; 
		}
	} else {
		$self->SUPER::_assign_Matrix_from_2D_MATRIX( $M );
	}
	1;
}

sub _assign_DenseMatrix_from_OBJECT {
	my ($self, $other) = @_;
	

	if ( (ref $other) ne 'Anorman::Data::Matrix::Dense'  ) {
		return $self->SUPER::_assign_Matrix_from_OBJECT( $other );
	}
	
	return 1 if ($self == $other);

	$self->_check_shape( $other );

	if ($self->_is_noview && $other->_is_noview) {
		@{ $self->{'_ELEMS'} } = @{ $other->{'_ELEMS'} };
	}

	if ($self->_have_shared_cells( $other )) {
		my $copy = $other->copy;

		$other = $copy;
	}

	my $A_elems   = $self->{'_ELEMS'};
	my $B_elems   = $other->{'_ELEMS'};
	my $A_cstride = $self->{'cstride'};
	my $B_cstride = $other->{'cstride'};
	my $A_rstride = $self->{'rstride'};
	my $B_rstride = $other->{'rstride'};

	my $A_index   = $self->_index(0,0);
	my $B_index   = $other->_index(0,0);
	
	my $row = $self->{'rows'};
	while ( --$row >= 0) {

		my $i      = $A_index;
		my $j      = $B_index;
		my $column = $self->{'columns'};
		while ( --$column >= 0 ) {
			$A_elems->[ $i ] = $B_elems->[ $i ];
			$i += $A_cstride;
			$j += $B_cstride;
		}

		$A_index += $A_rstride;
		$B_index += $B_rstride;
	}

	1;
}

sub _assign_DenseMatrix_from_OBJECT_and_CODE {
	my ($self, $other, $CODE) = @_;
	
	if (ref ($other) ne 'Anorman::Data::Matrix::Dense') {
		return $self->SUPER::_assign_Matrix_from_OBJECT_and_CODE( $other, $CODE);
	}

	$self->_check_shape( $other );

	my $A_elems   = $self->{'_ELEMS'};
	my $B_elems   = $other->{'_ELEMS'};
	my $A_cstride = $self->{'cstride'};
	my $B_cstride = $other->{'cstride'};
	my $A_rstride = $self->{'rstride'};
	my $B_rstride = $other->{'rstride'};

	my $A_index   = $self->_index(0,0);
	my $B_index   = $other->_index(0,0);
	
	my $row = $self->{'rows'};
	while ( --$row >= 0) {

		my $i      = $A_index;
		my $j      = $B_index;
		my $column = $self->{'columns'};
		while ( --$column >= 0 ) {
			$A_elems->[ $i ] = $CODE->( $A_elems->[ $i], $B_elems->[ $i ] );
			$i += $A_cstride;
			$j += $B_cstride;
		}

		$A_index += $A_rstride;
		$B_index += $B_rstride;
	}

	1;
}

sub _assign_DenseMatrix_from_NUMBER {
	my ($self, $value) = @_;

	my $elems   = $self->{'_ELEMS'};
	my $index   = $self->_index(0,0);
	my $cstride = $self->{'cstride'};
	my $rstride = $self->{'rstride'};

	my $row = $self->{'rows'};

	while ( --$row >= 0) {
		
		my $i      = $index;
		my $column = $self->{'columns'};
		while ( --$column >= 0 ) {
			$elems->[ $i ] = $value;
			$i += $cstride;
		}

		$index += $rstride;

	}

	1;

}

sub _assign_DenseMatrix_from_CODE {
	my ($self, $CODE) = @_;
	
	my $elems   = $self->{'_ELEMS'};
	my $index   = $self->_index(0,0);
	my $cstride = $self->{'cstride'};
	my $rstride = $self->{'rstride'};

	my $row = $self->{'rows'};

	while ( --$row >= 0) {
		
		my $i      = $index;
		my $column = $self->{'columns'};
		while ( --$column >= 0 ) {
			$elems->[ $i ] = $CODE->( $elems->[ $i ] );
			$i += $cstride;
		}

		$index += $rstride;

	}

	1;
}

sub _have_shared_cells_raw {
	if (ref $_[1] eq 'Anorman::Data::Matrix::Dense') {
		return ($_[0]->{'_ELEMS'} eq $_[1]->{'_ELEMS'});
	}
}

sub _view_selection_like {
	my $self = shift;
	return Anorman::Data::Matrix::SelectedDense->new( $self->{'_ELEMS'}, $_[0], $_[1],0);
}

sub DESTROY {
	my $self = shift;
	@{ $self->{'_ELEMS'} } = () if $self->_is_noview;
}

1;
