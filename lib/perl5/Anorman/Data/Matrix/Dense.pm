package Anorman::Data::Matrix::Dense;

use strict;
use warnings;

use parent qw(Anorman::Data::Matrix::Abstract Anorman::Data::Matrix);

use Anorman::Common qw(trace_error sniff_scalar);
use Anorman::Data::Vector::Dense;
use Anorman::Data::Matrix::SelectedDense;
use Anorman::Data::LinAlg::Property qw( is_matrix );
use Anorman::Math::Functions;

my $F = Anorman::Math::Functions->new;

my %ASSIGN_DISPATCH = (
	'NUMBER'        => \&_assign_DenseMatrix_from_NUMBER,
	'2D_MATRIX'     => \&_assign_DenseMatrix_from_2D_MATRIX,
	'OBJECT'        => \&_assign_DenseMatrix_from_OBJECT,
	'OBJECT+CODE'	=> \&_assign_DenseMatrix_from_OBJECT_and_CODE,
	'CODE'          => \&_assign_DenseMatrix_from_CODE
);


sub new {
	my $that  = shift;
	my $class = ref $that || $that;
	my $self  = $class->SUPER::new();

	if (@_ != 1 && @_ != 2 && @_ != 7) {
		trace_error("Wrong number of arguments");
	}

	if (@_ == 1) {
		$self->_new_from_AoA(@_);
	} else {
		$self->_new_from_dims(@_);
	}
	
	return $self;
}

sub _new_from_AoA {
	my $self = shift;

	trace_error("Not a reference to Array of Arrays\n" )
		if sniff_scalar($_[0]) ne '2D_MATRIX';

	my $rows    = @{ $_[0] };
	my $columns = @{ $_[0] } == 0 ? 0 : @{ $_[0]->[0] };

	$self->_new_from_dims( $rows, $columns );
	$self->_assign_DenseMatrix_from_2D_MATRIX( $_[0] );
}

sub _new_from_dims {
	my $self = shift;

	my ( $rows,
             $columns,
	     $elements,
             $row_zero,
             $column_zero,
             $row_stride,
             $column_stride
           ) = @_;

	# Allocate a fresh matrix
	if (@_ == 2) {
		$self->_setup($rows, $columns);
		$self->{'_ELEMS'} = [ (0) x ($rows * $columns) ];

	# Set up view on existing matrix elements
	} else {  
		$self->_setup( $rows, $columns, $row_zero, $column_zero, $row_stride, $column_stride );

		trace_error("Invalid data elements. Must be an ARRAY reference")
			unless ref($elements) eq 'ARRAY';

		$self->{'_ELEMS'} = $elements;
		$self->{'_VIEW'}  = 1;
	}
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
	$ASSIGN_DISPATCH{ $type }->( $self, @_ );# || $self->_error("Assigment error");

	return $self;
}

sub set_quick {
	my ($s, $r, $c, $value) = @_;

	$s->{'_ELEMS'}->[ $s->{'r0'} + $r * $s->{'rstride'} + $s->{'c0'} + $c * $s->{'cstride'} ] = $value;
}

sub get_quick {
	my ($s, $r, $c) = @_;

	return $s->{'_ELEMS'}->[ $s->{'r0'} + $r * $s->{'rstride'} + $s->{'c0'} + $c * $s->{'cstride'} ];
}

sub like {
	my $self  = shift;
	my ($rows, $columns);

	if (@_ == 2) {
		($rows, $columns) = @_;
	} else {
		$rows    = $self->{'rows'};
		$columns = $self->{'columns'};
	}

	return $self->new($rows, $columns);
}

sub sum {
	my $self = shift;
	
	my $elems = $self->{'_ELEMS'};
	my $index = $self->_index(0,0);
	my $cs    = $self->{'cstride'};
	my $rs    = $self->{'rstride'};
	
	my $sum   = 0.0;

	my $row = $self->{'rows'};
	while ( --$row >=0 ) {
		my $i = $index;
		my $column = $self->{'columns'};
		while ( --$column >= 0 ) {
			$sum += $elems->[ $i ];
			$i   += $cs;
		}

		$index += $rs
	}

	return $sum;
}

sub _add_assign { is_matrix($_[1]) ? $_[0]->assign($_[1], $F->plus ) : $_[0]->assign( $F->bind_arg2( $F->plus , $_[1] ) ) } 
sub _sub_assign { is_matrix($_[1]) ? $_[0]->assign($_[1], $F->minus) : $_[0]->assign( $F->bind_arg2( $F->minus, $_[1] ) ) } 
sub _mul_assign { is_matrix($_[1]) ? $_[0]->assign($_[1], $F->mult ) : $_[0]->assign( $F->bind_arg2( $F->mult , $_[1] ) ) }
sub _div_assign { is_matrix($_[1]) ? $_[0]->assign($_[1], $F->div  ) : $_[0]->assign( $F->bind_arg2( $F->div  , $_[1] ) ) }

sub _index {
	my ($s, $r, $c) = @_;
	return ($s->{'r0'} + $r * $s->{'rstride'} + $s->{'c0'} + $c * $s->{'cstride'});
}

sub like_vector {
	my $self = shift;
	
	return Anorman::Data::Vector::Dense->new($_[0])
}

sub _like_vector {
	my $self  = shift;
	my ($size, $zero, $stride) = @_;

	return Anorman::Data::Vector::Dense->new($size, $self->{'_ELEMS'}, $zero, $stride)
}

sub _assign_DenseMatrix_from_2D_MATRIX {
	# assign array of arrays as matrix (copy into single indexed array structure)

	my ($self, $M) = @_;

	if ($self->_is_noview) {
		trace_error("Must have same number of rows (" . $self->rows . ") as matrix object. Rows=" . @{ $M } ) 
			if @{ $M } != $self->{'rows'};

		my $i   = $self->{'columns'} * ($self->{'rows'} - 1);
		my $row = $self->{'rows'};

		while (--$row >= 0) { 
			my $row_ref = $M->[ $row ];

			# Column length sanity check
			trace_error("Column length error") if (@{ $row_ref } != $self->columns );
			
			splice (@{ $self->{'_ELEMS'} }, $i, $self->{'columns'}, @{ $row_ref });
			
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

	$self->check_shape( $other );

	if ($self->_is_noview && $other->_is_noview) {
		@{ $self->{'_ELEMS'} } = @{ $other->{'_ELEMS'} };
		return 1;
	}

	if ($self->_have_shared_cells( $other )) {
		my $copy = $other->copy;

		$other = $copy;
	}

	my $A_elems   =  $self->{'_ELEMS'};
	my $B_elems   = $other->{'_ELEMS'};
	my $A_cstride =  $self->{'cstride'};
	my $B_cstride = $other->{'cstride'};
	my $A_rstride =  $self->{'rstride'};
	my $B_rstride = $other->{'rstride'};

	my $A_index   =  $self->_index(0,0);
	my $B_index   = $other->_index(0,0);
	
	my $row = $self->{'rows'};
	while ( --$row >= 0) {

		my $i      = $A_index;
		my $j      = $B_index;
		my $column = $self->{'columns'};
		while ( --$column >= 0 ) {
			$A_elems->[ $i ] = $B_elems->[ $j ];

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

	$self->check_shape( $other );

	my $A_elems   =  $self->{'_ELEMS'};
	my $B_elems   = $other->{'_ELEMS'};
	my $A_cstride =  $self->{'cstride'};
	my $B_cstride = $other->{'cstride'};
	my $A_rstride =  $self->{'rstride'};
	my $B_rstride = $other->{'rstride'};

	my $A_index   =  $self->_index(0,0);
	my $B_index   = $other->_index(0,0);
	
	my $row = $self->{'rows'};
	while ( --$row >= 0) {

		my $i      = $A_index;
		my $j      = $B_index;
		my $column = $self->{'columns'};
		while ( --$column >= 0 ) {
			$A_elems->[ $i ] = $CODE->( $A_elems->[ $i ], $B_elems->[ $j ] );

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
	if ($_[1]->isa('Anorman::Data::Matrix::Dense')
		||$_[1]->isa('Anorman::Data::Matrix::SelectedDense'))
	{
		return ($_[0]->{'_ELEMS'} eq $_[1]->{'_ELEMS'});
	}
}

sub _view_selection_like {
	my $self = shift;
	my ($roffsets, $coffsets) = @_;
	return Anorman::Data::Matrix::SelectedDense->new( $self->{'_ELEMS'}, $roffsets, $coffsets, 0 );
}


# Dumper the internal hash. Good for debugging
sub _dump {
	my $elems = defined $_[0]->{'_ELEMS'} ? $_[0]->{'_ELEMS'} : 'NULL';
	my ($type)  = ref ($_[0]) =~ /\:\:(\w+)$/;
	printf STDERR ("%s Matrix dump: HASH(0x%p)\n", $type, $_[0]);
	printf STDERR ("\trows\t\t: %lu\n",    $_[0]->{'rows'}     );
    	printf STDERR ("\tcols\t\t: %lu\n",    $_[0]->{'columns'}  );
    	printf STDERR ("\tr0\t\t: %lu\n",      $_[0]->{'r0'}       );
    	printf STDERR ("\tc0\t\t: %lu\n",      $_[0]->{'c0'}       );
    	printf STDERR ("\trstride\t\t: %lu\n", $_[0]->{'rstride'}  );
    	printf STDERR ("\tcstride\t\t: %lu\n", $_[0]->{'cstride'}  );

	if ($elems ne 'NULL') {
		printf STDERR ("\telements[%lu]\t: %s\n",  scalar @{ $elems }, $elems );
	} else {
		printf STDERR ("\telements[%lu]\t: %s\n",  0,$elems );

	}
    	printf STDERR ("\tview\t\t: %i\n\n",   $_[0]->{'_VIEW'}    );

}

1;
