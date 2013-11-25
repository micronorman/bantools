package Anorman::Data::Vector::SelectedDensePacked;

use strict;

use parent 'Anorman::Data::Vector';

use Anorman::Data::Vector::SelectedDensePacked;
use Anorman::Data::LinAlg::Property qw(is_packed);

sub new {
	my $class = shift;

	if (@_ != 2 && @_ != 6) {
		$class->_error("Wrong number of arguments");
	}
	
	my ( 
             $size,
	     $elems,
             $zero,
             $stride,
             $offsets,
	     $offset
           );

	my $self = &new_selectedvector_object( ref($class) || $class );
	
	if (@_ == 4) {
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

	$self->_setup( $size, $zero, $stride, $offset, $offsets );
	$self->_set_elements_addr( $elems );

	return $self;
}

sub _view_selection_like {
	my $self = shift;
	return $self->new( $self->_get_elements_addr, $self->offsets );
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

	return undef unless (is_packed($self) && is_packed($other));
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

#include "data.h"

#define SV_2SELECTEDVECTOR( sv, ptr_name )    SelectedVector* ptr_name = (SelectedVector*) SvIV( SvRV( sv ) )

#define SVADDR_2PTR( sv_name, ptr_name )            \
     UV ptr_name = INT2PTR( double*, SvUV( sv_name ) ) 

#define PTR_2SVADDR( ptr_name, sv_name )        \
    SV* sv_name = newSVuv( PTR2UV( ptr_name ) )

SV*  _get_elements_addr( SV* );
void _set_elements_addr( SV*, SV* );

void static  show_struct( SelectedVector* );

/* object constructors */
SV* new_selectedvector_object( SV* sv_class_name ) {

    /* the central Vector struct */
    SelectedVector* m;

    /* set up object variables */
    char* class_name = SvPV_nolen( sv_class_name );
    SV*   self       = newSViv(0);
    SV*   obj        = newSVrv( self, class_name );

    /* allocate struct memory */
    Newxz(m, 1, SelectedVector);

    /* set object address */
    sv_setiv( obj, (IV)m);
    SvREADONLY_on( obj );

    return self;
}

/* object accessors (for perl calls) */
UV size(SV* self) {
    return (UV) ((SelectedVector*)SvIV(SvRV(self)))->size;
}

UV zero(SV* self) {
    return (UV) ((SelectedVector*)SvIV(SvRV(self)))->zero;
}

IV stride(SV* self) {
    return (IV) ((SelectedVector*)SvIV(SvRV(self)))->stride;
}

IV offset(SV* self) {
    return (IV) ((SelectedVector*)SvIV(SvRV(self)))->offset;
}

SV* offsets(SV* self) {
    
    SV_2SELECTEDVECTOR( self, v );

    AV* av_offsets = newAV();

    int* offsets = (int*) v->offsets;

    int i;
    for (i = 0; i < v->size; i++) {
        av_push( av_offsets, newSViv( offsets[ i ] ) );
    }

    return newRV_noinc((SV*) av_offsets );
}

UV _is_noview (SV* self) {
    return (UV) (((SelectedVector*)SvIV(SvRV(self)))->view_flag == FALSE);
}

NV get_quick(SV* self, IV index) {
    /* NOTE:  Assumes that index is always
       is within array boundary */
    SV_2SELECTEDVECTOR( self, v );
   
       int* offs  = (int*) v->offsets;
    double* elems = (double*) v->elements;

    return (NV) elems[ v->offset + offs[ v->zero + index * v->stride ] ];
}

void set_quick(SV* self, IV index, NV value) {
    SV_2SELECTEDVECTOR( self, v );

       int* offs = (int*) v->offsets;
    double* elems = (double*) v->elements;

    elems[ v->offset + offs[ v->zero + index * v->stride ] ] = (double) value;
}

/* object initializors */
void _setup ( SV* self,
              UV size,
              UV zero,
              IV stride,
              IV offset,
              AV* av_offsets
            ) {

    SV_2SELECTEDVECTOR( self, v );

    v->size      = (size_t) size;
    v->zero      = (int) zero;
    v->stride    = (int) stride;
    v->offset    = (int) offset;
    v->view_flag = TRUE;

    int* offsets;   

    int length = av_len( av_offsets ) + 1;

    /* allocate memory for offsets */
    Newx( offsets, length, int ); 

    /* assign offsets */
    int i = length;
    while ( --i >= 0 ) {
        offsets[ i ] = (int) SvIV( *av_fetch( av_offsets, i, 0) );
    }

    v->offsets = (char*) offsets;

}

/* elements pointer address manipulation */
SV* _get_elements_addr (SV* self) {

    SV_2SELECTEDVECTOR( self, v );
    PTR_2SVADDR( v->elements, sv_addr );

    return sv_addr;
}

void _set_elements_addr (SV* self, SV* sv_addr ) {

    SVADDR_2PTR( sv_addr, elems_ptr );
    SV_2SELECTEDVECTOR( self, v );

    /* some sanity checks */
    if (v->elements == NULL) {
        v->elements = (double*) elems_ptr;
    } else {
        PerlIO_printf( PerlIO_stderr(), "Cannot assign (%x) to an already assigned pointer (%p)\n", elems_ptr, v->elements );
    }
}

IV _index (SV* self, UV rank ) {
    SV_2SELECTEDVECTOR( self, v );

    int* offsets = (int*) v->offsets;
 
    return v->offset + offsets[ v->zero + rank * v->stride ];
}

IV _offset (SV* self, IV abs_rank ) {
    SV_2SELECTEDVECTOR( self, v );

    int* offsets = (int*) v->offsets;

    return (IV) offsets[ abs_rank ];
}



/* object destruction */
void DESTROY(SV* self) {
    SV_2SELECTEDVECTOR( self, v );

    /* do not free matrix elements unless object
       is not a view */
    if (v->elements != NULL && v->view_flag != TRUE) {
        Safefree( v->elements );
    }

    Safefree( v->offsets );
    Safefree( v );
}

/* DEBUGGING */
void show_struct( SelectedVector* v ) {
    
    PerlIO_printf( PerlIO_stderr(), "\nContents of Vector struct:\n" );
    PerlIO_printf( PerlIO_stderr(), "\tsize\t(%p): %d\n", &v->size, (int) v->size );
    PerlIO_printf( PerlIO_stderr(), "\tview\t(%p): %d\n", &v->view_flag, (int) v->view_flag );
    PerlIO_printf( PerlIO_stderr(), "\t0\t(%p): %d\n",  &v->zero, v->zero );
    PerlIO_printf( PerlIO_stderr(), "\tstride\t(%p): %d\n", &v->stride, v->stride );
    PerlIO_printf( PerlIO_stderr(), "\toffset\t(%p): %d\n", &v->offset, v->offset );

    if (v->offsets == NULL) {
        PerlIO_printf( PerlIO_stderr(), "\toffsets\t(%p): null\n",  &v->offsets );
    } else {
        PerlIO_printf( PerlIO_stderr(), "\toffsets\t(%p): [ %p ]\n",  &v->offsets, v->offsets );
    }

    if (v->elements == NULL) {
        PerlIO_printf( PerlIO_stderr(), "\telems\t(%p): null\n\n",  &v->elements );
    } else {
        PerlIO_printf( PerlIO_stderr(), "\telems\t(%p): [ %p ]\n\n",  &v->elements, v->elements );
    }
}

END_OF_C_CODE

1;

