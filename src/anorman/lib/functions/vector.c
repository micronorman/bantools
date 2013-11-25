#include "data.h"
#include "vector.h"
#include "functions/functions.h"
#include "functions/vector.h"

double c_v_aggregate( int size, Vector* a, dd_func aggr, d_func f ) {

    double result = (*f) ( c_v_get_quick( a, size - 1 ) );
    
    int i = size - 1;

    while ( --i >= 0) {
        result = ( *aggr ) ( result, (*f) ( c_v_get_quick( a, i ) ) );
    }

    return result;
}

double c_v_aggregate_upto( int size, Vector* a, dd_func aggr, d_func f, double th ) {

    double result = (*f) ( c_v_get_quick( a, size - 1 ) );
    
    int i = size - 1;

    while ( --i >= 0) {
        if (result > th)
        break;
        result = ( *aggr ) ( result, (*f) ( c_v_get_quick( a, i ) ) );
    }

    return result;
}

double c_v_mean( int size, Vector* v ) {
   return ( c_v_aggregate( size, v, &c_plus, &c_identity ) / size );
    
}

double c_v_variance( int size, Vector* v ) {
    double mean = c_v_mean( size, v );

    return (c_v_aggregate( size, v, &c_plus, &c_square )
            - mean * c_v_aggregate( size, v, &c_plus, &c_identity )) / (size - 1);
}

void c_v_div_assign ( int size, Vector* v, double value ) {
    int s = v->stride;
    int i = c_v_index( v, 0 );

    double* elems = (double*) v->elements;

    int k =v->size;
    while ( --k >= 0) {
        elems[ i ] /= value;
        i += s;
    }
}
