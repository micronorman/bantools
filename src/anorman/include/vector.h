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


double* 
c_v_ptr(Vector *v, const size_t rank) {
    return (double *) (v->elements + v->zero + rank * v->stride);
}

double
c_v_get_quick(Vector *v, size_t index) {
    double *elem = v->elements;
    return elem[ v->zero + v->stride * index ];
}

void
c_v_set_quick( Vector *v, size_t index, const double value ) {
    double *elem = v->elements;
    elem[ v->zero + v->stride * index ] = value;
}

size_t
c_v_index ( Vector *v, size_t rank ) {
    return v->zero + rank * v->stride;
}

#endif
