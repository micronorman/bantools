#include "data.h"
#include "vector.h"

/* quick retrieval and assignement 
 * NOTE: "quick" function assumes that 
 * all passed index values are within bounds
 */

double c_v_get_quick(Vector* v, int index) {
    double *elem = (double *) v->elements;
    return elem[ v->zero + v->stride * index ];
}

void c_v_set_quick( Vector* v, int index, double value ) {
    double *elem = (double *) v->elements;
    elem[ v->zero + v->stride * index ] = value;
}

/* fast arithmetic assignment functions */
void c_vv_plus_assign ( Vector* a, Vector* b ) {
    int i = (int) a->size;

    int a_stride = a->stride;
    int b_stride = b->stride;

    int a_index = a->zero;
    int b_index = b->zero;

    double* a_elem = (double*) a->elements;
    double* b_elem = (double*) b->elements;

    while (--i >= 0) {
        a_elem[ a_index ] += b_elem[ b_index ];
        a_index += a_stride;
        b_index += b_stride;
    } 
}

void c_vv_minus_assign ( Vector* a, Vector* b ) {
   int i = (int) a->size;

    int a_stride = a->stride;
    int b_stride = b->stride;

    int a_index = a->zero;
    int b_index = b->zero;

    double* a_elem = (double*) a->elements;
    double* b_elem = (double*) b->elements;

    while (--i >= 0) {
        a_elem[ a_index ] -= b_elem[ b_index ];
        a_index += a_stride;
        b_index += b_stride;
    } 
}

void c_vv_mult_assign ( Vector* a, Vector* b ) {
   int i = (int) a->size;

    int a_stride = a->stride;
    int b_stride = b->stride;

    int a_index = a->zero;
    int b_index = b->zero;

    double* a_elem = (double*) a->elements;
    double* b_elem = (double*) b->elements;

    while (--i >= 0) {
        a_elem[ a_index ] *= b_elem[ b_index ];
        a_index += a_stride;
        b_index += b_stride;
    } 
}

void c_vv_div_assign ( Vector* a, Vector* b ) {
   int i = (int) a->size;

    int a_stride = a->stride;
    int b_stride = b->stride;

    int a_index = a->zero;
    int b_index = b->zero;

    double* a_elem = (double*) a->elements;
    double* b_elem = (double*) b->elements;

    while (--i >= 0) {
        a_elem[ a_index ] /= b_elem[ b_index ];
        a_index += a_stride;
        b_index += b_stride;
    } 
}

void c_vv_assign ( Vector* a, Vector* b ) {
    int i = (int) a->size;

    int a_stride = a->stride;
    int b_stride = b->stride;

    int a_index = a->zero;
    int b_index = b->zero;

    double* a_elem = (double*) a->elements;
    double* b_elem = (double*) b->elements;

    while (--i >= 0) {
        a_elem[ a_index ] = b_elem[ b_index ];
        a_index += a_stride;
        b_index += b_stride;
    } 
}

void c_vn_assign ( Vector* a, double value ) {
    int i = (int) a->size;

    int a_stride = a->stride;
    int a_index = a->zero;

    double* a_elem = (double*) a->elements;

    while (--i >= 0) {
        a_elem[ a_index ] = value;
        a_index += a_stride;
    } 
}

double c_vv_dot_product ( int size, Vector* a, Vector* b, int from, int length ) {
    int tail = from + length;

    if (from < 0 || length < 0) return 0;
    if (size < tail) tail = size;
    if (b->size < tail) tail = b->size;

    int min = tail - from;

    int i = c_v_index(a, from);
    int j = c_v_index(b, from);
    
    int a_str = a->stride;
    int b_str = b->stride;

    double* a_elems = (double*) a->elements;
    double* b_elems = (double*) b->elements;

    long double sum = 0.0;

    /* loop unrolled for speed */
    i -= a_str;
    j -= b_str;

    int k = min / 4;
    while (--k >=0) {
        sum += a_elems[ i += a_str ] * b_elems[ j += b_str ];
        sum += a_elems[ i += a_str ] * b_elems[ j += b_str ];
        sum += a_elems[ i += a_str ] * b_elems[ j += b_str ];
        sum += a_elems[ i += a_str ] * b_elems[ j += b_str ];
    }
 
    k = min % 4;
    while (--k >= 0) {
        sum +=  a_elems[ i += a_str ] * b_elems[ j += b_str ];

    }

    return sum;
}

void c_vv_swap ( int size, Vector* a, Vector* b ) {

    /* swap elements between two vectors of equal length */
    double* a_elems = a->elements;
    double* b_elems = b->elements;

    int a_str = a->stride;
    int b_str = b->stride;

    int i = c_v_index(a, 0);
    int j = c_v_index(b, 0);

    int k = size;
    while ( --k >= 0) {
        double tmp = a_elems[ i ];
        a_elems[ i ] = b_elems[ j ];
        b_elems[ j ] = tmp;
        i += a_str;
        j += b_str;
    }
}

int c_v_index ( Vector* v, int rank ) {
    return v->zero + rank * v->stride;
}


/* quick unary vector functions */
double c_v_sum( Vector* v ) {
    double sum = 0.0;

    int s = v->stride;
    int i = c_v_index( v, 0 );

    double* elem = (double*) v->elements;

    int k = (int) v->size;

    while (--k >= 0) {
        sum += elem[i];
        i += s;
    }

    return sum;
}
