package Anorman::Data::Matrix::DensePacked;

use strict;
use warnings;

use parent qw(Anorman::Data::Matrix::Abstract Anorman::Data::Matrix);

use Anorman::Common qw(sniff_scalar trace_error);
use Anorman::Data::LinAlg::Property qw(is_packed);
use Anorman::Data::Vector::DensePacked;
use Anorman::Data::Matrix::SelectedDensePacked;

my %ASSIGN_DISPATCH = (
	'NUMBER'      => \&_assign_DensePackedMatrix_from_NUMBER,
	'2D_MATRIX'   => \&_assign_DensePackedMatrix_from_2D_MATRIX,
	'OBJECT'      => \&_assign_DensePackedMatrix_from_OBJECT,
	'OBJECT+CODE' => \&Anorman::Data::Matrix::_assign_Matrix_from_OBJECT_and_CODE,	
	'CODE'        => \&_assign_DensePackedMatrix_from_CODE
);

sub new {
	my $that = shift;
	
	trace_error("Wrong number of arguments") if (@_ != 1 && @_ != 2 && @_ != 7);

	my $class = ref $that || $that;
	my $self  = $class->_bless_matrix_struct;

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
	$self->_assign_DensePackedMatrix_from_2D_MATRIX( $_[0] );
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
		$self->_set_elements( $self->_allocate_elements( $rows * $columns ));

	# Set up view on existing matrix elements
	} else {  
		$self->_setup( $rows, $columns, $row_zero, $column_zero, $row_stride, $column_stride );

		trace_error("Invalid data elements. Must be an unsiged integer")
			unless sniff_scalar($elements) eq 'NUMBER';

		$self->_set_elements( $elements );
		$self->_set_view( 1 );
	}
}

sub assign {
	my $self = shift;
	my $type = sniff_scalar($_[0]);

	# pass to parent class if matrices are different types
	if ($type eq 'OBJECT') {
		$self->check_shape( $_[0] );
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
        return Anorman::Data::Vector::DensePacked->new($_[0], $self->_elements, $_[1], $_[2]);
}

sub _view_selection_like {
	my $self = shift;
	return Anorman::Data::Matrix::SelectedDensePacked->new( $self->_elements, $_[0], $_[1], 0 );
}

sub _have_shared_cells_raw {
	my ($self, $other) = @_;

	return undef unless (is_packed($self) && is_packed($other));
	return $self->_elements == $other->_elements;
}

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Data::Matrix::DensePacked',
		ENABLE    => AUTOWRAP =>
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include'

           );

use Inline C => <<'END_OF_C_CODE';

#include <stdio.h>
#include "data.h"
#include "matrix.h"
#include "perl2c.h"
#include "error.h"
#include "../lib/matrix.c"

/*===========================================================================
 Abstract matrix functions
 ============================================================================*/

/* object constructors */
SV* _bless_matrix_struct( SV* sv_class_name ) {
    Matrix* m;
    SV* self;

    /* allocate struct memory */
    Newxz(m, 1, Matrix);

    const char* class_name = SvPV_nolen( sv_class_name );
    BLESS_STRUCT( m, self, class_name );

    return self;
}

/* clone a matrix object by making and blessing a copy of the underlying struct */
SV* _clone_self( SV* self ) {
    SV_2STRUCT( self, Matrix, m );

    Matrix* n;
    SV* clone;

    /* clone struct */
    Newx( n, 1, Matrix );
    StructCopy( m, n, Matrix );

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

UV _row_zero(SV* self) {
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

UV _is_view (SV* self) {
    return (UV) ((Matrix*)SvIV(SvRV(self)))->view_flag;
}

UV _is_noview (SV* self) {
    return (UV) (((Matrix*)SvIV(SvRV(self)))->view_flag == 0);
}

void _set_view(SV* self, IV flag) {
    ((Matrix*)SvIV(SvRV(self)))->view_flag = (int) flag;
}

UV size (SV* self) {
    SV_2STRUCT( self, Matrix, m );
    
   return (UV) (m->rows * m->columns);
}

UV _row_rank (SV* self, UV rank) {
    SV_2STRUCT( self, Matrix, m);

    return m->row_zero + (size_t) rank * m->row_stride;
}

UV _row_offset (SV* self, UV index ) {
    return index;
}

UV _column_rank (SV* self, UV rank) {
    SV_2STRUCT( self, Matrix, m);

    return m->column_zero + (size_t) rank * m->column_stride;
}

UV _column_offset (SV* self, UV index ) {
    return index;
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

    if ((m->rows * m->columns) > MAX_NUM_ELEMENTS) {
        C_ERROR_VOID("Matrix is too large", C_EINVAL );
    }
}


/* Consistency checks */

void _check_row ( SV* self, IV index ) {
    SV_2STRUCT( self, Matrix, m );

    if (index < 0 || index >= (IV) m->rows) {
        char reason[80];
        sprintf(reason, "Row number (%li) is out of bounds", index);
        C_ERROR_VOID( reason, C_EINVAL );
    }
}

void _check_column ( SV* self, IV index ) {
    SV_2STRUCT( self, Matrix, m );

    if (index < 0 || index >= (IV) m->columns) {
        char reason[80];
        sprintf(reason, "Column number (%li) is out of bounds", index);
        C_ERROR_VOID( reason , C_EINVAL );
    }
}

void _check_box ( SV* self, IV row, IV column, IV width, IV height )  {
    SV_2STRUCT( self, Matrix, m );
    if (column < 0 || width < 0 || column + width > (IV) m->columns 
        || row < 0 || height < 0 || row + height > (IV) m->rows)
    {
        char reason[80];
        sprintf( reason, "Out of bounds: [ %lu x %lu ], column: %li row: %li, width: %li, height: %li",
                 m->rows, m->columns, column, row, width, height);
        C_ERROR_VOID( reason, C_EINVAL );

    }
}
 

/* In-place mutators */

SV* _v_dice( SV* self ) {
    SV_2STRUCT( self, Matrix, m );
    int tmp;
    
    tmp = m->rows;       m->rows = m->columns;             m->columns = tmp;
    tmp = m->row_stride; m->row_stride = m->column_stride; m->column_stride = tmp;
    tmp = m->row_zero;   m->row_zero = m->column_zero;     m->column_zero = tmp;

    SvREFCNT_inc( self );
    return self;
}

SV* _v_part( SV* self, UV row, UV column, UV height, UV width ) {
    SV_2STRUCT( self, Matrix, m );

    c_m_part( m, row, column, height, width );

    SvREFCNT_inc( self );	
    return self;
}

/* Matrix destruction */
void DESTROY(SV* self) {
    SV_2STRUCT( self, Matrix, m );

    c_m_free( m );
}

void _dump( SV* self ) {
    SV_2STRUCT( self, Matrix, m );

    c_m_show_struct( m );
}


/*===========================================================================
 DenseMatrix Functions
 ============================================================================*/  

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

    return (NV) (m->row_zero + i * m->row_stride + m->column_zero + j * m->column_stride);
}

SV* _elements (SV* self) {

    SV_2STRUCT( self, Matrix, m );
    PTR_2SVADDR( m->elements, sv_addr );

    return sv_addr;
}

void _set_elements (SV* self, SV* sv_addr ) {

    SVADDR_2PTR( sv_addr, elems_ptr );
    SV_2STRUCT( self, Matrix, m );

    if (!m->elements) {
        m->elements = elems_ptr;
    } else {
        C_ERROR_VOID("This matrix was already assigned an elements pointer", C_EINVAL );
    }   
}

SV* _allocate_elements( SV* self, UV num_elems ) {
    SV_2STRUCT( self, Matrix, m );

    if ( m->elements ) {
        C_ERROR_NULL("Memory already allocated", C_EINVAL);
    }

    ALLOC_ELEMS( num_elems, sv_addr );
        
    return sv_addr;
}
SV* _sub_assign( SV* self, SV* other, SV* swap ) {
    SV_2STRUCT( self, Matrix, u );

    if (!SvROK(other)) {
        c_m_add_constant( u, -( SvNV( other )));
    } else {
        SV_2STRUCT( other, Matrix, v );
        c_mm_sub( u, v );
    }
    
    SvREFCNT_inc( self );
    return self;
}

SV* _add_assign( SV* self, SV* other, SV* swap ) {
    SV_2STRUCT( self, Matrix, u );

    if (!SvROK(other)) {
        c_m_add_constant( u, SvNV( other ));
    } else {
        SV_2STRUCT( other, Matrix, v );
        c_mm_add( u, v );
    }

    SvREFCNT_inc( self );
    return self;
}

SV* _div_assign( SV* self, SV* other, SV* swap ) {
    SV_2STRUCT( self, Matrix, u );

    if (!SvROK(other)) {
        c_m_scale( u, 1 / SvNV( other ) );
    } else {
        SV_2STRUCT( other, Matrix, v );
        c_mm_div( u, v );
    }

    SvREFCNT_inc( self );
    return self;
}

SV* _mul_assign( SV* self, SV* other, SV* swap ) {
    SV_2STRUCT( self, Matrix, u );

    if (!SvROK(other)) {
        c_m_scale( u, SvNV( other ) );
    } else {
        SV_2STRUCT( other, Matrix, v );
        c_mm_mul( u, v );
    }

    SvREFCNT_inc( self );
    return self;
}

/* data assignment functions */
void _assign_DensePackedMatrix_from_2D_MATRIX(SV* self, AV* array_of_arrays ) {
    SV_2STRUCT( self, Matrix, m );

    /* verify number of rows */
    size_t rows = (size_t) av_len( array_of_arrays ) + 1;
    
    if (rows != m->rows) {
        char reason[80]; 
        sprintf( reason, "Cannot assign AoA to matrix object: must have %lu rows\n", m->rows);
        C_ERROR_VOID( reason, C_EINVAL );
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
            char reason[80];
            sprintf(reason, "Must have same number of colunms (%lu) but was %lu\n", m->columns, columns);
            C_ERROR_VOID( reason, C_EINVAL );
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
       
    call_method("Anorman::Data::Matrix::Abstract::check_shape", G_VOID );

    LEAVE;

    /* straight up memcopy if neither marix is a view */
    if (!A->view_flag && !B->view_flag) {
        Copy( B->elements, A->elements, (UV) (A->rows * A->columns), double );
        return; 
    }

    c_mm_copy( A, B );
}

void _assign_DensePackedMatrix_from_CODE( SV* self, SV* code ) {
    HV *stash;
    GV *gv;
    CV* cv = sv_2cv( code, &stash, &gv, 0);

    if (cv == Nullcv) {
         C_ERROR_VOID("Not a subroutine reference", C_EINVAL );
    }

    SV_2STRUCT( self, Matrix, m );

    double* elems = m->elements;
    size_t index = c_m_index(m, 0,0);

    const size_t cs = m->column_stride;
    const size_t rs = m->row_stride;

    size_t row,column;
    for (row = 0; row < m->rows; row++ ) {
        size_t i = index;
        for (column = 0; column < m->columns; column++ ) {
            dSP;

            PUSHMARK(SP);
            XPUSHs( sv_2mortal( newSVnv( elems[ i ])));
            PUTBACK;

            call_sv((SV*)cv, G_SCALAR);
            elems[ i ] =  SvNV( *PL_stack_sp );

            FREETMPS;

            i += cs;
        }

        index += rs;
    }
}

void _assign_DensePackedMatrix_from_OBJECT_and_CODE ( SV* self, SV* other, SV* function ) {
	SV_2STRUCT( self, Matrix, A );
	SV_2STRUCT( other, Matrix, B );

	
	
}

void _assign_DensePackedMatrix_from_NUMBER ( SV* self, NV value ) {
    SV_2STRUCT( self, Matrix, m );

    c_m_set_all( m, (double) value );
}

NV sum( SV* self ) {
    SV_2STRUCT( self, Matrix, m );

    return (NV) c_m_sum( m );
}

void _mult_matrix_matrix ( SV* self, 
                           SV* other,
                           SV* result,
                           SV* sv_alpha,
                           SV* sv_beta,
                           SV* sv_transA,
                           SV* sv_transB )
{

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
	XPUSHs( sv_transA );
	XPUSHs( sv_transB );
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

void _mult_matrix_vector ( SV* self, SV* other, SV* result, SV* sv_alpha, SV* sv_beta, SV* sv_transA ) {

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
        XPUSHs( sv_transA );
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

END_OF_C_CODE

1;
