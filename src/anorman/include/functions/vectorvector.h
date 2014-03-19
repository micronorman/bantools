#ifndef __ANORMAN_FUNCTIONS_VECTORVECTOR_H__
#define __ANORMAN_FUNCTIONS_VECTORVECTOR_H__

#include "data.h"
#include "functions/functions.h"

typedef double ( *vv_func ) ( int, Vector*, Vector* );
typedef double ( *vv_thr_func ) ( int, Vector*, Vector*, double );

double c_vv_aggregate_quick( int, Vector*, Vector*, dd_func, dd_func );
double c_vv_aggregate_quick_upto( int, Vector*, Vector*, dd_func, dd_func, double );

double c_vv_covariance( int, Vector*, Vector* );
double c_vv_dist_manhattan( int, Vector*, Vector* );
double c_vv_dist_euclidean( int, Vector*, Vector* );
double c_vv_dist_manhattan_upto( int, Vector*, Vector*, double );
double c_vv_dist_euclidean_upto( int, Vector*, Vector*, double );

#endif
