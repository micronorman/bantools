#include "vector.h"
#include "functions/functions.h"
#include "functions/vector.h"
#include "functions/vectorvector.h"

/* aggregate functions that return a double */

double c_vv_aggregate_quick( size_t size, Vector* a, Vector* b, dd_func aggr, dd_func f ) {
    long double result = (*f) ( c_v_get_quick( a, size - 1 ), c_v_get_quick( b, size - 1 ) );
    
    int i = (int) size - 1;
    while ( --i >= 0) {
        result = ( *aggr ) ( result, (*f) ( c_v_get_quick( a, i ), c_v_get_quick( b, i ) ) );
    }

    return result;
}

double c_vv_aggregate_quick_upto( size_t size, Vector* a, Vector* b, dd_func aggr, dd_func f, double threshold ) {
    long double result = (*f) ( c_v_get_quick( a, size - 1 ), c_v_get_quick( b, size - 1 ) );
    
    int i = (int) size - 1;
    while ( --i >= 0) {
        if (result > threshold)
        break;
        result = ( *aggr ) ( result, (*f) ( c_v_get_quick( a, i ), c_v_get_quick( b, i ) ) );
    }

    return result;
}

double c_vv_covariance( size_t size, Vector* a, Vector* b ) {
    const double ma = c_v_mean( size, a );
    const double mb = c_v_mean( size, b );
   
    long double covariance = 0;

    size_t i;
    for (i = 0; i < size; i++) {
        const long double delta1 = c_v_get_quick( a, i ) - ma;
        const long double delta2 = c_v_get_quick( b, i ) - mb;

        covariance += ( delta1 * delta2 - covariance) / (double) (i + 1);
    }

    return covariance * ((double)size / (double)(size -1));
}

void c_vv_plusmult_assign( size_t size, Vector* a, Vector* b, double multiplicator ) {
    double* const a_elems = a->elements;
    double* const b_elems = b->elements;

    const size_t a_str = a->stride;
    const size_t b_str = b->stride;

    size_t a_index = c_v_index(a, 0);
    size_t b_index = c_v_index(b, 0);

    if (multiplicator == 1) {
        int k = (int) size;
        while (--k >= 0) {
             a_elems[ a_index ] += b_elems[ b_index ];
             a_index += a_str;
             b_index += b_str; 
        }
    } else if (multiplicator == 0) {
        return;
    } else if (multiplicator == -1) {
        int k = (int) size;
        while (--k >= 0) {
             a_elems[ a_index ] -= b_elems[ b_index ];
             a_index += a_str;
             b_index += b_str; 
        }
    } else {
        int k = (int) size;
        while (--k >= 0) {
             a_elems[ a_index ] += multiplicator * b_elems[ b_index ];
             a_index += a_str;
             b_index += b_str;
        } 
    }
}

void c_vv_func_assign( size_t size, Vector* a, Vector* b, dd_func function ) {
    double* const a_elems = a->elements;
    double* const b_elems = b->elements;

    const size_t a_str = a->stride;
    const size_t b_str = b->stride;

    size_t a_index = c_v_index(a, 0);
    size_t b_index = c_v_index(b, 0);

    int k = (int) size;
    while (--k >= 0) {
         a_elems[ a_index ] += (*function) ( a_elems[ a_index ], b_elems[ b_index ] );
         a_index += a_str;
         b_index += b_str; 
    }
}

/*****************************
 *                           *
 * Vector Distance Functions *
 *                           *
 *****************************/


/* Manhattan distance */
double c_vv_dist_manhattan( size_t size, Vector* a, Vector* b ) {

    dd_func aggr = (dd_func) &c_plus;
    dd_func f    = (dd_func) &c_abs_diff;

    return c_vv_aggregate_quick( size, a, b, aggr, f );
}

/* Manhattan distance with threshold */
double c_vv_dist_manhattan_upto( size_t size, Vector* a, Vector* b, double threshold ) {
 
    dd_func aggr = (dd_func) &c_plus;
    dd_func f    = (dd_func) &c_abs_diff;

    return c_vv_aggregate_quick_upto( size, a, b, aggr, f, threshold );
}

/* Euclidean distance */
double c_vv_dist_euclidean( size_t size, Vector* a, Vector* b ) {

    return sqrt( c_vv_squared_dist_euclidean( size, a, b ) ); 
}

double c_vv_squared_dist_euclidean( size_t size, Vector* a, Vector* b ) {

    dd_func aggr = (dd_func) &c_plus;
    dd_func    f = (dd_func) &c_square_diff;

    return c_vv_aggregate_quick( size, a, b, aggr, f );
}

/* Euclidean distance with threshold */
double c_vv_dist_euclidean_upto( size_t size, Vector* a, Vector* b, double threshold ) {

    dd_func aggr = (dd_func) &c_plus;
    dd_func    f = (dd_func) &c_square_diff;

    threshold = (threshold * threshold);

    return sqrt( c_vv_aggregate_quick_upto( size, a, b, aggr, f, threshold ) ); 
}

