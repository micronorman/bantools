package Anorman::Data::Vector::SelectedDensePacked;

use strict;

use parent qw(Anorman::Data::Vector::Abstract Anorman::Data::Vector);
use Anorman::Data::Vector::DensePacked;
use Anorman::Data::LinAlg::Property qw( :vector );

sub new {
	my $that  = shift;
	my $class = ref $that || $that;

	if (@_ != 2 && @_ != 6) {
		$class->_error("Wrong number of arguments");
	}
	
	my $self = $class->_bless_vector_struct();

	my ( 
             $size,
	     $elems,
             $zero,
             $stride,
             $offsets,
	     $offset
           );
	
	if (@_ == 2) {
		$zero      = 0;
		$stride    = 1;
		
		($size,
		 $elems,
		 $offsets,
		 $offset ) = ( scalar @{ $_[1] }, $_[0], $_[1], 0 ); 
	} else {
		($size,
                 $elems,
                 $zero,
                 $stride,
                 $offsets,
                 $offset) = @_;
	}		

	$self->_setup( $size, $zero, $stride );
	$self->_set_offsets( $offset, $offsets );
	$self->_set_elements( $elems );

	$self->_set_view(1);

	return $self;
}

sub _view_selection_like {
	my $self = shift;
	return $self->new( $self->_elements, $self->offsets );
}

sub like {
	my $self = shift;
	
}

sub _like_vector {
	my $self    = shift;
        return Anorman::Data::Vector::DensePacked->new($_[0], $self, $_[1], $_[2]);
}

sub _have_shared_cells_raw {
	my ($self, $other) = @_;

	return undef unless (is_vector($other) && is_packed($other));
	return $self->_get_elements_addr == $other->_get_elements_addr;
}

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Data::Vector::SelectedDensePacked',
		ENABLE    => AUTOWRAP =>
		LIBS      => '-L' . $Anorman::Common::AN_SRC_DIR . '/lib -lmatrix',
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR  . '/include'

           );
use Inline C => <<'END_OF_C_CODE';

#include <stdio.h>
#include "error.h"
#include "data.h"
#include "perl2c.h"
#include "vector.h"

#include "../lib/vector.c"

/*===========================================================================
 Abstract Vector functions
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

/*
UV _offset (SV* self, UV index ) {
    return index;
}

UV _rank (SV* self, UV rank) {
    SV_2STRUCT( self, Vector, v);

    return v->zero + (size_t) rank * v->stride;
}
*/

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

/*===========================================================================
 SelectedDenseVector functions
 ============================================================================*/

NV get_quick(SV* self, IV index) {
    SV_2STRUCT( self, Vector, v );
   
    size_t* offs  = v->offsets->offsets;
    double* elems = v->elements;

    return (NV) elems[ v->offsets->offset + offs[ v->zero + index * v->stride ] ];
}

void set_quick(SV* self, IV index, NV value) {
    SV_2STRUCT( self, Vector, v );
   
    size_t* offs  = v->offsets->offsets;
    double* elems = v->elements;

    elems[ v->offsets->offset + offs[ v->zero + index * v->stride ] ] = (double) value;
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

IV _index (SV* self, UV rank ) {
    SV_2STRUCT( self, Vector, v );

    size_t* offsets = v->offsets->offsets;
 
    return v->offsets->offset + offsets[ v->zero + rank * v->stride ];
}

IV _offset (SV* self, IV abs_rank ) {
    SV_2STRUCT(self, Vector, v);

    size_t* offsets = v->offsets->offsets;

    return (IV) offsets[ (size_t) abs_rank ];
}

void _get_offsets( SV* self ) {
    SV_2STRUCT( self, Vector, v );

    UV offset;
    AV* av_offsets    = newAV();

    size_t* offsets    = v->offsets->offsets;

    size_t i;
    for (i = 0; i < v->size; i++) {
        av_push( av_offsets, newSViv( offsets[ i ] ) );
    }

    Inline_Stack_Vars;
    Inline_Stack_Reset;
    
    Inline_Stack_Push( sv_2mortal(newSVuv( v->offsets->offset )));
    Inline_Stack_Push( newRV_noinc((SV*) av_offsets ));
    
    Inline_Stack_Done;
}

void _set_offsets( SV* self, UV offset, AV* av_offsets) {
    SV_2STRUCT( self, Vector, v);

    size_t* offsets;   
    size_t o_size = av_len( av_offsets ) + 1;

    /* allocate memory for row and column offsets */
    Newx( offsets, o_size, size_t ); 

    /* fill array with row offsets */
    size_t i;
    for (i = 0; i < o_size; i++ ) {
        offsets[ i ] = (size_t) SvUV( *av_fetch( av_offsets, i, 0) );
    }

    VectorOffsets* vo_ptr;

    /* Allocate struct space for matrix offsets */
    Newx( vo_ptr, 1, VectorOffsets );

    v->offsets = vo_ptr;

    v->offsets->offset = (size_t) offset;
    v->offsets->offsets = offsets;
}

void _dump (SV* self) {
    SV_2STRUCT(self, Vector, v);

    c_v_show_struct( v );
}

END_OF_C_CODE

1;

