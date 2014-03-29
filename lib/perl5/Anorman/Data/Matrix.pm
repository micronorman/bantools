package Anorman::Data::Matrix;

use strict;
use warnings;

use Anorman::Common qw(sniff_scalar trace_error);
use Anorman::Data::Config qw( :string_rules ); 
use Anorman::Data::LinAlg::BLAS;
use Anorman::Data::LinAlg::Property qw( :all );
use Anorman::Math::Functions;

use Scalar::Util qw(refaddr blessed looks_like_number);
use List::Util qw(min);

my %ASSIGN_DISPATCH = (
	'NUMBER'        => \&_assign_Matrix_from_NUMBER,
	'2D_MATRIX'     => \&_assign_Matrix_from_2D_MATRIX,
	'OBJECT'        => \&_assign_Matrix_from_OBJECT,
	'OBJECT+CODE'	=> \&_assign_Matrix_from_OBJECT_and_CODE,	
	'CODE'          => \&_assign_Matrix_from_CODE
);

# universal matrix commands

sub get {
	my $self = shift;
	
	if ( $_[1] < 0 || $_[1] >= $self->columns || $_[0] < 0 || $_[0] >= $self->rows) {
		trace_error("Index out of bounds ( $_[0], $_[1] ) "); 
	}

	return $self->get_quick( $_[0], $_[1] );
}

sub set {
	my $self = shift;
	
	if ( $_[1] < 0 || $_[1] >= $self->columns || $_[0] < 0 || $_[0] >= $self->rows) {
		trace_error("Index out of bounds ( $_[0], $_[1] ) "); 
	}

	$self->set_quick( $_[0], $_[1], $_[2] );
}

sub view_row {
	my $self = shift;
	
	$self->_check_row( $_[0] );

	my $view_size   = $self->columns;
	my $view_zero   = $self->_index( $_[0], 0 );
	my $view_stride = $self->_column_stride;

	return $self->_like_vector($view_size, $view_zero, $view_stride);
}

sub view_column {
	my $self = shift;

	$self->_check_column( $_[0] );

	my $view_size   = $self->rows;
	my $view_zero   = $self->_index( 0, $_[0] );
	my $view_stride = $self->_row_stride;

	return $self->_like_vector($view_size, $view_zero, $view_stride);
}

sub view_diagonal {
	my $self = shift;

	my $view_size   = min ( $self->rows, $self->columns );
	my $view_zero   = $self->_index( 0, 0 );
	my $view_stride = $self->_row_stride + 1;

	return $self->_like_vector($view_size, $view_zero, $view_stride);
}

sub view_selection {
	my $self = shift;
	
	my ($row_indexes, $column_indexes) = @_;
	
	$row_indexes    = [ (0 .. $self->rows    - 1) ] if (!$row_indexes   );
	$column_indexes = [ (0 .. $self->columns - 1) ] if (!$column_indexes);

	my @row_offsets    = map { $self->_row_offset($self->_row_rank($_))       } @{ $row_indexes    };
	my @column_offsets = map { $self->_column_offset($self->_column_rank($_)) } @{ $column_indexes };
	
	return $self->_view_selection_like( \@row_offsets, \@column_offsets );
}

sub view_dice {
	my $self = shift;
	return $self->_view->_v_dice;
}

sub view_part {
	my $self = shift;

	my ($row,$column,$height,$width) = @_;

	return $self->_view->_v_part( $row, $column, $height, $width );
}

sub swap_rows {
	my $self = shift;
	my ($a,$b) = @_;

	$self->_check_row( $a );
	$self->_check_row( $b );

	return if ($a == $b);

	$self->view_row( $a )->swap( $self->view_row( $b ) );
}

sub swap_columns {
	my $self = shift;
	my ($a,$b) = @_;

	$self->_check_column( $a );
	$self->_check_column( $b );

	return if ($a == $b);

	$self->view_column( $a )->swap( $self->view_column( $b ) );
}

sub like {
	my $self = shift;

	if (@_ == 2) {
		return $self->new( $_[0], $_[1] );
	} else {
		return $self->new( $self->rows, $self->columns );
	}
}

sub assign {
	# For assigning matrices of different types
	# Override for similar types
	my $self = $_[0];
	my $type = sniff_scalar($_[1]);

	$ASSIGN_DISPATCH{ $type }->( @_ );
}

sub aggregate {
	my $self  = shift;

	# Check wether results matrix was provided
	my $other = shift if is_matrix($_[0]);
	
	return undef if ($self->size == 0);
	
	my ($aggr, $f) = @_;

	# Set f to identity if it was not provided
	$f = Anorman::Math::Functions::identity if !defined $f;

	my $loop_func;

	if ($other) {
		$self->check_shape($other);
		$loop_func = sub { $f->( $self->get_quick($_[0],$_[1]), $other->get_quick($_[0],$_[1]) ) };
	} else {
		$loop_func = sub { $f->( $self->get_quick($_[0], $_[1]) ) };
	}

	my $row    = $self->rows - 1;
	my $column = $self->columns - 1;

	my $a = $loop_func->($row,$column);
	my $d = 1;
	
	$row = $self->rows;
	while ( --$row >= 0 ) {
		$column = $self->columns - $d;
		while ( --$column >= 0 ) {
			$a = $aggr->( $a, $loop_func->($row,$column) ); 
		}
		$d = 0;
	}

	return $a;
}

sub normalize {
	# Normalize matrix in place to [0..1]
	my $self = shift;
	my $F = Anorman::Math::Functions->new;

	my $min = $self->aggregate( $F->min );
	my $max = $self->aggregate( $F->max );

	return if ($min == 0 && $max == 1);

	$self->assign( $F->minus($min)      );
	$self->assign( $F->div($max - $min) );
}

sub equals {
	my $self = shift;

	# will check for equality between two matrix objects
	if (is_matrix( $_[0])) {
		my $other = shift;

		# same adress?
		return 1 if (refaddr($other) == refaddr($self));

		# same dimensions?
		return matrix_equals_matrix( $self, $other );

	# will check if all values of the matrix equals a given value
	} else {
		my $value = shift;

		return matrix_equals_value( $self, $value );
	}
}

sub mult {
	my ($self, $other, $result, $alpha, $beta, $transA, $transB) = @_;
	
	trace_error("Can only multiply with vector or matrix") unless (is_vector($other) || is_matrix($other));

	my ($m, $n) = ($self->rows, $self->columns);

	$alpha = 1 if !defined $alpha;
	$beta  = defined $result ? (defined $beta ? $beta : 1) : 0; 
	
	# matrix-vector multiplication
	if (is_vector($other)) {
		if (!defined $result) {
			$result = $other->like( $m ) if !defined $result;
		}

		if ($n != $other->size || $m != $result->size) {
			trace_error("Incompatible dimensions (A, y, z): " .
				$self->_to_short_string  . ", " . 
				$other->_to_short_string . ", " .
				$result->_to_short_string )
		} 

		$self->_mult_matrix_vector($other, $result, $alpha, $beta, $transA);

		return $result;

	# matrix-matrix multiplication
	} else {
		check_matrix($other);

		if (!defined $result) {	
			$result = $other->like($m, $other->columns);
		}

		if ($other->rows != $n ) {
			trace_error("Matrix2D inner dimensions must agree: " 
					. $self->_to_short_string . ", "
					. $other->_to_short_string )
		}
 
		if ($result->rows != $m || $result->columns != $other->columns) {
			trace_error("Incompatible result matrix: " 
					. $self->_to_short_string . ", " 
					. $other->_to_short_string . ", "
					. $result->_to_short_string )
		}

		$self->_mult_matrix_matrix($other, $result, $alpha, $beta, $transA, $transB);

		return $result;
	}
}

sub _mult_matrix_matrix {
	my ($A,$B,$C, $alpha, $beta, $transA, $transB ) = @_;

	Anorman::Data::BLAS::blas_gemm($transA ? BlasTrans : BlasNoTrans,
				       $transB ? BlasTrans : BlasNoTrans,
                                       $alpha, $A, $B, $beta, $C);

	# Moved to BLAS
	#my ($m, $n, $p) = ($self->rows, $self->columns, $other->columns);
	#my $j = $p;
	#while (--$j >=0) {
	#	my $i = $m;
	#	while ( --$i >= 0) {
	#		my $s = 0;
	#		my $k = $n;
	#		while ( --$k >= 0 ) {
	#			$s += $self->get_quick($i,$k) * $other->get_quick($k, $j);
	#		}
	#		$result->set_quick($i,$j,$alpha * $s + $beta * $result->get_quick($i,$j));
	#	}
	#}
}

sub _mult_matrix_vector {
	my ($A, $x, $y, $alpha, $beta, $transA) = @_;

	Anorman::Data::BLAS::blas_gemv( $transA ? BlasTrans : BlasNoTrans, $alpha, $A, $x, $beta, $y);
	#my ($m,$n) = ($self->rows,$self->columns);

	#my $i = $m;
	#while ( --$i >=0 ) {
	#	my $s = 0;
	#	my $j = $n;
	#	while ( --$j >= 0 ) {
	#		$s += $self->get_quick($i,$j) * $other->get_quick($j);
	#	}
	#
	#	$result->set_quick( $i, $alpha * $s + $beta * $result->get_quick($i) );
	#}
}


sub _have_shared_cells {
	my ($self, $other) = @_;

	return undef if (!defined $other);
	return 1 if (refaddr($other) == refaddr($self));
	return $self->_have_shared_cells_raw( $other );
}

sub _have_shared_cells_raw {
	return undef;
}


# Assign values to the matrix from different  kinds of sources

sub _assign_Matrix_from_NUMBER {
	my ($self,$value) = @_;
	
	my $row = $self->rows;
	while ( --$row >= 0 ) {
		
		my $column = $self->columns;
		while ( --$column >= 0 ) {
			$self->set_quick($row,$column,$value);
		}
	}

	return $self;
}

sub _assign_Matrix_from_OBJECT {
	my ($self,$other) = @_;
	return if ($self == $other);
	$self->check_shape($other);
	$other = $other->copy if $self->_have_shared_cells($other);

	my $row = $self->rows;
	while ( --$row >= 0 ) {
		my $column = $self->columns;
		while ( --$column >= 0) {
			$self->set_quick($row, $column, $other->get_quick($row,$column));
		}
	}

	return $self;
}

sub _assign_Matrix_from_2D_MATRIX {
	my $self = shift;

	trace_error("Must have same number of rows (" . $self->rows . ") as matrix object. Rows=" . @{ $_[0] } ) 
		if @{ $_[0] } != $self->rows;

	my $M   = $_[0];
	my $row = $self->rows;

	while ( --$row >= 0 ) { 
		my $row_ref = $M->[ $row ];

		# Column length sanity check
		$self->_error("Column length error") if (@{ $row_ref } != $self->columns );
		
		my $column = $self->columns;
		while ( --$column >= 0 ) {
			$self->set_quick( $row, $column, $row_ref->[ $column ] );
		}
	}

	return $self;
}

sub _assign_Matrix_from_CODE {
	my ($self,$function) = @_;
	my $row = $self->rows;
	while ( --$row >= 0 ) {
		my $column = $self->columns;
		while ( --$column >= 0) {
			$self->set_quick($row, $column, $function->( $self->get_quick($row,$column)) );
		}
	}

	return $self;
}

sub _assign_Matrix_from_OBJECT_and_CODE {
	my ($self, $other, $function) = @_;
	$self->check_shape( $other );

	my $row = $self->rows;
	while ( --$row >= 0 ) {
		my $column = $self->columns;
		while ( --$column >= 0 ) {
			$self->set_quick($row, $column, $function->($self->get_quick($row, $column) , $other->get_quick($row, $column)));
		}
	}
	
	return $self;
}

sub _to_array {
	# repackages internal matrix into perl array of arays
	my $self   = shift;
	my $values = [[]];

	my $row = $self->rows;	
	while (--$row >= 0) {
		my $col = $self->columns;
		while (--$col >= 0) {
			$values->[ $row ][ $col ] = $self->get_quick( $row, $col );
		}
	}

	return $values;
}

# Pretty printing of matrices

sub _to_string {
	my $self = shift;

	my $rows    = $self->rows;
	my $columns = $self->columns;
	my $string  = '';

	my $row = -1;
	while (++$row < $rows) {
		$string .= $MATRIX_ROW_ENDS->[0];
		$string .= join ($MATRIX_COL_SEPARATOR, map { sprintf( $FORMAT, $_ ) } @{ $self->view_row( $row )->_to_array });
		$string .= $MATRIX_ROW_ENDS->[1];
		$string .= $MATRIX_ROW_SEPARATOR;
	}

	return $string;
}

sub _to_short_string {
	my $self = shift;

	return "[ " . $self->rows . " x " . $self->columns . " ]";
}

1;
