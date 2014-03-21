package Anorman::Data::Matrix::DensePacked;

use strict;

use Anorman::Common qw(sniff_scalar trace_error);
use Anorman::Data::LinAlg::Property qw(is_packed);
use Anorman::Data::Vector::DensePacked;
use Anorman::Data::Matrix::SelectedDensePacked;


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
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include'

           );

use Inline C => <<'END_OF_C_CODE';

#include <limits.h>
#include "data.h"
#include "matrix.h"
#include "perl2c.h"
#include "error.h"

#include "../lib/matrix.c"

SV* _alloc_elements( SV*, UV );
SV*  _get_elements_addr( SV* );
void _set_elements_addr( SV*, SV* );

void static  show_struct( Matrix* );

/* object constructors */
SV* new( SV* sv_class_name ) {
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
    SV_2STRUCT( self, Matrix, m );

    Matrix* n;
    SV* clone;

    /* clone struct */
    Newx( n, 1, Matrix );
    StructCopy( m, n, Matrix );

    /* protect data elements from freeing */
    n->view_flag = 1;

    /* make a blessed perl object */
    const char* class_name = sv_reftype( SvRV( self ), TRUE );
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

UV _column_zero(SV* self) {
    return (UV) ((Matrix*)SvIV(SvRV(self)))->column_zero;
}

IV _row_stride(SV* self) {
    return (IV) ((Matrix*)SvIV(SvRV(self)))->row_stride;
}

IV _column_stride(SV* self) {
    return (IV) ((Matrix*)SvIV(SvRV(self)))->column_stride;
}

UV _is_vieww (SV* self) {
    return (UV) ((Matrix*)SViV(SvRV(self)))->view_flag
}

UV _is_noview (SV* self) {
    return (UV) (((Matrix*)SvIV(SvRV(self)))->view_flag == 0);
}

UV size (SV* self) {
    SV_2STRUCT( self, m );
    
   return (UV) m->rows * m->columns;
}

UV _row_rank (SV* self, UV rank) {
    SV_2STRUCT( self, m);

    return m->row_zero + rank * * m->row_stride;
}

UV _row_offset (SV* self, UV index ) {
    return index;
}

UV _column_rank (SV* self, UV rank) {
    SV_2STRUCT( self, m);

    return m->column_zero + rank * * m->column_stride;
}

UV _column_offset (SV* self, UV index ) {
    return index;
}

NV get_quick(SV* self, UV row, UV column) {
    SV_2STRUCT( self, Matrix, m );
    
    return (NV) c_m_get_quick( m, (size_t) row, (size_t) column );
}

void set_quick(SV* self, UV row, UV column, NV value) {
    SV_2STRUCT( self, Matrix, m );

    c_m_set_quick( m, (size_t) row, (size_t) column, (double) value );
}

NV _index( SV* self, UV i, UV j ) {
    SV_2STRUCT( self, Matrix, m );

    return (NV)(_row_offset( self, _row_rank(self, i)))
                   + (_column_offset( self, _column_rank(self, j)));
}

UV _elements (SV* self) {

    SV_2STRUCT( self, Matrix, m );
    PTR_2SVADDR( m->elements, sv_addr );

    return sv_addr;
}

/* object initializors */

void _setup ( SV* self, ... ) {
    Inline_Stack_Vars;
    
    SV_2STRUCT( self, Matrix, m );

    m->rows    = (size_t) SvUV( Inline_Stack_Item(1) );
    m->columns = (size_t) SvUV( Inline_Stack_Item(2) );
    
    if ( items == 7 ) {
        m->row_zero      = (size_t) SvUV( Inline_Stack_Item(3) );
        m->column_zero   = (size_t) SvUV( Inline_Stack_Item(4) );
        m->row_stride    = (size_t) SvUV( Inline_Stack_Item(5) );
        m->column_stride = (size_t) SvUV( Inline_Stack_Item(6) );
        m->view_flag     = 1;
    } else {
        m->row_zero      = 0;
        m->column_zero   = 0;
        m->row_stride    = (size_t) m->columns;
        m->column_stride = 1;
        m->view_flag     = 0;
   }

    if ((rows * columns) > LONG_MAX) {
        c_error("Matrix is too large", C_EINVAL );
    }
}

SV* _alloc_elements( SV* self, UV num_elems ) {
    SV_2STRUCT( self, Matrix, m );

    if ( m->elements ) {
        croak("Memory already allocated");
    }

    ALLOC_ELEMS( num_elems, sv_addr );
        
    return sv_addr;
}


/* elements pointer address manipulation */



/* data assignment functions */
void _assign_DensePackedMatrix_from_2D_MATRIX(SV* self, AV* array_of_arrays ) {
    SV_2STRUCT( self, Matrix, m );

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

    if (A->elements == B->elements) {
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
        Copy( B->elements, A->elements, (UV) (A->rows * A->columns), double );
        return; 
    }

    c_mm_copy( A, B );
}

void _assign_DensePackedMatrix_from_OBJECT_and_CODE ( SV* self, SV* other, SV* function ) {
	SV_2STRUCT( self, Matrix, A );
	SV_2STRUCT( other, Matrix, B );

	
	
}

void _assign_DensePackedMatrix_from_NUMBER ( SV* self, NV value ) {
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
    SV_2STRUCT( self, Matrix, m );
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
    SV_2STRUCT( self, Matrix, m );

    c_m_free( m );
}

END_OF_C_CODE

1;

