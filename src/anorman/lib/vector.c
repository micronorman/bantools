#include <stdio.h>
#include <stddef.h>

#include "data.h"
#include "error.h"
#include "vector.h"

/* quick retrieval and assignement 
 * NOTE: "quick" function assumes that 
 * all passed index values are within bounds
 */

/* arithmetic operations */

int
c_vv_add ( Vector *a, Vector *b ) {
    const size_t N = a->size;

    if (N != b->size) {
        C_ERROR("Vectors must have equal length", C_EINVAL );        
    } 

    const size_t a_stride = a->stride;
    const size_t b_stride = b->stride;

    size_t a_index = a->zero;
    size_t b_index = b->zero;

          double *a_elem = a->elements;
    const double *b_elem = b->elements;
    
    size_t i;

    for(i = 0; i < N; i++ ) {
        a_elem[ a_index ] += b_elem[ b_index ];
        a_index += a_stride;
        b_index += b_stride;
    } 

    return C_SUCCESS;
}

int
c_vv_sub ( Vector *a, Vector *b ) {
    const size_t N = a->size;

    if (N != b->size) {
        C_ERROR("Vectors must have equal length", C_EINVAL );        
    } 

    const size_t a_stride = a->stride;
    const size_t b_stride = b->stride;

    size_t a_index = a->zero;
    size_t b_index = b->zero;

          double *a_elem = a->elements;
    const double *b_elem = b->elements;
    
    size_t i;

    for(i = 0; i < N; i++ ) {
        a_elem[ a_index ] -= b_elem[ b_index ];
        a_index += a_stride;
        b_index += b_stride;
    } 

    return C_SUCCESS;
}

int
c_vv_mul ( Vector *a, Vector *b ) {
    const size_t N = a->size;

    if (N != b->size) {
        C_ERROR("Vectors must have equal length", C_EINVAL );        
    } 

    const size_t a_stride = a->stride;
    const size_t b_stride = b->stride;

    size_t a_index = a->zero;
    size_t b_index = b->zero;

          double *a_elem = a->elements;
    const double *b_elem = b->elements;
    
    size_t i;

    for(i = 0; i < N; i++ ) {
        a_elem[ a_index ] *= b_elem[ b_index ];
        a_index += a_stride;
        b_index += b_stride;
    } 

    return C_SUCCESS;
}

int
c_vv_div ( Vector *a, Vector *b ) {
    const size_t N = a->size;

    if (N != b->size) {
        C_ERROR("Vectors must have equal length", C_EINVAL );        
    } 

    const size_t a_stride = a->stride;
    const size_t b_stride = b->stride;

    size_t a_index = a->zero;
    size_t b_index = b->zero;

          double *a_elem = a->elements;
    const double *b_elem = b->elements;
    
    size_t i;

    for(i = 0; i < N; i++ ) {
        a_elem[ a_index ] /= b_elem[ b_index ];
        a_index += a_stride;
        b_index += b_stride;
    } 

    return C_SUCCESS;
}


int
c_v_scale ( Vector *a, const double x ) {
    const size_t N = a->size;
    const size_t a_stride = a->stride;

    size_t a_index = a->zero;

    double *a_elem = a->elements;
    
    size_t i;

    for (i = 0; i < N; i++) {
        a_elem[ a_index ] *= x;
        a_index += a_stride;
    }

    return C_SUCCESS; 
}

int
c_v_add_constant ( Vector *a, const double x ) {
    const size_t N = a->size;
    const size_t a_stride = a->stride;

    size_t a_index = a->zero;

    double *a_elem = a->elements;
    
    size_t i;

    for (i = 0; i < N; i++) {
        a_elem[ a_index ] += x;
        a_index += a_stride;
    }

    return C_SUCCESS; 
}

int
c_vv_copy ( Vector *a, Vector *b ) {
    const size_t N = a->size;

    if (N != b->size) {
        C_ERROR("Vectors must have equal length", C_EINVAL );        
    } 

    const size_t a_stride = a->stride;
    const size_t b_stride = b->stride;

    size_t a_index = a->zero;
    size_t b_index = b->zero;

          double *a_elem = a->elements;
    const double *b_elem = b->elements;
    
    size_t i;

    for(i = 0; i < N; i++ ) {
        a_elem[ a_index ] = b_elem[ b_index ];
        a_index += a_stride;
        b_index += b_stride;
    } 

    return C_SUCCESS;
}

int
c_vv_swap ( Vector *a, Vector *b ) {
    double *a_elems = a->elements;
    double *b_elems = b->elements;

    const size_t size  = a->size;
    const size_t a_str = a->stride;
    const size_t b_str = b->stride;

    size_t i = c_v_index(a, 0);
    size_t j = c_v_index(b, 0);

    if (a->size != b->size) {
        C_ERROR("Vector lengths must be equal", C_EINVAL );
    }
    
    size_t k;

    for (k = 0; k < size; k++) {
        double tmp = a_elems[ i ];
        a_elems[ i ] = b_elems[ j ];
        b_elems[ j ] = tmp;
        i += a_str;
        j += b_str;
    }

    return C_SUCCESS;
}


double
c_vv_dot_product ( Vector *a, Vector *b, const size_t from, const size_t length ) {
    size_t tail = from + length;

    if (a->size < tail) tail = a->size;
    if (b->size < tail) tail = b->size;

    const int min = (int) tail - from;

    size_t i = c_v_index(a, from);
    size_t j = c_v_index(b, from);
    
    const size_t a_str = a->stride;
    const size_t b_str = b->stride;

    const double *a_elems = a->elements;
    const double *b_elems = b->elements;

    double sum = 0.0;

    /* loop unrolled for speed */
    i -= a_str;
    j -= b_str;

    int k;
    for (k = min / 4; --k >=0; ) {
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



/* quick unary vector functions */
double
c_v_sum( Vector *v ) {
    double sum = 0.0;

    const size_t s = v->stride;
    size_t i = c_v_index( v, 0 );

    double* elem = v->elements;

    int k = (int) v->size;
    while (--k >= 0) {
        sum += elem[i];
        i += s;
    }

    return sum;
}

double *
c_v_alloc( Vector* v, const size_t n ) {
    double* _ELEMS;

    if (n == 0) {
        C_ERROR_VAL ("Vector length must be positive integer", C_EINVAL, 0);
    }

    if (v->elements != 0 ) {
        C_WARNING("Vector already contained allocated elements");
        return v->elements;
    }

    _ELEMS = (double *) calloc (1, n * sizeof (double));

    if (_ELEMS == 0) {
        C_ERROR_VAL("Failed to allocate elements for vector", C_ENOMEM, 0);
    }

    return _ELEMS;
}

Vector*
c_v_alloc_from_vector( Vector * w,
                       const size_t zero,
                       const size_t n,
                       const size_t stride) 
{
    Vector* v;
    
    if (n == 0) {
        C_ERROR_VAL ("Vector lenth n must be positive integer", C_EINVAL, 0);
    }

    if (stride == 0) {
        C_ERROR_VAL ("Stride must be positive integer", C_EINVAL, 0);
    }

    if (zero + (n - 1) * stride >= w->size) {
        C_ERROR_VAL ("New vector extends past end of elements", C_EINVAL, 0);
    }

    v = ((Vector*) malloc (sizeof (Vector)));

    if (v == 0) {
        C_ERROR_VAL ("Failed to allocate space for vector struct", C_ENOMEM, 0);

    }

    v->elements  = w->elements;
    v->zero      = w->zero + w->stride * zero;
    v->size      = n;
    v->stride    = stride * w->stride;
    v->view_flag = 1;
    
    return v;
}

void
c_v_set_all( Vector* v, double x ) {
    double* const elem = v->elements;
    const size_t n = v->size;
    const size_t s = v->stride;

    size_t i = c_v_index( v, 0 );

    size_t k;

    for (k = 0; k < n; k++ ) {
        elem[ i ] = x;
        i += s;
    }
}

void
c_v_free( Vector* v ) {

    if (!v) {
        return;
    }

    /* do not free elements if
       struct is a view         */
    if (v->elements && !v->view_flag) {
        free( v->elements );
	v->elements = NULL;
    }
  
    if (v->offsets) {
        free(v->offsets->offsets);
        free(v->offsets);
        v->offsets = NULL;
    } 

    free( v );
}

void
c_v_part( Vector* v, size_t from, size_t width ) {
    
    if (width == 0) {
        C_ERROR_VOID("Vector length must be positive integer", C_EINVAL );
    }

    if (from + (width - 1) >= v->size) {
        C_ERROR_VOID("View would extend past end of vector", C_EINVAL );
    }

    v->zero      += from * v->stride;
    v->size       = width;
    v->view_flag  = 1;
}
