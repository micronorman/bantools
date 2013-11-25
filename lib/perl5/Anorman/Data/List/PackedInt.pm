package Anorman::Data::List::PackedInt;

use Inline (C => Config =>
		DIRECTORY => '/home/anorman/tmp',
		NAME      => 'Anorman::Data::List::PackedInt',
		ENABLE    => AUTOWRAP =>
		LIBS      => '-L/home/anorman/src/anorman/lib -lvector',
		INC       => '-I/home/anorman/src/anorman/include'
	   );
use Inline C => <<'END_OF_C_CODE';

#include "data.h"

#define SV_2LIST( sv, ptr_name )    IntList* ptr_name = (IntList*) SvIV( SvRV( sv ) )


#define SVADDR_2PTR( sv_name, ptr_name )            \
     UV ptr_name = INT2PTR( char*, SvUV( sv_name ) ) 

#define PTR_2SVADDR( ptr_name, sv_name )        \
    SV* sv_name = newSVuv( PTR2UV( ptr_name ) )

#define ELEMS_BEG( ptr_name, x )               \
    int* ptr_name =  (int *) x->elements     \

#define ALLOC_ELEMS( slots, sv_name )          \
    char* _ELEMS;                              \
    Newxc( _ELEMS, slots, int, char* );     \
    SV* sv_name = newSVuv(PTR2UV( _ELEMS ))    \

SV* _alloc_elements( SV*, UV );

SV*  _get_elements_addr( SV* );
void _set_elements_addr( SV*, SV* );

/* object constructor */
SV* new( SV* sv_class_name,...) {

    Inline_Stack_Vars;
    IntList* l;

     /* set up object variables */
    char* class_name = SvPV_nolen( sv_class_name );
    SV*   self       = newSViv(0);
    SV*   obj        = newSVrv( self, class_name );

    /* allocate struct memory */
    Newxz(l, 1, IntList);

    /* set object address */
    sv_setiv( obj, (IV)v);
    SvREADONLY_on( obj );

    size_t initial_capacity;
    
    if (Inline_Stack_Items > 1) {
        initial_capacity = (size_t) SvIV( Inline_Stack_Item(1) );
    }

    return self;
}


/* object accessors */
IV size(SV* self) {
    return (UV) ((List*)SvIV(SvRV(self)))->size;
}


NV get_quick(SV* self, IV index) {

    SV_2VECTOR( self, v );
    
    return (NV) c_v_get_quick( v, (int) index );
}

void set_quick(SV* self, IV index, NV value) {
 
    SV_2VECTOR( self, v );

    c_v_set_quick( v, (int)index, (double)value );
}

/* elements pointer address manipulation */
SV* _get_elements_addr (SV* self) {

    SV_2VECTOR( self, v );
    PTR_2SVADDR( v->elements, sv_addr );

    return sv_addr;
}

void _set_elements_addr (SV* self, SV* sv_addr ) {

    SVADDR_2PTR( sv_addr, elems_ptr );
    SV_2VECTOR( self, v );

    /* some sanity checls */
    if (v->elements == 0) {
        v->elements = (char*) elems_ptr;
    } else if (&elems_ptr == (*v->elements) ) {
        PerlIO_printf( PerlIO_stderr(), "Elements pointer is already assigned to this address (%)x\n", &elems_ptr );
    } else {
        PerlIO_printf( PerlIO_stderr(), "Cannot assign (%x) to an already assigned pointer (%p)\n", elems_ptr, (*v->elements) );
    }   
}

/* object destruction */
void DESTROY(SV* self) {
    SV_2LIST( self, v );

    if (v == NULL) {
        PerlIO_printf( PerlIO_stderr(), "Struct was NULL!\n" );
    }
    /* do not free matrix elements unless object
       is not in view mode                       */
    if (v->elements != NULL && v->view_flag != TRUE) {
        Safefree( v->elements );
    }
    
    Safefree( v );
}

/* DEBUGGING */
void show_struct( IntList* l ) {
    
    PerlIO_printf( PerlIO_stderr(), "\nContents of Vector struct:\n" );
    PerlIO_printf( PerlIO_stderr(), "\tsize\t(%p): %d\n", &v->size, (int) v->size );
    PerlIO_printf( PerlIO_stderr(), "\tview\t(%p): %d\n", &v->view_flag, (int) v->view_flag );
    PerlIO_printf( PerlIO_stderr(), "\t0\t(%p): %d\n",  &v->zero, v->zero );
    PerlIO_printf( PerlIO_stderr(), "\tstride\t(%p): %d\n", &v->stride, v->stride );

    if (v->elements == NULL) {
        PerlIO_printf( PerlIO_stderr(), "\telems\t(%p): null\n\n",  &v->elements );
    } else {
        PerlIO_printf( PerlIO_stderr(), "\telems\t(%p): [ %p ]\n\n",  &v->elements, v->elements );
    }
}

END_OF_C_CODE


1;
