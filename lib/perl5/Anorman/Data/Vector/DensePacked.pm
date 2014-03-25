package Anorman::Data::Vector::DensePacked;

use strict;
use warnings;

use parent qw(Anorman::Data::Vector::Abstract Anorman::Data::Vector);

use Anorman::Common qw(sniff_scalar);
use Anorman::Data::LinAlg::Property qw( :vector );

# I like dispatch tables...
my %ASSIGN_DISPATCH = (
	'NUMBER'      => \&_assign_DensePackedVector_from_NUMBER,
	'ARRAY'       => \&_assign_DensePackedVector_from_ARRAY,
	'OBJECT'      => \&_assign_DensePackedVector_from_OBJECT,
	'OBJECT+CODE' => \&_assign_DensePackedVector_from_OBJECT_and_CODE,
	'CODE'        => \&_assign_DensePackedVector_from_CODE
);

sub new {
	my $that  = shift;
	my $class = ref $that || $that;

	trace_error("Wrong number of arguments") if (@_ != 1 && @_ != 4);

	my $self = $class->_bless_vector_struct();

	if (ref $_[0] eq 'ARRAY') {
		$self->_new_from_array(@_);
	} else {
		$self->_new_from_dims(@_);
	}

	return $self;
}

sub _new_from_array {
	my $self = shift;
	my $size = @{ $_[0] };

	$self->_new_from_dims( $size );
	$self->_assign_DenseVector_from_ARRAY( $_[0] );
}

sub _new_from_dims {
	my $self = shift;

	my ($size, $elements, $zero, $stride) = @_;

	if (@_ == 1) {
		$self->_setup( $size );
		$self->_set_elements( $self->_allocate_elements( $size ) );
	} else {
		$self->_setup( $size, $zero, $stride );
		
		trace_error("Invalid data elements. Must be an unsigned integer")
			unless sniff_scalar($elements) eq 'NUMBER';

		$self->_set_elements( $elements );
		$self->_set_view(1);
	}
}

sub assign {
	my $self = shift;
	my $type = sniff_scalar($_[0]);
	my $instance = ref $_[0];

	if ($type eq 'OBJECT') {
		$self->_check_size($_[0] );	
		return $self->SUPER::assign(@_) if ($instance ne 'Anorman::Data::Vector::DensePacked');
	}

	# determine type of data passed
	if (@_ == 2) {
		my $arg2_type = sniff_scalar( $_[1] );
		unless ($type eq 'OBJECT' && $arg2_type eq 'CODE') {
			$self->_error("Invalid arguments. Argument 2 must be a CODE block ($type,$arg2_type)");
		}
		$type = 'OBJECT+CODE';
	}

	$self->_error("Illegal data type $type") unless exists $ASSIGN_DISPATCH{ $type };

	# execute from dispatch table
	$ASSIGN_DISPATCH{ $type }->( $self, @_ );

	return $self;
}

sub like {
	my $self = shift;

	if (@_ == 1) {
		return $self->new( $_[0] );
	} else {
		return $self->new( $self->size );
	}
}

sub dot_product {
	my ($self, $other, $from, $length) = @_;

	# re-direct mixed vector types to higher level
	if (ref $other ne 'Anorman::Data::Vector::DensePacked') {
		return $self->SUPER::dot_product($other, $from, $length);
	}

	if (@_ == 2) {
		$from = 0;
		$length = $self->size;
	}

	return $self->_packed_dot_product( $other, $from, $length );
}

sub swap {
	my ($self, $other) = @_;
	
	check_vector( $other );
	return if ($self == $other);
	#$self->_check_size( $other );

	$self->SUPER::swap( $other ) if ref $other ne 'Anorman::Data::Vector::DensePacked';
	$self->_packed_swap($other);
}

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Data::Vector::DensePacked',
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

void _dump( SV* self );

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
  DenseVector functions
  ===========================================================================*/

NV get_quick(SV* self, UV index) {
    SV_2STRUCT( self, Vector, v );
    return (NV) c_v_get_quick( v, (size_t) index );
}

void set_quick(SV* self, UV index, NV value) {
    SV_2STRUCT( self, Vector, v );
    c_v_set_quick( v, (size_t) index, (double) value );
}

SV* _allocate_elements( SV* self, UV num_elems ) {
    SV_2STRUCT( self, Vector, v );

    if ( v->elements != NULL ) {
        C_ERROR_NULL("Memory already allocated", C_ENOMEM );
    }

    ALLOC_ELEMS( num_elems, sv_addr );
        
    return sv_addr;
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

/* data assignment functions */
void _assign_DensePackedVector_from_ARRAY( SV* self, AV* array ) {
    
    SV_2STRUCT( self, Vector, v );
 
    /* verify size */
    size_t size  = (size_t) av_len( array ) + 1;

    if (size != v->size) {
        char reason[80];
        sprintf( reason, "Cannot assign %lu-element array to vector object: must have %lu elements\n", size, v->size );
        C_ERROR_VOID( reason, C_EINVAL );
    }

    int i = (long int) size;
    while ( --i >= 0 ) {
        double value = SvNV( *av_fetch( array, i , 0) );

        c_v_set_quick( v, i, value );
    }
}

void _assign_DensePackedVector_from_OBJECT( SV* self, SV* other ) {
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    if (!u->view_flag && !v->view_flag) {
        /* direct memcopy when it is safe to do so */
        Copy( v->elements, u->elements, (UV) u->size, double );
        return;
    } else { 
        c_vv_copy( u, v );
    } 
}

void _assign_DensePackedVector_from_NUMBER( SV* self, NV value ) {
    SV_2STRUCT( self, Vector, v );
    c_v_set_all( v, value );    
}

NV _packed_dot_product( SV* self, SV* other, UV from, UV length ) {
    SV_2STRUCT( self, Vector, a );
    SV_2STRUCT( other, Vector, b );

    return c_vv_dot_product( a, b, (size_t) from, (size_t) length ); 
}

void _assign_DensePackedVector_from_CODE( SV* self, SV* code ) {
    HV *stash;
    GV *gv;

    CV* cv = sv_2cv( code, &stash, &gv, 0);

    if (cv == Nullcv) {
        C_ERROR_VOID("Not a subroutine reference", C_EINVAL );
    }

    SV_2STRUCT( self, Vector, v);

    const size_t s = v->stride;
    size_t       i = v->zero;
    double * elems = v->elements;
	
    size_t k;
    for ( k = 0; k < v->size; k++ ) {
        dSP;

        PUSHMARK(SP);
	XPUSHs( sv_2mortal( newSVnv(elems[ i ])) );
        PUTBACK;

        call_sv((SV*)cv, G_SCALAR);
        elems[i] = SvNV( *PL_stack_sp );
	i += s;

        FREETMPS;
    }
}

void _assign_DensePackedVector_from_OBJECT_and_CODE( SV* self, SV* other, SV* code ) {
    HV *stash;
    GV *gv;

    CV* cv = sv_2cv( code, &stash, &gv, 0);

    if (cv == Nullcv) {
        C_ERROR_VOID("Not a subroutine reference", C_EINVAL );
    }

    SV_2STRUCT(  self, Vector, v);
    SV_2STRUCT( other, Vector, u);

    const size_t A_s = v->stride;
    const size_t B_s = u->stride;
    size_t       i = v->zero;
    size_t       j = u->zero;
    double * A_elems = v->elements;
    double * B_elems = u->elements;
	
    size_t k;
    for ( k = 0; k < v->size; k++ ) {
        dSP;

        PUSHMARK(SP);
	XPUSHs( sv_2mortal( newSVnv(A_elems[ i ]) ) );
        XPUSHs( sv_2mortal( newSVnv(B_elems[ j ]) ) );
	PUTBACK;

        call_sv((SV*)cv, G_SCALAR);

        A_elems[i] = SvNV( *PL_stack_sp );

        FREETMPS;

	i += A_s;
        j += B_s;
    }
}
void _packed_swap( SV* self, SV* other) {

    /* optimized element swapping between two packed vectors */
    SV_2STRUCT( self, Vector, u );
    SV_2STRUCT( other, Vector, v );

    c_vv_swap( u, v );
}

NV sum( SV* self ) {
    SV_2STRUCT( self, Vector, v );
    return c_v_sum( v );
}

SV* _sub_assign( SV* self, SV* other, SV* swap ) {
    SV_2STRUCT( self, Vector, u );

    if (!SvROK(other)) {
        c_v_add_constant( u, -( SvNV( other )));
    } else {
        SV_2STRUCT( other, Vector, v );
        c_vv_sub( u, v );
    }
    
    SvREFCNT_inc( self );
    return self;
}

SV* _add_assign( SV* self, SV* other, SV* swap ) {
    SV_2STRUCT( self, Vector, u );

    if (!SvROK(other)) {
        c_v_add_constant( u, SvNV( other ));
    } else {
        SV_2STRUCT( other, Vector, v );
        c_vv_add( u, v );
    }

    SvREFCNT_inc( self );
    return self;
}

SV* _div_assign( SV* self, SV* other, SV* swap ) {
    SV_2STRUCT( self, Vector, u );

    if (!SvROK(other)) {
        c_v_scale( u, 1 / SvNV( other ) );
    } else {
        SV_2STRUCT( other, Vector, v );
        c_vv_div( u, v );
    }

    SvREFCNT_inc( self );
    return self;
}

SV* _mul_assign( SV* self, SV* other, SV* swap ) {
    SV_2STRUCT( self, Vector, u );

    if (!SvROK(other)) {
        c_v_scale( u, SvNV( other ) );
    } else {
        SV_2STRUCT( other, Vector, v );
        c_vv_mul( u, v );
    }

    SvREFCNT_inc( self );
    return self;
}

void _dump( SV* self ) {
    SV_2STRUCT( self, Vector, v);

    c_v_show_struct( v );
}

END_OF_C_CODE

1;
