package Anorman::Data::Matrix::AbstractPacked;

use strict;
use warnings;

#use parent 'Anorman::Data::Abstract';

use Anorman::Common;


sub _index { $_[0]->_row_offset($_[0]->_row_rank($_[1]))
		+ $_[0]->_column_offset($_[0]->_column_rank($_[2]))
}

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Data::Matrix::AbstractPacked',
		ENABLE    => AUTOWRAP =>
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include'

           );

use Inline C => <<'END_OF_C_CODE';

#include <stdio.h>
#include <limits.h>
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

END_OF_C_CODE

1;
