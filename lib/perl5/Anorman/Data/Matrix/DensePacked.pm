package Anorman::Data::Matrix::DensePacked;

use strict;
use parent 'Anorman::Data::Matrix';

use Anorman::Common qw(sniff_scalar trace_error);
use Anorman::Data::LinAlg::Property qw(is_packed);
use Anorman::Data::Vector::DensePacked;
use Anorman::Data::Matrix::SelectedDensePacked;

my %ASSIGN_DISPATCH = (
	'NUMBER'      => \&_assign_DensePackedMatrix_from_NUMBER,
	'2D_MATRIX'   => \&_assign_DensePackedMatrix_from_2D_MATRIX,
	'OBJECT'      => \&_assign_DensePackedMatrix_from_OBJECT,
	'OBJECT+CODE' => \&Anorman::Data::Matrix::_assign_Matrix_from_OBJECT_and_CODE,	
	'CODE'        => \&Anorman::Data::Matrix::_assign_Matrix_from_CODE
);


sub new {
	my $that = shift;
	
	trace_error("Wrong number of arguments") if (@_ != 1 && @_ != 2 && @_ != 7);

	my $class = ref $that || $that;
	my $self  = $class->new_matrix_object();

	my ( $rows,
             $columns,
             $row_zero,
             $column_zero,
             $row_stride,
             $column_stride
           );


	if (@_ == 1) {
		my $type = sniff_scalar($_[0]);
		if ($type eq '2D_MATRIX') {
			my $M    = shift;
			$rows    = @{ $M };
			$columns = @{ $M} == 0 ? 0 : @{ $M->[0] };
			
			$self->_setup( $rows, $columns);
			$self->_set_elements_addr( $self->_alloc_elements( $rows * $columns ) );
			$self->_assign_DensePackedMatrix_from_2D_MATRIX( $M );
		} else {
			$self->_error("Argument error. Input is not a matrix reference");
		}

	} elsif (@_ == 2) {
		# construct new empty matrix
	    	my ($rows, $columns) = @_;

		$self->_setup($rows, $columns);
		$self->_set_elements_addr( $self->_alloc_elements( $rows * $columns ) );
	} else {
		# set up view
		my $other;

		($rows, $columns, $other, $row_zero, $column_zero, $row_stride, $column_stride) = @_;

		$self->_setup($rows, $columns, $row_zero, $column_zero, $row_stride, $column_stride);
		
                # assign address pointer to view
		$self->_set_elements_addr( $other->_get_elements_addr );
	}

	return $self;
}

sub assign {
	my $self = shift;
	my $type = sniff_scalar($_[0]);

	# pass to parent class if matrices are different types
	if ($type eq 'OBJECT') {
		$self->_check_shape( $_[0] );
		return $self->SUPER::assign($_[0]) if ref $_[0] ne 'Anorman::Data::Matrix::DensePacked';
	}

	# determine type of data passed
	if (@_ == 2) {
		my $arg2_type = sniff_scalar( $_[1] );
		unless ($type eq 'OBJECT' && $arg2_type eq 'CODE') {
			$self->_error("Invalid arguments. Argument 2 is not a CODE block ($type,$arg2_type)");
		}
		$type = 'OBJECT+CODE';
	}

	# execute from dispatch table
	$ASSIGN_DISPATCH{ $type }->( $self, @_ );

	return $self;
}

sub like_vector {
	my $self = shift;
	
	if (@_ == 1) {
		return Anorman::Data::Vector::DensePacked->new($_[0])
	} else {
		trace_error("Wrong number of arguments");
	}
}

sub _plus_assign {
	warn "COCK!\n";
}

sub _like_vector {
	my $self    = shift;
        return Anorman::Data::Vector::DensePacked->new($_[0], $self, $_[1], $_[2]);
}

sub _view_selection_like {
	my $self = shift;
	return Anorman::Data::Matrix::SelectedDensePacked->new( $self->_get_elements_addr, $_[0], $_[1], 0 );
}

sub _have_shared_cells_raw {
	my ($self, $other) = @_;

	return undef unless (is_packed($self) && is_packed($other));
	return $self->_get_elements_addr == $other->_get_elements_addr;
}

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Data::Matrix::DensePacked',
		ENABLE    => AUTOWRAP =>
		LIBS      => '-L' . $Anorman::Common::AN_SRC_DIR . '/lib -lmatrix',
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include'

           );

use Inline C => <<'END_OF_C_CODE';

#include "data.h"
#include "matrix.h"
#include "perl2c.h"

#include "../lib/matrix.c"

SV* _alloc_elements( SV*, UV );

SV*  _get_elements_addr( SV* );
void _set_elements_addr( SV*, SV* );

void static  show_struct( Matrix* );

/* object constructors */
SV* new_matrix_object( SV* sv_class_name ) {
    printf("NEW\n");
    Matrix* m;
    SV* self;

    /* allocate struct memory */
    Newxz(m, 1, Matrix);

    const char* class_name = SvPV_nolen( sv_class_name );
    BLESS_STRUCT( m, self, class_name );

    return self;
}

/* clone a matrix object by making a copy of the underlying struct */
SV* clone( SV* self ) {
    printf("CLONE\n");
    SV_2STRUCT( self, Matrix, m );

    Matrix* n;
    SV* clone;

    Newx( n, 1, Matrix );
    const char* class_name = sv_reftype( SvRV( self ), TRUE );

    n = c_m_alloc_from_matrix( m, 0, 0, m->rows, m->columns );

    BLESS_STRUCT( n, clone, class_name ); 

    return clone; 
}

/* object accessors (for perl calls) */
UV rows(SV* self) {
    return (UV) ((Matrix*)SvIV(SvRV(self)))->rows;
}

UV columns(SV* self) {
    return (UV) ((Matrix*)SvIV(SvRV(self)))->columns;
}

UV row_zero(SV* self) {
    return (UV) ((Matrix*)SvIV(SvRV(self)))->row_zero;
}

UV column_zero(SV* self) {
    return (UV) ((Matrix*)SvIV(SvRV(self)))->column_zero;
}

IV row_stride(SV* self) {
    return (IV) ((Matrix*)SvIV(SvRV(self)))->row_stride;
}

IV column_stride(SV* self) {
    return (IV) ((Matrix*)SvIV(SvRV(self)))->column_stride;
}

UV _is_noview (SV* self) {
    return (UV) (((Matrix*)SvIV(SvRV(self)))->view_flag == FALSE);
}


NV get_quick(SV* self, IV row, IV column) {
    /* NOTE:  Assumes that index is always
       is within array boundary */
    SV_2STRUCT( self, Matrix, m );
    
    return (NV) c_m_get_quick( m, (size_t) row, (size_t) column );
}

void set_quick(SV* self, IV row, IV column, NV value) {
    SV_2STRUCT( self, Matrix, m );

    c_m_set_quick( m, (size_t) row, (size_t) column, (double) value );
}

NV _index( SV* self, IV i, IV j ) {
    SV_2STRUCT( self, Matrix, m );
    return (NV) (m->row_zero + i * m->row_stride + m->column_zero + j * m->column_stride);
}

NV sum( SV* self ) {
    SV_2STRUCT( self, Matrix, m );

    return (NV) c_m_sum( m );
}

/* object initializors */
void _setup ( SV* self, ... ) {
    printf("SETUP\n");
    Inline_Stack_Vars;
    
    if ( items != 3 && items != 7) {
        croak("_setup::Wrong number of arguments (%d)", (int) Inline_Stack_Items );
    }

    SV_2STRUCT( self, Matrix, m );

    m->rows    = (size_t) SvIV( Inline_Stack_Item(1) );
    m->columns = (size_t) SvIV( Inline_Stack_Item(2) );
    
    if ( items == 7 ) {
        m->row_zero      = (size_t) SvIV( Inline_Stack_Item(3) );
        m->column_zero   = (size_t) SvIV( Inline_Stack_Item(4) );
        m->row_stride    = (size_t) SvIV( Inline_Stack_Item(5) );
        m->column_stride = (size_t) SvIV( Inline_Stack_Item(6) );
        m->view_flag     = 1;
    } else {
        m->row_zero      = 0;
        m->column_zero   = 0;
        m->row_stride    = (size_t) m->columns;
        m->column_stride = 1;
        m->view_flag     = 0;
   }
}

SV* _alloc_elements( SV* self, UV num_elems ) {
    SV_2STRUCT( self, Matrix, m );

    if ( m->elements != NULL ) {
        croak("Memory already allocated");
    }

    ALLOC_ELEMS( num_elems, sv_addr );
        
    return sv_addr;
}


/* elements pointer address manipulation */
SV* _get_elements_addr (SV* self) {

    SV_2STRUCT( self, Matrix, m );
    PTR_2SVADDR( m->elements, sv_addr );

    return sv_addr;
}

void _set_elements_addr (SV* self, SV* sv_addr ) {

    SVADDR_2PTR( sv_addr, elems_ptr );
    SV_2STRUCT( self, Matrix, m );

    if (m->elements == NULL) {
        m->elements = elems_ptr;
    } else {
        PerlIO_printf( PerlIO_stderr(), "Cannot assign (%p) to an already assigned pointer (%p)\n", elems_ptr, m->elements );
    }   
}

/* data assignment functions */
void _assign_DensePackedMatrix_from_2D_MATRIX(SV* self, AV* array_of_arrays ) {
    SV_2MATRIX( self, m );

    /* verify number of rows */
    size_t rows = (size_t) av_len( array_of_arrays ) + 1;
    
    if (rows != m->rows) {
        croak("Cannot assign AoA to matrix object: must have %lu rows\n", m->rows );
        my_exit(1);
    }
        
    size_t     i = m->columns * (rows - 1);
    double* elem = m->elements;

    int row = (int) rows;
    while( --row >= 0 ) {

	/* fetch a row from AoA and convert to AV* */
        AV* current_row = (AV*) SvIV( *av_fetch( array_of_arrays, row, 0) );
        size_t columns  = (size_t) av_len( current_row ) + 1;

        /* verify length */
        if (columns != m->columns) {   
            PerlIO_printf( PerlIO_stderr(), "Must have same number of colunms (%lu) but was %lu\n", m->columns, columns );
            my_exit(1);
        }
         
	/* fill elements */
        size_t j;
        for (j = 0; j < columns; j++) {
            double value = (double) SvNV( *av_fetch( current_row, j, 0) );
            elem[ i + j ] = value;
        }

        i -= m->columns;  
    }
}

void _assign_DensePackedMatrix_from_OBJECT ( SV* self, SV* other ) {
    SV_2STRUCT( self, Matrix, A );
    SV_2STRUCT( other, Matrix, B );

    printf("LOW-LEVEL ASSIGN\n");

    if (A->elements == B->elements) {
        printf("SAME. Nothing to do\n");
        return;
    }

    dSP;

    ENTER;
    PUSHMARK( SP );
    XPUSHs( self );
    XPUSHs( other );
    PUTBACK;
       
    call_method("Anorman::Data::Matrix::_check_shape", G_VOID );

    LEAVE;

    /* straight up memcopy if neither marix is a view */
    if (!A->view_flag && !B->view_flag) {
	printf("MEMCPY\n");
        Copy( B->elements, A->elements, (UV) (A->rows * A->columns), double );
        return; 
    }

    printf ("ELEMENT COPY\n");
    c_mm_copy( A, B );
}

void _assign_DensePackedMatrix_from_OBJECT_and_CODE ( SV* self, SV* other, SV* function ) {
	SV_2STRUCT( self, Matrix, A );
	SV_2STRUCT( other, Matrix, B );

	
	
}

void _assign_DensePackedMatrix_from_NUMBER ( SV* self, NV value ) {
    printf("ASSIGN CONSTANT\n");
    SV_2STRUCT( self, Matrix, m );

    c_m_set_all( m, (double) value );
}

void _mult_matrix_matrix ( SV* self, SV* other, SV* result, SV* sv_alpha, SV* sv_beta ) {

    /* call parent method if data is not in packed format */
    if ( strEQ( sv_reftype( SvRV(self), TRUE), sv_reftype( SvRV(other), TRUE) ) == FALSE ) {

        dSP;

        ENTER;
        PUSHMARK( SP );
        XPUSHs( self );
        XPUSHs( other );
        XPUSHs( result );
        XPUSHs( sv_alpha );
        XPUSHs( sv_beta );
        PUTBACK;
       
        call_method("Anorman::Data::Matrix::_mult_matrix_matrix", G_VOID );

        LEAVE;

        return;
    } 

    SV_2STRUCT( self,   Matrix, A );	
    SV_2STRUCT( other,  Matrix, B );
    SV_2STRUCT( result, Matrix, C );

    double alpha = (double) SvNV( sv_alpha );
    double beta  = (double) SvNV( sv_beta );

    c_mm_mult( A, B, C, alpha, beta );
}

void _mult_matrix_vector ( SV* self, SV* other, SV* result, SV* sv_alpha, SV* sv_beta ) {

    /* call parent method if matrix is not packed */
    if ( strEQ( sv_reftype( SvRV(self), TRUE), sv_reftype( SvRV(other), TRUE) ) == FALSE ) {

        dSP;

        ENTER;
        PUSHMARK( SP );
        XPUSHs( self );
        XPUSHs( other );
        XPUSHs( result );
        XPUSHs( sv_alpha );
        XPUSHs( sv_beta );
        PUTBACK;
       
        call_method("Anorman::Data::Matrix::_mult_matrix_vector", G_VOID );

        LEAVE;

        return;
    } 

    SV_2STRUCT( self,   Matrix, A );	
    SV_2STRUCT( other,  Vector, y );
    SV_2STRUCT( result, Vector, z );

    double alpha = (double) SvNV( sv_alpha );
    double beta  = (double) SvNV( sv_beta );

    c_mv_mult( A, y, z, alpha, beta );
} 

SV* _v_dice( SV* self ) {
    SV_2MATRIX( self, m );
    int tmp;
    
    tmp = m->rows;       m->rows = m->columns;             m->columns = tmp;
    tmp = m->row_stride; m->row_stride = m->column_stride; m->column_stride = tmp;
    tmp = m->row_zero;   m->row_zero = m->column_zero;     m->column_zero = tmp;

    m->view_flag = 1;
    
    SvREFCNT_inc( self );
    return self;
}

SV* _v_part( SV* self, UV row, UV column, UV height, UV width ) {
    SV_2STRUCT( self, Matrix, m );

    c_m_part( m, row, column, height, width );

    SvREFCNT_inc( self );	
    return self;
}

/* object destruction */
void DESTROY(SV* self) {
    printf("DESTROY\n");
    SV_2STRUCT( self, Matrix, m );

    c_m_free( m );
}

END_OF_C_CODE

1;
