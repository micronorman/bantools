package Anorman::Data::Vector::DensePacked;

use strict;
use warnings;

use parent 'Anorman::Data::Vector';

use Anorman::Common qw(sniff_scalar);
use Anorman::Data::LinAlg::Property qw( :vector );

# I like dispatch tables...
my %ASSIGN_DISPATCH = (
	'NUMBER'      => \&_assign_DensePackedVector_from_NUMBER,
	'ARRAY'       => \&_assign_DensePackedVector_from_ARRAY,
	'OBJECT'      => \&_assign_DensePackedVector_from_OBJECT,
	'OBJECT+CODE' => \&Anorman::Data::Vector::_assign_Vector_from_OBJECT_and_CODE,
	'CODE'        => \&Anorman::Data::Vector::_assign_Vector_from_CODE
);

use overload 
	'+=' => \&_plus_assign;

sub new {
    my $class = shift;
    
    $class->_error("Wrong number of arguments") if (@_ != 1 && @_ != 4);

    my $self = &new_vector_object( ref $class || $class );

    if (@_ == 1) {
	my $type = sniff_scalar($_[0]);
    	if ($type eq 'ARRAY') {
		my $size = @{ $_[0] };
		$self->_setup( $size );
		$self->_set_elements_addr( $self->_alloc_elements( $size ) );
		$self->_assign_DensePackedVector_from_ARRAY( $_[0] );
	} elsif ($type eq 'NUMBER'){
                # construct empty vector
		my $size = $_[0];
		$self->_setup($size);
		$self->_set_elements_addr( $self->_alloc_elements( $size ) );
	}

    } else {
    	# set up view
	my ($size, $other, $zero, $stride) = @_;
	
	$self->_setup($size, $zero, $stride);
	$self->_set_elements_addr( $other->_get_elements_addr );
    }

    return $self;
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
	$self->_check_size( $other );

	$self->SUPER::swap( $other ) if ref $other ne 'Anorman::Data::Vector::DensePacked';

	$self->_packed_swap($other);


	1;
}

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Data::Vector::DensePacked',
		ENABLE    => AUTOWRAP =>
		LIBS      => '-L' . $Anorman::Common::AN_SRC_DIR . '/lib -lvector',
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include'
	   );
use Inline C => <<'END_OF_C_CODE';

#include "data.h"
#include "vector.h"

#include "../lib/vector.c"

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

/* object constructor */
SV* new_vector_object( SV* sv_class_name ) {

    Vector* v;

     /* set up object variables */
    char* class_name = SvPV_nolen( sv_class_name );
    SV*   self       = newSViv(0);
    SV*   obj        = newSVrv( self, class_name );

    /* allocate struct memory */
    Newxz(v, 1, Vector);

    /* set object address */
    sv_setiv( obj, (IV)v);
    SvREADONLY_on( obj );
    
    return self;
}

SV* _struct_clone( SV* self ) {
    SV_2VECTOR( self, v );

    Vector* n;

    char* class_name = sv_reftype( SvRV( self ), TRUE );

    SV*   clone      = newSViv(0);
    SV*   obj        = newSVrv( clone, class_name );

    Newx( n, 1, Vector );

    StructCopy( v, n, Vector );

    sv_setiv( obj, (IV) n );
    SvREADONLY_on( obj );

    return clone; 
}

/* object accessors */
IV size(SV* self) {
    return (UV) ((Vector*)SvIV(SvRV(self)))->size;
}

IV stride(SV* self) {
    return (IV) ((Vector*)SvIV(SvRV(self)))->stride;
}

IV zero(SV* self) {
    return (UV) ((Vector*)SvIV(SvRV(self)))->zero;
}

IV is_noview (SV* self) {
    return (IV) (((Vector*)SvIV(SvRV(self)))->view_flag == FALSE);
}


NV get_quick(SV* self, IV index) {

    SV_2VECTOR( self, v );
    
    return (NV) c_v_get_quick( v, (int) index );
}

void set_quick(SV* self, IV index, NV value) {
 
    SV_2VECTOR( self, v );

    c_v_set_quick( v, (int)index, (double)value );
}



/* object initializors */
void _setup( SV* self, SV* size, ... ) {
    Inline_Stack_Vars;

    if ( Inline_Stack_Items > 2 && Inline_Stack_Items != 4) {
        croak("_setup::Wrong number of arguments (%d)", (int) Inline_Stack_Items );
    }

    SV_2VECTOR( self, v );
    
    v->size = (size_t) SvIV( size );

    if ( items == 4 ) {
        v->zero      = (int) SvIV( Inline_Stack_Item(2) );
        v->stride    = (int) SvIV( Inline_Stack_Item(3) );
        v->view_flag = TRUE;
    } else {
        v->zero      = 0;
        v->stride    = 1;
        v->view_flag = FALSE;
    }    
}


SV* _alloc_elements( SV* self, UV num_elems ) {
    SV_2VECTOR( self, v );

    if ( v->elements != NULL ) {
        croak("Memory already allocated");
    }

    ALLOC_ELEMS( num_elems, sv_addr );
        
    return sv_addr;
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
        v->elements = (double*) elems_ptr;
    } else {
        PerlIO_printf( PerlIO_stderr(), "Cannot assign (%x) to an already assigned pointer (%p)\n", elems_ptr, v->elements );
    }   
}

/* data assignment functions */
void _assign_DensePackedVector_from_ARRAY( SV* self, AV* array ) {
    
    SV_2VECTOR( self,v );
 
    /* verify size */
    I32 size       = av_len( array ) + 1;

    if (size != (I32) v->size) {
        PerlIO_printf( PerlIO_stderr(), "Cannot assign array to vector object: must have %d elements\n", (int) v->size );
        my_exit(1);
    }

    ELEMS_BEG( elem, v );
    
    int i = size;
    while ( --i >= 0 ) {
        double value = SvNV( *av_fetch( array, i , 0) );
        c_v_set_quick( v, i, value );
    }
}

void _assign_DensePackedVector_from_OBJECT( SV* self, SV* other ) {
    SV_2VECTOR( self, u );
    SV_2VECTOR( other, v );

    if (u->view_flag == FALSE && v->view_flag == FALSE) {
        /* direct memcopy when it is safe to do so */
        Copy( v->elements, u->elements, (UV) u->size, double );
        return;
    } else { 
        c_vv_assign( u, v );
    } 
}

void _assign_DensePackedVector_from_NUMBER( SV* self, NV value ) {
    SV_2VECTOR( self, v );
    c_vn_assign( v, value );    
}

NV _packed_dot_product( SV* self, SV* other, IV from, IV length ) {
    SV_2VECTOR( self, a );
    SV_2VECTOR( other, b );

    return c_vv_dot_product( (int) a->size, a, b, (int) from, (int) length ); 
}

void _packed_swap( SV* self, SV* other) {

    /* optimized element swapping between two packed vectors */
    SV_2VECTOR( self, a );
    SV_2VECTOR( other, b );

    c_vv_swap( (int) a->size, a, b );
}

NV sum( SV* self ) {

    /* optimized summation of packed vector */
    Vector* v = (Vector*)SvIV(SvRV(self));
    return c_v_sum( v );
}

SV* _v_part( SV* self, SV* index, SV* width ) {
    SV_2VECTOR( self, v );

    dSP;

    ENTER;
    PUSHMARK( SP );
    XPUSHs( self );
    XPUSHs( index );
    XPUSHs( width );
    PUTBACK;

    call_method("Anorman::Data::Vector::_check_range", G_VOID );

    LEAVE;

    v->zero     += v->stride * SvIV( index );
    v->size      = SvIV( width );
    v->view_flag = TRUE;

    SvREFCNT_inc( self );	
    return self;
}

/* object destruction */
void DESTROY(SV* self) {
    SV_2VECTOR( self, v );

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
void show_struct( Vector* v ) {
    
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
