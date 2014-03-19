#ifndef __ANORMAN_PERL2C_H__
#define __ANORMAN_PERL2C_H__

#include "ppport.h"

/* Defines. extract struct from Perl scalars */
#define SV_2MATRIX( sv, ptr_name )    Matrix* ptr_name = (Matrix*) SvIV( SvRV( sv ) )
#define SV_2VECTOR( sv, ptr_name )    Vector* ptr_name = (Vector*) SvIV( SvRV( sv ) )
#define SV_2SELECTEDMATRIX( sv, ptr_name )    SelectedMatrix* ptr_name = (SelectedMatrix*) SvIV( SvRV( sv ) )
#define SV_2SELECTEDVECTOR( sv, ptr_name )    SelectedVector* ptr_name = (SelectedVector*) SvIV( SvRV( sv ) )
#define SV_2STRUCT( sv, TYPE, ptr_name ) TYPE* ptr_name = (TYPE*) SvIV( SvRV( sv ) )

#define SVADDR_2PTR( sv_name, ptr_name )            \
     double* ptr_name = INT2PTR( double*, SvUV( sv_name ) ) 

#define PTR_2SVADDR( ptr_name, sv_name )        \
    SV* sv_name = newSVuv( PTR2UV( ptr_name ) )

#define ALLOC_ELEMS( slots, sv_name )          \
    double* _ELEMS;                            \
    Newxz( _ELEMS, slots, double );            \
    PTR_2SVADDR( _ELEMS, sv_name )

#define BLESS_STRUCT( x, sv_name, class_name ) \
    sv_name = newSViv(0);                      \
    SV* obj = newSVrv( sv_name, class_name );  \
    sv_setiv( obj, (IV) x );                   \
    SvREADONLY_on( obj );

#endif
