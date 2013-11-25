package Anorman::Data::LinAlg::Property;

# Functions that determine matrix or vector properties
# Again, this is all borrowed heavily from the java colt libraries


use strict;


use Scalar::Util qw(refaddr reftype blessed looks_like_number);
use Anorman::Common qw(is_null trace_error);

# export functions
use Exporter;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@EXPORT_OK   = qw( 
	check_matrix
	check_rectangular
	check_square
	check_vector
	is_packed
	is_identity
	is_matrix
	is_square
	is_singular
	is_diagonal
	is_symmetric
	is_vector
	matrix_equals_matrix
	matrix_equals_value
	vector_equals_vector
	vector_equals_value
);
 
%EXPORT_TAGS = ( vector => [ qw(is_packed is_vector check_vector vector_equals_vector vector_equals_value) ],
                 matrix => [ qw(is_packed is_matrix is_symmetric is_square is_singular is_diagonal is_identity
                             check_matrix check_rectangular check_square matrix_equals_matrix matrix_equals_value) ],
		 all => [ @EXPORT_OK ] );

@ISA = qw(Exporter);


# TOLERANCE determines the tolerance of the equals funcitons. Can be set externally using 
# $Anorman::Data::LinAlg::Property::TOLERANCE = 1e-12 

our $TOLERANCE = 0.0;

sub matrix_equals_matrix ($$) {
	trace_error("Both arguments must be a blessed Anorma::Data::Matrix::... object") 
		unless (&is_matrix($_[0]) && &is_matrix($_[1]));
	my ($A, $B) = @_;

	my $A_addr = refaddr($A);
	my $B_addr = refaddr($B);

	return 1 if ($A_addr == $B_addr);
	return undef if (is_null($A) || is_null($B));
	my $rows = $A->rows;
	my $columns = $A->columns;

	return undef if ($columns != $B->columns || $rows != $B->rows);

	my $epsilon = $TOLERANCE;
		
	my $row = $rows;
	
	while (--$row >= 0) {
		my $column = $columns;
		while (--$column >= 0) {
			my $x      = $A->get_quick( $row, $column);
			my $value  = $B->get_quick( $row, $column );
			my $diff   = abs( $value - $x);

			$diff = 0 if (($diff != $diff) && (($value != $value && $x != $x) || $value == $x)); 
			
			return undef if $diff > $epsilon;
		}

	}

	return 1;
}

sub matrix_equals_value ($$) {
	trace_error("First argument must be a blessed Anorman::Data::Matrix::... object") 
		unless (&is_matrix($_[0]));
	
	trace_error("Second argument is not a number") unless (looks_like_number($_[1]));
	my ($A, $value) = @_;

	my $A_addr = refaddr($A);
	return undef if (is_null($A));
	my $rows = $A->rows;
	my $columns = $A->columns;

	my $epsilon = $TOLERANCE;
		
	my $row = $rows;
	while (--$row >= 0) {
		my $column = $columns;
		while (--$column >= 0) {
			my $x    = $A->get_quick( $row, $column);
			my $diff = abs( $value - $x);

			$diff = 0 if (($diff != $diff) && (($value != $value && $x != $x) || $value == $x)); 
			return undef if $diff > $epsilon;
				
		}

	}

	return 1;
}

sub vector_equals_vector {
	trace_error("Both arguments must be a blessed Anorma::Data::Vector::... object") 
		unless (&is_vector($_[0]) && &is_vector($_[1]));
	my ($u, $v) = @_;

	my $u_addr = refaddr($u);
	my $v_addr = refaddr($v);

	return 1 if ($u_addr == $v_addr);
	return undef if (is_null($u) || is_null($v));
	my $size = $u->size;

	return undef if ($size != $v->size);

	my $epsilon = $TOLERANCE;
		
	my $i = $size;
	while (--$i >= 0) {
		my $x      = $u->get_quick( $i );
		my $value  = $v->get_quick( $i );
		my $diff   = abs( $value - $x);

		$diff = 0 if (($diff != $diff) && (($value != $value && $x != $x) || $value == $x)); 
		return undef if $diff > $epsilon;
	}

	return 1;

}

sub vector_equals_value {
	trace_error("First argument must be a blessed Anorman::Data::Vector::... object") 
		unless (&is_vector($_[0]));
	
	trace_error("Second argument is not a number") unless (looks_like_number($_[1]));
	my ($u, $value) = @_;

	my $u_addr = refaddr($u);
	return undef if (is_null($u));

	my $size    = $u->size;
	my $epsilon = $TOLERANCE;
		
	my $i = $size;
	while (--$i >= 0) {
		my $x    = $u->get_quick( $i );
		my $diff = abs( $value - $x);

		$diff = 0 if (($diff != $diff) && (($value != $value && $x != $x) || $value == $x)); 
		return undef if $diff > $epsilon;
				
	}

	return 1;
}

sub check_square {
	trace_error("Matrix must be square [ " . $_[0]->rows . " x " . $_[0]->columns . " ]") if $_[0]->rows != $_[0]->columns;
}

sub check_rectangular {
	trace_error("Matrix must be rectangular [ " . $_[0]->rows . " x " . $_[0]->columns . " ]") if $_[0]->rows < $_[0]->columns;
}

sub check_matrix {
	trace_error("Not a matrix") unless &is_matrix( $_[0] );
}

sub is_diagonal {
	my $A       = shift;
	my $epsilon = $TOLERANCE;
	my $rows    = $A->rows;
	my $columns = $A->columns;

	my $row = $rows;
	while ( --$row >= 0) {
		my $column = $columns;
		while ( --$column >= 0 ) {
			return undef if ($row != $column && !(abs($A->get_quick($row,$column)) <= $epsilon));
		}
	}
	return 1;
}

sub is_singular {
	return !(abs(Anorman::Data::LinAlg::det($_[0])) >= $TOLERANCE);
}

sub is_identity {
	my $A       = shift;
	my $epsilon = $TOLERANCE;
	my $rows    = $A->rows;
	my $columns = $A->columns;

	my $row = $rows;
	while ( --$row >= 0) {
		my $column = $columns;
		while ( --$column >= 0 ) {
			my $v = $A->get_quick($row,$column);

			if ( $row == $column ) {
				return undef if !(abs(1 -$v) < $epsilon);
			} 

			return undef if !(abs($v) <= $epsilon);
		}
	}
	return 1;
}

sub is_square {
	return $_[0]->rows == $_[0]->columns;
}

sub is_packed {
	return undef unless defined (my $class = blessed($_[0]));
	return $class =~ m/Anorman::Data::\w+::\w+Packed/;
}

sub is_matrix {
	return undef unless defined (my $class = blessed($_[0]));
	return $class->isa('Anorman::Data::Matrix'); 
}

sub is_vector {
	return undef unless defined (my $class = blessed($_[0]));
	return $class->isa('Anorman::Data::Vector');
}

sub check_vector {
	trace_error("Not a vector") unless &is_vector( $_[0] );
}

sub is_symmetric {
	&check_square( $_[0] );
	return &matrix_equals_matrix( $_[0], $_[0]->view_dice);
	
}

1;
