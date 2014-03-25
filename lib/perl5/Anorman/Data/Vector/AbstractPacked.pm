package Anorman::Data::Vector::AbstractPacked;

use parent 'Anorman::Data::Abstract';

use Anorman::Common;
use Anorman::Data::Config qw($MAX_ELEMENTS);

sub _index { &_offset($_[0], &_rank($_[0],$_[1])) }

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Data::Vector::AbstractPacked',
		AUTOWRAP  => ENABLE =>
		LIBS      => '-L' . $Anorman::Common::AN_SRC_DIR . '/lib -lvector',
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include'
	   );
use Inline C => <<'END_OF_C_CODE';

#include <stdio.h>
#include "error.h"
#include "data.h"
#include "perl2c.h"
#include "vector.h"

#include "../lib/vector.c"

/*===========================================================================
 Abstract Vectorfunctions
 ============================================================================*/

/* object constructors */
SV* _bless_vector_struct( SV* sv_class_name ) {

    Vector* v;
    SV* self;

    /* allocate struct memory */
    Newxz(v, 1, Vector);

    const char* class_name = SvPV_nolen( sv_class_name );
    BLESS_STRUCT( v, self, class_name );

    return self;
}

/* clone a Vectorobject by making and blessing a copy of the underlying struct */
SV* _clone_self( SV* self ) {
    SV_2STRUCT( self, Vector, v );

    Vector* n;
    SV* clone;

    /* clone struct */
    Newx( n, 1, Vector);
    StructCopy( v, n, Vector);

    /* make a blessed perl object */
    const char* class_name = sv_reftype( SvRV( self ), TRUE );
    BLESS_STRUCT( n, clone, class_name ); 

    return clone; 
}

/* object accessors (for perl calls) */
UV size (SV* self) {
    SV_2STRUCT( self, Vector, v );
    
   return (UV) v->size;
}

UV _zero(SV* self) {
    return (UV) ((Vector*)SvIV(SvRV(self)))->zero;
}

IV _stride(SV* self) {
    return (IV) ((Vector*)SvIV(SvRV(self)))->stride;
}

UV _is_view (SV* self) {
    return (UV) ((Vector*)SvIV(SvRV(self)))->view_flag;
}

UV _is_noview (SV* self) {
    return (UV) (((Vector*)SvIV(SvRV(self)))->view_flag == 0);
}

void _set_view(SV* self, IV flag) {
    ((Vector*)SvIV(SvRV(self)))->view_flag = (int) flag;
}

UV _offset (SV* self, UV index ) {
    return index;
}

UV _rank (SV* self, UV rank) {
    SV_2STRUCT( self, Vector, v);

    return v->zero + (size_t) rank * v->stride;
}

SV* _elements (SV* self) {
    SV_2STRUCT( self, Vector, v );
    PTR_2SVADDR( v->elements, sv_addr );

    return sv_addr;
}

void _set_elements (SV* self, SV* sv_addr ) {
    SVADDR_2PTR( sv_addr, elems_ptr );
    SV_2STRUCT( self, Vector, v );

    if (!v->elements) {
        v->elements = elems_ptr;
    } else {
        C_ERROR_VOID("This Vector was already assigned an elements pointer", C_EINVAL );
    }   
}

/* object initializors */

void _setup ( SV* self, SV* size, ... ) {
    Inline_Stack_Vars;
    
    SV_2STRUCT( self, Vector, v );
    
    v->size = (size_t) SvUV( size );

    if ( items == 4 ) {
        v->zero      = (size_t) SvUV( Inline_Stack_Item(2) );
        v->stride    = (size_t) SvUV( Inline_Stack_Item(3) );
        v->view_flag = 1;
    } else {
        v->zero      = 0;
        v->stride    = 1;
        v->view_flag = 0;
    }  

    if (v->size > MAX_NUM_ELEMENTS) {
        C_ERROR_VOID("Vector is too large", C_EINVAL );
    }
}


/* Consistency checks */

void _check_index ( SV* self, IV index ) {
    SV_2STRUCT( self, Vector, v );

    if (index < 0 || index >= (IV) v->size) {
        char reason[80];
        sprintf(reason, "Index (%li) is out of bounds", index);
        C_ERROR_VOID( reason, C_EINVAL );
    }
}

void _check_range ( SV* self, IV from, IV length )  {
    SV_2STRUCT( self, Vector, v );
    if (from < 0 || length < 0 || from + length > (IV) v->size) 
    {
        char reason[80];
        sprintf( reason, "Index range out of bounds: from: %li, length: %li, size: %li",
                 from, length, v->size);
        C_ERROR_VOID( reason, C_EINVAL );

    }
}
 
SV* _v_part( SV* self, UV index, UV width ) {
    SV_2STRUCT( self, Vector, v );

    c_v_part( v, index, width );

    SvREFCNT_inc( self );	
    return self;
}

/* object destruction */
void DESTROY(SV* self) {
    SV_2STRUCT( self, Vector, v );

    c_v_free( v );
}

END_OF_C_CODE

1;


