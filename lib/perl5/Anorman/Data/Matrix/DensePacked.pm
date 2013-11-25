package Anorman::Data::Matrix::DensePacked;

use strict;
use parent 'Anorman::Data::Matrix';

use Anorman::Common qw(sniff_scalar);
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
	my $class = shift;
	$class->_error("Wrong number of arguments") if (@_ != 1 && @_ != 2 && @_ != 7);

	my ( $rows,
             $columns,
             $row_zero,
             $column_zero,
             $row_stride,
             $column_stride
           );

	my $self = &new_matrix_object( ref($class) || $class );

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
			$self->_error("Not a matrix reference");
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

#include "../lib/matrix.c"

#define SV_2MATRIX( sv, ptr_name )    Matrix* ptr_name = (Matrix*) SvIV( SvRV( sv ) )
#define SV_2VECTOR( sv, ptr_name )    Vector* ptr_name = (Vector*) SvIV( SvRV( sv ) )

#define SVADDR_2PTR( sv_name, ptr_name )            \
     UV ptr_name = INT2PTR( double*, SvUV( sv_name ) ) 

#define PTR_2SVADDR( ptr_name, sv_name )        \
    SV* sv_name = newSVuv( PTR2UV( ptr_name ) )

#define ELEMS_BEG( ptr_name, x )               \
    double* ptr_name =  (double *) x->elements     \

#define ALLOC_ELEMS( slots, sv_name )          \
    double* _ELEMS;                            \
    Newxz( _ELEMS, slots, double );            \
    SV* sv_name = newSVuv(PTR2UV( _ELEMS ))    \

SV* _alloc_elements( SV*, UV );

SV*  _get_elements_addr( SV* );
void _set_elements_addr( SV*, SV* );

void static  show_struct( Matrix* );

/* object constructors */
SV* new_matrix_object( SV* sv_class_name ) {

    /* the central Matrix struct */
    Matrix* m;

    /* set up object variables */
    char* class_name = SvPV_nolen( sv_class_name );
    SV*   self       = newSViv(0);
    SV*   obj        = newSVrv( self, class_name );

    /* allocate struct memory */
    Newxz(m, 1, Matrix);

    /* set object address */
    sv_setiv( obj, (IV)m);
    SvREADONLY_on( obj );

    return self;
}

/* clone a matrix object by making a copy of the underlying struct */
SV* _struct_clone( SV* self ) {
    SV_2MATRIX( self, m );
    Matrix* n;

    char* class_name = sv_reftype( SvRV( self ), TRUE );

    SV*   clone      = newSViv(0);
    SV*   obj        = newSVrv( clone, class_name );

    Newx( n, 1, Matrix );

    StructCopy( m, n, Matrix );

    sv_setiv( obj, (IV) n );
    SvREADONLY_on( obj );

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
    SV_2MATRIX( self, m );
    
    return (NV) c_m_get_quick( m, (int)row, (int)column );
}

void set_quick(SV* self, IV row, IV column, NV value) {
    SV_2MATRIX( self, m );

    c_m_set_quick( m, (int)row, (int)column, (double)value );
}

NV sum( SV* self ) {
    SV_2MATRIX( self, m );

    return c_m_sum( m );
}

/* object initializors */
void _setup ( SV* self, ...) {
    Inline_Stack_Vars;
    
    if ( items != 3 && items != 7) {
        croak("_setup::Wrong number of arguments (%d)", (int) Inline_Stack_Items );
    }

    SV_2MATRIX( self, m);

    m->rows    = (size_t) SvIV( Inline_Stack_Item(1) );
    m->columns = (size_t) SvIV( Inline_Stack_Item(2) );
    
    if ( items == 7 ) {
        m->row_zero      = (int) SvIV( Inline_Stack_Item(3) );
        m->column_zero   = (int) SvIV( Inline_Stack_Item(4) );
        m->row_stride    = (int) SvIV( Inline_Stack_Item(5) );
        m->column_stride = (int) SvIV( Inline_Stack_Item(6) );
        m->view_flag     = TRUE;
    } else {
        m->row_zero      = 0;
        m->column_zero   = 0;
        m->row_stride    = (int) m->columns;
        m->column_stride = 1;
        m->view_flag     = FALSE;
   }
}

SV* _alloc_elements( SV* self, UV num_elems ) {
    SV_2MATRIX( self, m );

    if ( m->elements != NULL ) {
        croak("Memory already allocated");
    }

    ALLOC_ELEMS( num_elems, sv_addr );
        
    return sv_addr;
}


/* elements pointer address manipulation */
SV* _get_elements_addr (SV* self) {

    SV_2MATRIX( self, m);
    PTR_2SVADDR( m->elements, sv_addr );

    return sv_addr;
}

void _set_elements_addr (SV* self, SV* sv_addr ) {

    SVADDR_2PTR( sv_addr, elems_ptr );
    SV_2MATRIX( self, m );

    if (m->elements == NULL) {
        m->elements = (double*) elems_ptr;
    } else {
        PerlIO_printf( PerlIO_stderr(), "Cannot assign (%x) to an already assigned pointer (%p)\n", elems_ptr, m->elements );
    }   
}

IV _index (SV* self, UV row, UV column) {
    SV_2MATRIX( self, m);
 
    return c_m_index( m, (int) row, (int) column );
}

/* data assignment functions */
void _assign_DensePackedMatrix_from_2D_MATRIX(SV* self, AV* array_of_arrays ) {
    SV_2MATRIX( self, m );

    /* verify number of rows */
    I32 rows = av_len( array_of_arrays ) + 1;
    
    if (rows != (I32) m->rows) {
        croak("Cannot assign AoA to matrix object: must have %d rows\n", m->rows );
        my_exit(1);
    }
        
    int i        = m->columns * (rows - 1);
    int row      = m->rows;
    double* elem = (double *) m->elements;

    while (--row >= 0) {

	/* fetch a row from AoA and convert to AV* */
        AV* current_row = (AV*) SvIV( *av_fetch( array_of_arrays, row, 0) );
        I32 columns     = av_len( current_row ) + 1;

        /* verify length */
        if (columns != m->columns) {   
            PerlIO_printf( PerlIO_stderr(), "Must have same number of colunms (%d) but was %d\n", m->columns, columns );
            my_exit(1);
        }
         
	/* fill elements */
        int j = -1;
        while ( ++j < columns ) {
            double value = (double) SvNV( *av_fetch( current_row, j, 0) );
            elem[ i + j ] = value;
        }

        i -= m->columns;  
    }
}

void _assign_DensePackedMatrix_from_OBJECT ( SV* self, SV* other ) {
    SV_2MATRIX( self, A );
    SV_2MATRIX( other, B );

    if (A->elements == B->elements) {
        return;
    }

    /* straight memcopy if neither marix is a view */
    if (A->view_flag == FALSE && B->view_flag == FALSE) {
        Copy( B->elements, A->elements, (UV) (A->rows * A->columns), double );
        return; 
    }

    ELEMS_BEG( A_elem, A);
    ELEMS_BEG( B_elem, B);

    int    A_cs = A->column_stride;
    int    B_cs = B->column_stride;
    int    A_rs = A->row_stride;
    int    B_rs = B->row_stride;
    int B_index = c_m_index( B, 0,0 );
    int A_index = c_m_index( A, 0,0 );

    int row = A->rows;
    while ( --row >= 0) {
        int i = A_index;
        int j = B_index;

        int column = A->columns;
        while (--column >= 0) {
            A_elem[ i ] = B_elem[ j ];
            i += A_cs;
            j += B_cs;
        }

        A_index += A_rs;
        B_index += B_rs;
    }

}

void _assign_DensePackedMatrix_from_OBJECT_and_CODE ( SV* self, SV* other, SV* function ) {
	SV_2MATRIX( self, A );
	SV_2MATRIX( other, B );

	
	
}

void _assign_DensePackedMatrix_from_NUMBER ( SV* self, NV value ) {

    SV_2MATRIX( self, M );

    ELEMS_BEG( elems, M);

    int index = c_m_index( M, 0,0 );
    int    cs = M->column_stride;
    int    rs = M->row_stride;

    int row = M->rows;
    while ( --row >= 0) {
        int i = index;

        int column = M->columns;
        while (--column >= 0) {
            elems[ i ] = value;
            i += cs;
        }

        index += rs;
    }

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

    SV_2MATRIX( self, A );	
    SV_2MATRIX( other, B );
    SV_2MATRIX( result, C);

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

    SV_2MATRIX( self, A );
    SV_2VECTOR( other, y );
    SV_2VECTOR( result, z );

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

    m->view_flag = TRUE;
    
    SvREFCNT_inc( self );
    return self;
}

SV* _v_part( SV* self, SV* row, SV* column, SV* height, SV* width ) {
    SV_2MATRIX( self, m );

    dSP;

    ENTER;
    PUSHMARK( SP );
    XPUSHs( self );
    XPUSHs( row );
    XPUSHs( column );
    XPUSHs( height );
    XPUSHs( width );
    PUTBACK;

    call_method("Anorman::Data::Matrix::_check_box", G_VOID );

    LEAVE;

    m->row_zero    += m->row_stride * SvIV( row );
    m->column_zero += m->column_stride * SvIV( column );
    m->rows         = SvIV( height );
    m->columns      = SvIV( width );
    m->view_flag    = TRUE;

    SvREFCNT_inc( self );	
    return self;
}

/* object destruction */
void DESTROY(SV* self) {
    SV_2MATRIX( self, m );

    /* do not free matrix elements unless object
       is not a view */
    if (m->elements != NULL && m->view_flag != TRUE) {
        Safefree( m->elements );
    }

    Safefree( m );
}

/* DEBUGGING */
void show_struct( Matrix* m ) {
    
    PerlIO_printf( PerlIO_stderr(), "\nContents of Matrix struct:\n" );
    PerlIO_printf( PerlIO_stderr(), "\trows\t(%p): %d\n", &m->rows, (int) m->rows );
    PerlIO_printf( PerlIO_stderr(), "\tcols\t(%p): %d\n", &m->columns, (int) m->columns );
    PerlIO_printf( PerlIO_stderr(), "\tview\t(%p): %d\n", &m->view_flag, (int) m->view_flag );
    PerlIO_printf( PerlIO_stderr(), "\tr0\t(%p): %d\n",  &m->row_zero, m->row_zero );
    PerlIO_printf( PerlIO_stderr(), "\tc0\t(%p): %d\n", &m->column_zero, m->row_zero );
    PerlIO_printf( PerlIO_stderr(), "\trstride\t(%p): %d\n", &m->row_stride, m->row_stride );
    PerlIO_printf( PerlIO_stderr(), "\tcstride\t(%p): %d\n", &m->column_stride, m->column_stride );

    if (m->elements == NULL) {
        PerlIO_printf( PerlIO_stderr(), "\telems\t(%p): null\n\n",  &m->elements );
    } else {
        PerlIO_printf( PerlIO_stderr(), "\telems\t(%p): [ %p ]\n\n",  &m->elements, m->elements );
    }
}

END_OF_C_CODE

1;
