#ifndef __ANORMAN_VECTOR_H__
#define __ANORMAN_VECTOR_H__
#include "data.h"

double* c_v_ptr(Vector*, const size_t );
double c_v_get_quick(Vector*, const size_t);
void c_v_set_quick( Vector* , const size_t , double );
size_t c_v_index( Vector*, size_t );

/* Operations */
int c_vv_add ( Vector*, Vector* );
int c_vv_sub ( Vector*, Vector* );
int c_vv_mul ( Vector*, Vector* );
int c_vv_div ( Vector*, Vector* );
int c_v_add_constant ( Vector*, const double );
int c_v_scale ( Vector* a, const double );


int c_vv_copy ( Vector* , Vector* );
int c_vv_swap ( Vector* , Vector* );

double c_v_sum( Vector* );
double c_vv_dot_product ( Vector* a, Vector* b, size_t from, size_t length );


double* c_v_alloc( Vector*, const size_t );
void c_v_set_all( Vector*, double );
void c_v_free( Vector* );

void c_v_show_struct( Vector* );

double* 
c_v_ptr(Vector *v, const size_t rank) {
    c_v_show_struct( v );
    return (double *) (v->elements + (v->zero + rank * v->stride));
}

double
c_v_get_quick(Vector *v, size_t index) {
    double *elems = v->elements;

    if (v->offsets) {
        size_t* offs  = v->offsets->offsets;
        return elems[ v->offsets->offset + offs[ v->zero + index * v->stride ] ]; 
    } else {
        return elems[ v->zero + v->stride * index ];
    }
}

void
c_v_set_quick( Vector *v, size_t index, const double value ) {
    double *elems = v->elements;
    if (v->offsets) {
        size_t* offs  = v->offsets->offsets;
        elems[ v->offsets->offset + offs[ v->zero + index * v->stride ] ] = value;
    } else {
        elems[ v->zero + v->stride * index ] = value;
    }
}

size_t
c_v_index ( Vector *v, size_t rank ) {
    if (v->offsets) {
        size_t* offsets = v->offsets->offsets;
        return v->offsets->offset + offsets[ v->zero + rank * v->stride ];
    } else {
        return v->zero + rank * v->stride;
    }
}

/* Good for debugging */
void
c_v_show_struct( Vector* v ) {
    fprintf(stderr, "\nContents of Vector struct: (%p)\n", v);
    fprintf(stderr, "\tsize\t(%p): %lu\n", &v->size, v->size );
    fprintf(stderr, "\tzero\t(%p): %lu\n",  &v->zero, v->zero );
    fprintf(stderr, "\tstride\t(%p): %lu\n", &v->stride, v->stride );

    if (!v->elements) {
        fprintf(stderr, "\telems\t(%p): null\n",  &v->elements );
    } else {
        fprintf(stderr, "\telems\t(%p): [ %p ]\n",  &v->elements, v->elements );
    }

    if (!v->offsets) {
        fprintf( stderr, "\toffsets\t(%p): null\n", &v->offsets );
    } else {
        fprintf( stderr, "\toffsets\t(%p): [ %p ]\n", &v->offsets, v->offsets );
    }

    fprintf(stderr, "\tview\t(%p): %i\n\n", &v->view_flag, v->view_flag );
}
#endif
