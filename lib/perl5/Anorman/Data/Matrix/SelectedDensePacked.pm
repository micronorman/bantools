package Anorman::Data::Matrix::SelectedDensePacked;

use strict;

use parent 'Anorman::Data::Matrix';

use Anorman::Common;
use Anorman::Data::Matrix::DensePacked;
use Anorman::Data::Vector::SelectedDensePacked;
use Anorman::Data::LinAlg::Property qw(is_packed);

sub new {
	my $class = shift;

	if (@_ != 4 && @_ != 10) {
		$class->_error("Wrong number of arguments");
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

	my $self = &new_selectedmatrix_object( ref($class) || $class );
	
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

	$self->_setup( $rows, $columns, $row_zero, $column_zero, $row_stride, $column_stride, $offset, $row_offsets, $column_offsets );
	$self->_set_elements_addr( $elems );

	return $self;
}

sub view_row {
	my ($self, $row) = @_;
	$self->_check_row( $row );
	
	my $vsize    = $self->columns;
	my $vzero    = $self->column_zero;
	my $vstride  = $self->column_stride;
	my $voffsets = $self->column_offsets;
	my $voffset  = $self->offset + $self->_row_offset( $self->_row_rank( $row ) );

	return Anorman::Data::Vector::SelectedDensePacked->new( $vsize, $self->_get_elements_addr, $vzero, $vstride, $voffsets, $voffset );
}

sub view_column {
	my ($self, $column) = @_;
	$self->_check_column( $column );

	my $vsize    = $self->rows;
	my $vzero    = $self->row_zero;
	my $vstride  = $self->row_stride;
	my $voffsets = $self->row_offsets;
	my $voffset  = $self->offset + $self->_column_offset( $self->_column_rank( $column ) );

	return Anorman::Data::Vector::SelectedDensePacked->new( $vsize, $self->_get_elements_addr, $vzero, $vstride, $voffsets, $voffset );
}

sub _view_selection_like {
	my $self = shift;
	return $self->new( $self->_get_elements_addr, $self->row_offsets, $self->column_offsets, $self->offset );
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
        return Anorman::Data::Vector::DensePacked->new($_[0], $self, $_[1], $_[2]);
}

sub _have_shared_cells_raw {
	my ($self, $other) = @_;

	return undef unless (is_packed($self) && is_packed($other));
	return $self->_get_elements_addr == $other->_get_elements_addr;
}

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Data::Matrix::SelectedDensePacked',
		ENABLE    => AUTOWRAP =>
		LIBS      => '-L' . $Anorman::Common::AN_SRC_DIR . '/lib -lmatrix',
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include'

           );

use Inline C => <<'END_OF_C_CODE';

#include "data.h"

#define SV_2SELECTEDMATRIX( sv, ptr_name )    SelectedMatrix* ptr_name = (SelectedMatrix*) SvIV( SvRV( sv ) )

#define SVADDR_2PTR( sv_name, ptr_name )            \
     UV ptr_name = INT2PTR( double*, SvUV( sv_name ) ) 

#define PTR_2SVADDR( ptr_name, sv_name )        \
    SV* sv_name = newSVuv( PTR2UV( ptr_name ) )

SV*  _get_elements_addr( SV* );
void _set_elements_addr( SV*, SV* );

void static  show_struct( SelectedMatrix* );

/* object constructors */
SV* new_selectedmatrix_object( SV* sv_class_name ) {

    /* the central Matrix struct */
    SelectedMatrix* m;

    /* set up object variables */
    char* class_name = SvPV_nolen( sv_class_name );
    SV*   self       = newSViv(0);
    SV*   obj        = newSVrv( self, class_name );

    /* allocate struct memory */
    Newxz(m, 1, SelectedMatrix);

    /* set object address */
    sv_setiv( obj, (IV)m);
    SvREADONLY_on( obj );

    return self;
}

SV* _struct_clone( SV* self ) {
    SV_2SELECTEDMATRIX( self, m );

    SelectedMatrix* n;

    char* class_name = sv_reftype( SvRV( self ), TRUE );

    SV*   clone      = newSViv(0);
    SV*   obj        = newSVrv( clone, class_name );

    Newx( n, 1, SelectedMatrix );

    StructCopy( m, n, SelectedMatrix );

    sv_setiv( obj, (IV) n );
    SvREADONLY_on( obj );

    return clone; 
}

/* object accessors (for perl calls) */
UV rows(SV* self) {
    return (UV) ((SelectedMatrix*)SvIV(SvRV(self)))->rows;
}

UV columns(SV* self) {
    return (UV) ((SelectedMatrix*)SvIV(SvRV(self)))->columns;
}

UV row_zero(SV* self) {
    return (UV) ((SelectedMatrix*)SvIV(SvRV(self)))->row_zero;
}

UV column_zero(SV* self) {
    return (UV) ((SelectedMatrix*)SvIV(SvRV(self)))->column_zero;
}

IV row_stride(SV* self) {
    return (IV) ((SelectedMatrix*)SvIV(SvRV(self)))->row_stride;
}

IV column_stride(SV* self) {
    return (IV) ((SelectedMatrix*)SvIV(SvRV(self)))->column_stride;
}

IV offset(SV* self) {
    return (IV) ((SelectedMatrix*)SvIV(SvRV(self)))->offset;
}

SV* row_offsets(SV* self) {
    
    SV_2SELECTEDMATRIX( self, m );

    AV* av_row_offsets = newAV();

    int* row_offsets = (int*) m->row_offsets;

    int i;
    for (i = 0; i < m->rows; i++) {
        av_push( av_row_offsets, newSViv( row_offsets[ i ] ) );
    }

    return newRV_noinc((SV*) av_row_offsets );
}

SV* column_offsets(SV* self) {
    SV_2SELECTEDMATRIX( self, m );

    AV* av_column_offsets = newAV();

    int* column_offsets = (int*) m->column_offsets;

    int i;
    for (i = 0; i < m->columns; i++) {
        av_push( av_column_offsets, newSViv( column_offsets[ i ] ) );
    }

    return newRV_noinc((SV*) av_column_offsets );
}

UV _is_noview (SV* self) {
    return (UV) (((SelectedMatrix*)SvIV(SvRV(self)))->view_flag == FALSE);
}

NV get_quick(SV* self, IV row, IV column) {
    /* NOTE:  Assumes that index is always
       is within array boundary */
    SV_2SELECTEDMATRIX( self, m );
   
       int* roffs = (int*) m->row_offsets;
       int* coffs = (int*) m->column_offsets;
    double* elems = (double*) m->elements;

    return (NV) elems[ m->offset + roffs[ m->row_zero + row * m->row_stride ] + coffs[ m->column_zero + column * m->column_stride ] ];
}

void set_quick(SV* self, IV row, IV column, NV value) {
    SV_2SELECTEDMATRIX( self, m );
       int* roffs = (int*) m->row_offsets;
       int* coffs = (int*) m->column_offsets;
    double* elems = (double*) m->elements;

    elems[ m->offset + roffs[ m->row_zero + row * m->row_stride ] + coffs[ m->column_zero + column * m->column_stride ] ] = (double) value;
}

/* object initializors */
void _setup ( SV* self,
              UV rows,
              UV columns,
              UV row_zero,
              UV column_zero,
              IV row_stride,
              IV column_stride,
              IV offset,
              AV* av_row_offsets,
              AV* av_column_offsets
            ) {

    SV_2SELECTEDMATRIX( self, m);

    m->rows          = (size_t) rows;
    m->columns       = (size_t) columns;
    m->row_zero      = (int) row_zero;
    m->column_zero   = (int) column_zero;
    m->row_stride    = (int) row_stride;
    m->column_stride = (int) column_stride;
    m->offset        = (int) offset;
    m->view_flag     = TRUE;

    int* row_offsets;   
    int* column_offsets;

    int ro_size = av_len( av_row_offsets ) + 1;
    int co_size = av_len( av_column_offsets ) + 1;

    /* allocate memory for row and column offsets */
    Newx( row_offsets, ro_size, int ); 
    Newx( column_offsets, co_size, int );

    /* assign row offsets */
    int i = ro_size;
    while ( --i >= 0 ) {
        row_offsets[ i ] = (int) SvIV( *av_fetch( av_row_offsets, i, 0) );
    }

    m->row_offsets = (char*) row_offsets;

    /* assign column offsets */
    i = co_size;
    while ( --i >= 0 ) {
        column_offsets[ i ] = (int) SvIV( *av_fetch( av_column_offsets, i, 0) );
    }

    m->column_offsets = (char*) column_offsets;
}

/* elements pointer address manipulation */
SV* _get_elements_addr (SV* self) {

    SV_2SELECTEDMATRIX( self, m );
    PTR_2SVADDR( m->elements, sv_addr );

    return sv_addr;
}

void _set_elements_addr (SV* self, SV* sv_addr ) {

    SVADDR_2PTR( sv_addr, elems_ptr );
    SV_2SELECTEDMATRIX( self, m );

    /* some sanity checls */
    if (m->elements == NULL) {
        m->elements = (double*) elems_ptr;
    } else {
        PerlIO_printf( PerlIO_stderr(), "Cannot assign (%x) to an already assigned pointer (%p)\n", elems_ptr, m->elements );
    }
}

IV _index (SV* self, UV row, UV column) {
    SV_2SELECTEDMATRIX( self, m );
 
      int* roffs = (int*) m->row_offsets;
      int* coffs = (int*) m->column_offsets;

    return m->offset + roffs[ m->row_zero + row * m->row_stride ] + coffs[ m->column_zero + column * m->column_stride ];
}

IV _row_offset (SV* self, IV abs_rank ) {
    SV_2SELECTEDMATRIX( self, m );

    int* row_offsets = (int*) m->row_offsets;
    return (IV) row_offsets[ abs_rank ];
}


IV _column_offset (SV* self, IV abs_rank ) {
    SV_2SELECTEDMATRIX( self, m );

    int* column_offsets = (int*) m->column_offsets;
    return (IV) column_offsets[ abs_rank ];
}

SV* _v_dice( SV* self ) {
    SV_2SELECTEDMATRIX( self, m );
    int tmp;
   
    tmp = m->rows;       m->rows = m->columns;             m->columns = tmp;
    tmp = m->row_stride; m->row_stride = m->column_stride; m->column_stride = tmp;
    tmp = m->row_zero;   m->row_zero = m->column_zero;     m->column_zero = tmp;

    int* tmp_offsets = m->row_offsets; m->row_offsets = m->column_offsets; m->column_offsets = tmp_offsets;

    m->view_flag = TRUE;
    
    SvREFCNT_inc( self );
    return self;
}

/* object destruction */
void DESTROY(SV* self) {
    SV_2SELECTEDMATRIX( self, m );

    if (m->row_offsets != NULL) {
        Safefree( m->row_offsets );
        Safefree( m->column_offsets );
    }

    Safefree( m );
}

/* DEBUGGING */
void show_struct( SelectedMatrix* m ) {
    
    PerlIO_printf( PerlIO_stderr(), "\nContents of Matrix struct:\n" );
    PerlIO_printf( PerlIO_stderr(), "\trows\t(%p): %d\n", &m->rows, (int) m->rows );
    PerlIO_printf( PerlIO_stderr(), "\tcols\t(%p): %d\n", &m->columns, (int) m->columns );
    PerlIO_printf( PerlIO_stderr(), "\tview\t(%p): %d\n", &m->view_flag, (int) m->view_flag );
    PerlIO_printf( PerlIO_stderr(), "\tr0\t(%p): %d\n",  &m->row_zero, m->row_zero );
    PerlIO_printf( PerlIO_stderr(), "\tc0\t(%p): %d\n", &m->column_zero, m->row_zero );
    PerlIO_printf( PerlIO_stderr(), "\trstride\t(%p): %d\n", &m->row_stride, m->row_stride );
    PerlIO_printf( PerlIO_stderr(), "\tcstride\t(%p): %d\n", &m->column_stride, m->column_stride );
    PerlIO_printf( PerlIO_stderr(), "\toffset\t(%p): %d\n", &m->offset, m->offset );

    if (m->row_offsets == NULL) {
        PerlIO_printf( PerlIO_stderr(), "\troffs\t(%p): null\n",  &m->row_offsets );
    } else {
        PerlIO_printf( PerlIO_stderr(), "\troffs\t(%p): [ %p ]\n",  &m->row_offsets, m->row_offsets );
    }
    if (m->column_offsets == NULL) {
        PerlIO_printf( PerlIO_stderr(), "\tcoffs\t(%p): null\n",  &m->column_offsets );
    } else {
        PerlIO_printf( PerlIO_stderr(), "\tcoffs\t(%p): [ %p ]\n",  &m->column_offsets, m->column_offsets );
    }

    if (m->elements == NULL) {
        PerlIO_printf( PerlIO_stderr(), "\telems\t(%p): null\n\n",  &m->elements );
    } else {
        PerlIO_printf( PerlIO_stderr(), "\telems\t(%p): [ %p ]\n\n",  &m->elements, m->elements );
    }
}

END_OF_C_CODE

1;

