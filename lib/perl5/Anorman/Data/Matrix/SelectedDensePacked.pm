package Anorman::Data::Matrix::SelectedDensePacked;

use strict;

use parent qw(Anorman::Data::Matrix::Abstract Anorman::Data::Matrix);

use Anorman::Common;

use Anorman::Data::Matrix::DensePacked;
use Anorman::Data::Vector::SelectedDensePacked;
use Anorman::Data::LinAlg::Property qw(is_packed);

sub new {
	my $that  = shift;
	my $class = ref $that || $that;

	if (@_ != 4 && @_ != 10) {
		trace_error("Wrong number of arguments");
	}
	
	my ( 
             $rows,
             $columns,
	     $elems,
             $row_zero,
             $column_zero,
             $row_stride,
             $column_stride,
             $row_offsets,
             $column_offsets,
	     $offset
           );

	my $self = $class->_bless_matrix_struct;
	
	if (@_ == 4) {
		$row_zero      = 0;
		$column_zero   = 0;
		$row_stride    = 1;
		$column_stride = 1;
		
		($rows,
		 $columns,
		 $elems,
		 $row_offsets,
		 $column_offsets,
		 $offset ) = ( scalar @{ $_[1] }, scalar @{ $_[2] }, $_[0], $_[1], $_[2], $_[3] ); 
	} else {
		($rows,
                 $columns,
                 $elems,
                 $row_zero,
                 $column_zero,
                 $row_stride,
                 $column_stride,
                 $row_offsets,
                 $column_offsets,
                 $offset) = @_;
	}		

	$self->_setup( $rows, $columns, $row_zero, $column_zero, $row_stride, $column_stride);

	$self->_set_elements( $elems );
	$self->_set_offsets( $offset, $row_offsets, $column_offsets );
	$self->_set_view(1);

	return $self;
}

sub view_row {
	my ($self, $row) = @_;
	$self->_check_row( $row );
	
	my $vsize    = $self->columns;
	my $vzero    = $self->_column_zero;
	my $vstride  = $self->_column_stride;

	my ($offset, $roffset, $coffset) = $self->_get_offsets;

	my $voffsets = $coffset;
	my $voffset  = $offset + $self->_row_offset( $self->_row_rank( $row ) );

	return Anorman::Data::Vector::SelectedDensePacked->new( $vsize, $self->_elements, $vzero, $vstride, $voffsets, $voffset );
}

sub view_column {
	my ($self, $column) = @_;
	$self->_check_column( $column );

	my $vsize    = $self->rows;
	my $vzero    = $self->_row_zero;
	my $vstride  = $self->_row_stride;

	my ($offset, $roffsets, $coffsets) = $self->_get_offsets;

	my $voffsets = $roffsets;
	my $voffset  = $$offset + $self->_column_offset( $self->_column_rank( $column ) );

	return Anorman::Data::Vector::SelectedDensePacked->new( $vsize, $self->_elements, $vzero, $vstride, $voffsets, $voffset );
}

sub _view_selection_like {
	my $self = shift;
	return $self->new( $self->_elements, $self->row_offsets, $self->column_offsets, $self->offset );
}

sub like {
	my $self = shift;
	return Anorman::Data::Matrix::DensePacked->new( $self->rows, $self->columns );
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

sub _have_shared_cells_raw {
	my ($self, $other) = @_;

	return undef unless (is_matrix($other) && is_packed($other));
	return $self->_elements == $other->_elements;
}

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Data::Matrix::SelectedDensePacked',
		ENABLE    => AUTOWRAP =>
		LIBS      => '-L' . $Anorman::Common::AN_SRC_DIR . '/lib -lmatrix',
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

/*
UV _row_offset (SV* self, UV index ) {
    return index;
}
*/

UV _column_rank (SV* self, UV rank) {
    SV_2STRUCT( self, Matrix, m);

    return m->column_zero + (size_t) rank * m->column_stride;
}

/*
UV _column_offset (SV* self, UV index ) {
    return index;
}
*/

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

/* OVERRIDDEN BELOW
SV* _v_dice( SV* self ) {
    SV_2STRUCT( self, Matrix, m );
    int tmp;
    
    tmp = m->rows;       m->rows = m->columns;             m->columns = tmp;
    tmp = m->row_stride; m->row_stride = m->column_stride; m->column_stride = tmp;
    tmp = m->row_zero;   m->row_zero = m->column_zero;     m->column_zero = tmp;

    SvREFCNT_inc( self );
    return self;
}
*/

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
  SelectedDenseMatrix Functions
  ===========================================================================*/

NV get_quick(SV* self, IV row, IV column) {
    SV_2STRUCT( self, Matrix, m );
   
    const size_t offset = m->offsets->offset;

    size_t* roffs = m->offsets->row_offsets;
    size_t* coffs = m->offsets->column_offsets;
    double* elems = m->elements;

    return (NV) elems[ offset + roffs[ m->row_zero + row * m->row_stride ] + coffs[ m->column_zero + column * m->column_stride ] ];
}

void set_quick(SV* self, IV row, IV column, NV value) {
    SV_2STRUCT( self, Matrix, m );
   
    const size_t offset = m->offsets->offset;

    size_t* roffs = m->offsets->row_offsets;
    size_t* coffs = m->offsets->column_offsets;
    double* elems = m->elements;

    elems[ offset + roffs[ m->row_zero + row * m->row_stride ] + coffs[ m->column_zero + column * m->column_stride ] ] = (double) value;
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

void _get_offsets( SV* self ) {
    SV_2STRUCT( self, Matrix, m );
    UV offset;
    AV* av_row_offsets    = newAV();
    AV* av_column_offsets = newAV();

    size_t* row_offsets    = m->offsets->row_offsets;
    size_t* column_offsets = m->offsets->column_offsets;

    size_t i;
    for (i = 0; i < m->rows; i++) {
        av_push( av_row_offsets, newSViv( row_offsets[ i ] ) );
    }

    for (i = 0; i < m->columns; i++) {
        av_push( av_column_offsets, newSViv( column_offsets[ i ] ) );
    }

    Inline_Stack_Vars;
    Inline_Stack_Reset;
    
    Inline_Stack_Push( sv_2mortal(newSVuv( m->offsets->offset )));
    Inline_Stack_Push( newRV_noinc((SV*) av_row_offsets ));
    Inline_Stack_Push( newRV_noinc((SV*) av_column_offsets ));
    
    Inline_Stack_Done;
}

void _set_offsets( SV* self, UV offset, AV* av_row_offsets, AV* av_column_offsets) {
    SV_2STRUCT( self, Matrix, m);

    size_t* row_offsets;   
    size_t* column_offsets;

    size_t ro_size = av_len( av_row_offsets ) + 1;
    size_t co_size = av_len( av_column_offsets ) + 1;

    /* allocate memory for row and column offsets */
    Newx( row_offsets, ro_size, size_t ); 
    Newx( column_offsets, co_size, size_t );

    /* fill array with row offsets */
    size_t i;
    for (i = 0; i < ro_size; i++ ) {
        row_offsets[ i ] = (size_t) SvUV( *av_fetch( av_row_offsets, i, 0) );
    }

    /* fill array with column offsets */
    i = co_size;
    for (i = 0; i < co_size; i++ ) {
        column_offsets[ i ] = (size_t) SvIV( *av_fetch( av_column_offsets, i, 0) );
    }

    MatrixOffsets* mo_ptr;

    /* Allocate struct space for matrix offsets */
    Newx( mo_ptr, 1, MatrixOffsets );

    m->offsets = mo_ptr;

    m->offsets->row_offsets = row_offsets;
    m->offsets->column_offsets = column_offsets;
    m->offsets->offset = (size_t) offset;
    
}

UV _index (SV* self, UV row, UV column) {
    SV_2STRUCT( self, Matrix, m );
   
    const size_t offset = m->offsets->offset;

    size_t* roffs = m->offsets->row_offsets;
    size_t* coffs = m->offsets->column_offsets;
    double* elems = m->elements;

    return (UV) offset + roffs[ m->row_zero + row * m->row_stride ] + coffs[ m->column_zero + column * m->column_stride ]; 
}

IV _row_offset (SV* self, IV abs_rank ) {
    SV_2STRUCT( self, Matrix, m);

    size_t* row_offsets = m->offsets->row_offsets;
    return (IV) row_offsets[ abs_rank ];
}


IV _column_offset (SV* self, IV abs_rank ) {
    SV_2STRUCT( self, Matrix, m );

    size_t* column_offsets = m->offsets->column_offsets;
    return (IV) column_offsets[ abs_rank ];
}

SV* _v_dice( SV* self ) {
    SV_2STRUCT( self, Matrix, m);
    int tmp;
   
    tmp = m->rows;       m->rows = m->columns;             m->columns = tmp;
    tmp = m->row_stride; m->row_stride = m->column_stride; m->column_stride = tmp;
    tmp = m->row_zero;   m->row_zero = m->column_zero;     m->column_zero = tmp;

    size_t* tmp_offsets = m->offsets->row_offsets; 
    m->offsets->row_offsets = m->offsets->column_offsets;
    m->offsets->column_offsets = tmp_offsets;

    SvREFCNT_inc( self );
    return self;
}


END_OF_C_CODE

1;

