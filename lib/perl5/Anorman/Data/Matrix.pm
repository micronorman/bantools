package Anorman::Data::Matrix;

use strict;
use warnings;

use parent 'Anorman::Data';

use Anorman::Common qw(sniff_scalar trace_error);
use Anorman::Math::Common qw( min max plus minus identity );
use Anorman::Data::LinAlg::Property qw( :all );

use Scalar::Util qw(refaddr blessed looks_like_number);

use Anorman::Data::Matrix::DensePacked;
use Anorman::Data::Matrix::Dense;

use overload
	'""'  => \&_to_string,
	'@{}' => \&_to_array,
	'=='  => \&equals;

my %ASSIGN_DISPATCH = (
	'NUMBER'        => \&_assign_Matrix_from_NUMBER,
	'2D_MATRIX'     => \&_assign_Matrix_from_2D_MATRIX,
	'OBJECT'        => \&_assign_Matrix_from_OBJECT,
	'OBJECT+CODE'	=> \&_assign_Matrix_from_OBJECT_and_CODE,	
	'CODE'          => \&_assign_Matrix_from_CODE
);

# basic constructor
sub new {
	my $class = ref $_[0] || $_[0];
	my $self  = {
	    'rows'    => 0,
            'columns' => 0,
            'r0'      => 0,
            'c0'      => 0,
            'rstride' => 0,
            'cstride' => 0,
            '_ELEMS'  => [],
            '_VIEW'   => undef
	};

	return bless ( $self, $class );
}

# basic object accessors
sub rows {
	return $_[0]->{'rows'};
}

sub columns {
	return $_[0]->{'columns'};
}

sub row_stride {
	return $_[0]->{'rstride'};
}

sub column_stride {
	return $_[0]->{'cstride'};
}

sub row_zero {
	return $_[0]->{'r0'};
}

sub column_zero {
	return $_[0]->{'c0'};
}

sub size {
	return ($_[0]->rows * $_[0]->columns);
}

sub _is_noview {
	return (!defined $_[0]->{'_VIEW'});
}

sub _row_rank {
	my $self = shift;
	return $self->column_zero + $_[0] * $self->row_stride;
}

sub _column_rank {
	my $self = shift;
	return $self->column_zero + $_[0] * $self->column_stride;
}

# universal matrix commands
sub get {
	my $self = shift;
	
	if ( $_[1] < 0 || $_[1] >= $self->columns || $_[0] < 0 || $_[0] >= $self->rows) {
		$self->_error("Index out of bounds ( $_[0], $_[1] ) "); 
	}

	return $self->get_quick( $_[0], $_[1] );
}

sub set {
	my $self = shift;
	
	if ( $_[1] < 0 || $_[1] >= $self->columns || $_[0] < 0 || $_[0] >= $self->rows) {
		$self->_error("Index out of bounds ( $_[0], $_[1] ) "); 
	}

	$self->set_quick( $_[0], $_[1], $_[2] );
}

sub view_row {
	my $self = shift;
	
	$self->_check_row( $_[0] );

	my $view_size   = $self->columns;
	my $view_zero   = $self->_index( $_[0], 0 );
	my $view_stride = $self->column_stride;

	return $self->_like_vector($view_size, $view_zero, $view_stride);
}

sub view_column {
	my $self =shift;

	$self->_check_column( $_[0] );

	my $view_size   = $self->rows;
	my $view_zero   = $self->_index( 0, $_[0] );
	my $view_stride = $self->row_stride;

	return $self->_like_vector($view_size, $view_zero, $view_stride);
}

sub view_selection {
	my $self = shift;
	
	my ($row_indexes, $column_indexes) = @_;
	
	$row_indexes    = [ (0 .. $self->rows    - 1) ] if (!defined $row_indexes);
	$column_indexes = [ (0 .. $self->columns - 1) ] if (!defined $column_indexes);

	my $row_offsets    = [ map { $self->row_zero + $_ * $self->row_stride } @{ $row_indexes    } ];
	my $column_offsets = [ map { $self->column_zero + $_ * $self->column_stride } @{ $column_indexes } ];

	return $self->_view_selection_like( $row_offsets, $column_offsets );
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

sub copy {
	my $self  = shift;
	my $copy  = $self->like;

	$copy->assign( $self );
	
	return $copy;  
}

sub pack {
	my $self = shift;
	my $copy = Anorman::Data::Matrix::DensePacked->new( $self->rows, $self->columns );

	$copy->assign( $self );
	
	return $copy;
}

sub unpack {
	my $self = shift;
	my $copy = Anorman::Data::Matrix::Dense->new( $self->rows, $self->columns );

	$copy->assign( $self );

	return $copy;
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
	$f = \&identity if !defined $f;

	my $loop_func;

	if ($other) {
		$self->_check_shape($other);
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

	my $min = $self->aggregate( \&min );
	my $max = $self->aggregate( \&max );

	return if ($min == 0 && $max == 1);

	my $diff = $max - $min;
	$self->assign( sub { $_[0] - $min } );
	$self->assign( sub { $_[0] / $diff } );
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
	my ($self, $other, $result, $alpha, $beta) = @_;
	
	$self->_error("Can only multiply with vector or matrix") unless (is_vector($other) || is_matrix($other));

	my ($m, $n) = ($self->rows, $self->columns);

	$alpha = 1 if !defined $alpha;
	$beta  = defined $result ? (defined $beta ? $beta : 1) : 0; 
	
	# matrix-vector multiplication
	if (is_vector($other)) {
		$result = $other->like( $m ) if !defined $result;
		$self->_error("Incompatible dimensions (A, y, z): " .
			$self->_to_short_string . ", " . 
			$other->_to_short_string . ", " .
                        $result->_to_short_string ) 
		if ($n != $other->size || $m != $result->size);

		$self->_mult_matrix_vector($other, $result, $alpha,$beta);
		return $result;
	# matrix-matrix multiplication
	} else {
		# chache the result matrix
		$result = $other->like($m, $other->columns) if !defined $result;
		check_matrix($result);
	
		$self->_error("Matrix2D inner dimensions must agree: " . $self->_to_short_string . ", " .
			$other->_to_short_string ) if ($other->rows != $n );
		$self->_error("Incompatible result matrix: " . $self->_to_short_string . ", " . $other->_to_short_string . ", "
                        . $result->_to_short_string ) if ($result->rows != $m || $result->columns != $other->columns);

		$self->_mult_matrix_matrix($other, $result, $alpha, $beta);
		return $result;
	}
}

sub _mult_matrix_matrix {
	my ($self, $other, $result, $alpha, $beta) = @_;

	my ($m, $n, $p) = ($self->rows, $self->columns, $other->columns);

	my $j = $p;
	while (--$j >=0) {
		my $i = $m;
		while ( --$i >= 0) {
			my $s = 0;
			my $k = $n;
			while ( --$k >= 0 ) {
				$s += $self->get_quick($i,$k) * $other->get_quick($k, $j);
			}
			$result->set_quick($i,$j,$alpha * $s + $beta * $result->get_quick($i,$j));
		}
	}
}

sub _mult_matrix_vector {
	my ($self, $other, $result, $alpha, $beta) = @_;

	my ($m,$n) = ($self->rows,$self->columns);

	my $i = $n;
	while ( --$i >=0 ) {
		my $s = 0;
		my $j = $m;
		while ( --$j >= 0 ) {
				$s += $self->get_quick($i,$j) * $other->get_quick($j);
			}
		$result->set_quick( $i, $alpha * $s + $beta * $other->get_quick($i) );
	}
}



sub _to_array {
	# repackages internal matrix to perl array of arays
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

sub _setup {
	my $self = shift;

	if (@_ != 2 && @_ != 6) {
		$self->_error("Wrong number of arguments\nUsage: " . __PACKAGE__ .
                "::_setup( row, columns [, row_zero, column_zero, row_stride, column_stride ]");
	}

	my ($rows, $columns, $row_zero, $column_zero, $row_stride, $column_stride) = @_;

	if (@_ == 2) {
		$row_zero      = 0;
		$column_zero   = 0;
		$row_stride    = $columns;
		$column_stride = 1;
		$self->{'_VIEW'} = undef;
	} else {
		$self->{'_VIEW'} = 1;
	}

	$self->{'rows'}    = $rows;
	$self->{'columns'} = $columns;
	$self->{'r0'}      = $row_zero;
	$self->{'c0'}      = $column_zero;
	$self->{'rstride'} = $row_stride;
	$self->{'cstride'} = $column_stride;

}

### CHECKS ###

sub _check_row {
	if ($_[1] < 0 || $_[1] >= $_[0]->rows) {
		my ($self, $row) = @_;
		$self->_error("Row number ($row) out of bounds " . $self->_to_short_string);
	}
}

sub _check_column {
	if ($_[1] < 0 || $_[1] >= $_[0]->columns) {
		my ($self, $column) = @_;
		$self->_error("Column number ($column) out of bounds " . $self->_to_short_string );
	}
}

sub _check_shape {
	my $self = shift;
	my $columns = $self->columns;
	my $rows    = $self->rows;

	foreach my $other(@_) {
		check_matrix( $other );
		if ($columns != $other->columns || $rows != $other->rows) {
			$self->_error("Incompatible dimensions " . $self->_to_short_string . " and " . $other->_to_short_string);
		}
	}
}

sub _check_box {
	my $self = shift;
	my ($row, $column, $height, $width) = @_;

	$self->_error("Out of bounds. " . $self->_to_short_string . ", column: $column, row: $row, width: $width, height: $height")
	if ($column < 0 || $width < 0 || $column + $width > $self->columns ||
		$row < 0 || $height < 0 || $row + $height > $self->rows);
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

#### ASSIGNMENT ####

sub _assign_Matrix_from_NUMBER {
	my ($self,$value) = @_;
	
	my $r = $self->rows;
	my $c = $self->columns;

	my $row = -1;
	while ( ++$row < $r ) {
		
		my $column = -1;
		while ( ++$column < $c ) {
			$self->set_quick($row,$column,$value);
		}
	}

	1;
}

sub _assign_Matrix_from_OBJECT {
	my ($self,$other) = @_;
	return if ($self == $other);
	$self->_check_shape($other);
	$other = $other->copy if $self->_have_shared_cells($other);

	my $row = $self->rows;
	while ( --$row >= 0 ) {
		my $column = $self->columns;
		while ( --$column >= 0) {
			$self->set_quick($row, $column, $other->get_quick($row,$column));
		}
	}
	1;
}

sub _assign_Matrix_from_2D_MATRIX {
	my $self = shift;

	$self->_error("Must have same number of rows (" . $self->rows . ") as matrix object. Rows=" . @{ $_[0] } ) 
		if @{ $_[0] } != $self->rows;

	my $M   = $_[0];
	my $row = $self->rows;

	while (--$row >= 0) { 
		my $row_ref = $M->[ $row ];

		# Column length sanity check
		$self->_error("Column length error") if (@{ $row_ref } != $self->columns );
		
		my $column = $self->columns;
		while (--$column >= 0) {
			$self->set_quick( $row, $column, $row_ref->[ $column ] );
		}
	}

	1;
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
	1;
}

sub _assign_Matrix_from_OBJECT_and_CODE {
	my ($self, $other, $function) = @_;
	$self->_check_shape( $other );
	my $row = $self->rows;
	while ( --$row >= 0 ) {
		my $column = $self->columns;
		while ( --$column >= 0 ) {
			$self->set_quick($row, $column, $function->($self->get_quick($row, $column) , $other->get_quick($row, $column)));
		}
	}
	
}

sub _to_string {
	my $self = shift;

	my $rows    = $self->rows;
	my $columns = $self->columns;
	my $string  = '';
	my $format  = $Anorman::Data::FORMAT;

	my $row = -1;
	while (++$row < $rows) {
		$string .=  join ("\t", map { my $v; defined ($v = $self->get_quick( $row, $_)) ? sprintf ( $format, $v ) : 'nan' } (0 .. $columns - 1) ) . "\n" ;
		#$string .=  join ("\t", map { my $v; defined ($v = $self->get_quick( $row, $_)) ? $v : 'nan' } (0 .. $columns - 1) ) . "\n" ;
	}

	return $string;
}

sub _to_short_string {
	my $self = shift;

	return "[ " . $self->rows . " x " . $self->columns . " ]";
}

sub _view {
	my $self = shift;
	return $self->clone;
}

sub _v_dice {
	# self modifying dice view
	my $self = shift;

	($self->{'rows'},$self->{'columns'}) = ($self->{'columns'},$self->{'rows'});
	($self->{'r0'},$self->{'c0'}) = ($self->{'c0'},$self->{'r0'});
	($self->{'rstride'},$self->{'cstride'}) = ($self->{'cstride'},$self->{'rstride'});

	$self->{'_VIEW'} = 1;

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
	
	$self->{'_VIEW'} = 1;

	return $self;
}

1;
