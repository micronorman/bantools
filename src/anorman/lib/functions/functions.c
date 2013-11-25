#include "functions/functions.h"

/* binary functions */
double c_plus( double a, double b ) {
    return a + b;
}

double c_minus( double a, double b ) {
    return a - b;
}

double c_multiply( double a, double b ) {
    return a * b;
}

double c_divide( double a, double b ) {
    assert( b != 0 ); 
    return a / b; 
}

double c_abs_diff( double a, double b ) {
    return abs( a - b );
}

double c_square_diff( double a, double b ) {
    double diff = a - b;
    return (diff * diff);
}

double c_max( double a, double b ) {
    return a > b ? a : b;
}

double c_min( double a, double b ) {
    return a < b ? a : b;
}

/* unary functions */
double c_identity( double a ) {
    return a;
}

double c_abs( double a ) {
    return abs( a );
}

double c_square( double a ) {
    return (a * a);
}
