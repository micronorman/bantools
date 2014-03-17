#include "vector.h"
#include "functions/functions.h"
#include "functions/vector.h"
#include "functions/vectorvector.h"

/* aggregate functions that return a double */

double c_vv_aggregate_quick( int size, Vector* a, Vector* b, dd_func aggr, dd_func f ) {
    
    if (a->size != b->size)
    croak("Different vector sizes");

    long double result = (*f) ( c_v_get_quick( a, size - 1 ), c_v_get_quick( b, size - 1 ) );
    
    int i = size - 1;
    while ( --i >= 0) {
        result = ( *aggr ) ( result, (*f) ( c_v_get_quick( a, i ), c_v_get_quick( b, i ) ) );
    }

    return result;
}

double c_vv_aggregate_quick_upto( int size, Vector* a, Vector* b, dd_func aggr, dd_func f, double threshold ) {

    if (a->size != b->size)
    croak("Different vector sizes");
    
    long double result = (*f) ( c_v_get_quick( a, size - 1 ), c_v_get_quick( b, size - 1 ) );
    
    int i = size - 1;
    while ( --i >= 0) {
        if (result > threshold)
        break;
        result = ( *aggr ) ( result, (*f) ( c_v_get_quick( a, i ), c_v_get_quick( b, i ) ) );
    }

    return result;
}

double c_vv_covariance( int size, Vector* a, Vector* b ) {
    const double ma = c_v_mean( size, a );
    const double mb = c_v_mean( size, b );
   
    long double covariance = 0;

    int i;
    for (i = 0; i < size; i++) {
        const long double delta1 = c_v_get_quick( a, i ) - ma;
        const long double delta2 = c_v_get_quick( b, i ) - mb;
        covariance += ( delta1 * delta2 - covariance) / (i + 1);
        /* sum += ( c_v_get_quick( a, i ) - ma ) * ( c_v_get_quick( b, i ) - mb ) */;
    }

    /* return ( sum / ( size - 1 ) )*/;
    return (double) covariance * ((double)size / (double)(size -1));
}

void c_vv_plusmult_assign( int size, Vector* a, Vector* b, int multiplicator ) {
    double* a_elems = (double*) a->elements;
    double* b_elems = (double*) b->elements;

    int a_str = a->stride;
    int b_str = b->stride;

    int a_index = c_v_index(a, 0);
    int b_index = c_v_index(b, 0);

    if (multiplicator == 1) {
        int k = size;
        while (--k >= 0) {
             a_elems[ a_index ] += b_elems[ b_index ];
             a_index += a_str;
             b_index += b_str; 
        }
    }
    else if (multiplicator == 0) {
        return;
    }
    else if (multiplicator == -1) {
        int k = size;
        while (--k >= 0) {
             a_elems[ a_index ] -= b_elems[ b_index ];
             a_index += a_str;
             b_index += b_str; 
        }
    }
    else {
        int k = size;
        while (--k >= 0) {
             a_elems[ a_index ] += multiplicator * b_elems[ b_index ];
             a_index += a_str;
             b_index += b_str;
        } 
    }
}

void c_vv_func_assign( int size, Vector* a, Vector* b, dd_func function ) {
    double* a_elems = (double*) a->elements;
    double* b_elems = (double*) b->elements;

    int a_str = a->stride;
    int b_str = b->stride;

    int a_index = c_v_index(a, 0);
    int b_index = c_v_index(b, 0);

    int k = size;
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
double c_vv_dist_manhattan( int size, Vector* a, Vector* b ) {

    dd_func aggr = (dd_func) &c_plus;
    dd_func f    = (dd_func) &c_abs_diff;

    return c_vv_aggregate_quick( size, a, b, aggr, f );
}

/* Manhattan distance with threshold */
double c_vv_dist_manhattan_upto( int size, Vector* a, Vector* b, double threshold ) {
 
    dd_func aggr = (dd_func) &c_plus;
    dd_func f    = (dd_func) &c_abs_diff;

    return c_vv_aggregate_quick_upto( size, a, b, aggr, f, threshold );
}

/* Euclidean distance */
double c_vv_dist_euclidean( int size, Vector* a, Vector* b ) {

    return sqrt( c_vv_q_dist_euclidean( size, a, b ) ); 
}

double c_vv_squared_dist_euclidean( int size, Vector* a, Vector* b ) {

    dd_func aggr = (dd_func) &c_plus;
    dd_func    f = (dd_func) &c_square_diff;

    return c_vv_aggregate_quick( size, a, b, aggr, f );
}

/* Euclidean distance with threshold */
double c_vv_dist_euclidean_upto( int size, Vector* a, Vector* b, double threshold ) {

    dd_func aggr = (dd_func) &c_plus;
    dd_func    f = (dd_func) &c_square_diff;

    threshold = (threshold * threshold);

    return sqrt( c_vv_aggregate_quick_upto( size, a, b, aggr, f, threshold ) ); 
}

