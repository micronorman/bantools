#ifndef ANORMAN_FUNCTIONS_FUNCTIONS_H
#define ANORMAN_FUNCTIONS_FUNCTIONS_H
/* define function pointers */
typedef double ( *d_func ) ( double );
typedef double ( *dd_func ) (double, double );

double c_plus ( double, double );
double c_minus ( double, double );
double c_multiply ( double, double );
double c_divide ( double, double );
double c_max ( double, double );
double c_min ( double, double );
double c_abs_diff( double, double );

double c_identity( double );
double c_abs( double );
double c_square( double );

#endif

