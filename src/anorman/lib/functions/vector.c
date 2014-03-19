#include "data.h"
#include "vector.h"
#include "functions/functions.h"
#include "functions/vector.h"

double c_v_aggregate( size_t size, Vector* a, dd_func aggr, d_func f ) {

    long double result = (*f) ( c_v_get_quick( a, size - 1 ) );
    
    int i = (int) size - 1;

    while ( --i >= 0) {
        result = ( *aggr ) ( result, (*f) ( c_v_get_quick( a, i ) ) );
    }

    return result;
}

double c_v_aggregate_upto( size_t size, Vector* a, dd_func aggr, d_func f, double th ) {

    long double result = (*f) ( c_v_get_quick( a, size - 1 ) );
    
    int i = (int) size - 1;

    while ( --i >= 0) {
        if (result > th)
        break;
        result = ( *aggr ) ( result, (*f) ( c_v_get_quick( a, i ) ) );
    }

    return result;
}

double c_v_mean( size_t size, Vector* v ) {
   return ( c_v_aggregate( size, v, &c_plus, &c_identity ) / size );
    
}

double c_v_variance( size_t size, Vector* v ) {
    double mean = c_v_mean( size, v );

    return (c_v_aggregate( size, v, &c_plus, &c_square )
            - mean * c_v_aggregate( size, v, &c_plus, &c_identity )) / (double) (size - 1);
}

double c_v_variance2( size_t size, Vector* v ) {
    long double variance = 0;

    double mean = c_v_mean( size, v );

    int i = c_v_index( v, 0 );
    int s = v->stride;

    double* elems = v->elements;

    int k;

    for ( k = 0; k < size; k++) {
        const double delta = (elems[ i ] - mean);
        variance += (delta * delta - variance) / (double) (k + 1);
        i += s;
    }

    return (double) variance * ((double)size / (double)(size -1));
}

void c_v_div_assign ( size_t size, Vector* v, double value ) {
    size_t s = v->stride;
    size_t i = c_v_index( v, 0 );

    double* elems = (double*) v->elements;

    int k = (int) v->size;
    while ( --k >= 0) {
        elems[ i ] /= value;
        i += s;
    }
}
