#ifndef __ANORMAN_FUNCTIONS_VECTORVECTOR_H__
#define __ANORMAN_FUNCTIONS_VECTORVECTOR_H__

#include "data.h"
#include "functions/functions.h"

typedef double ( *vv_func ) ( size_t, Vector*, Vector* );
typedef double ( *vv_thr_func ) ( size_t, Vector*, Vector*, double );

double c_vv_aggregate_quick( size_t, Vector*, Vector*, dd_func, dd_func );
double c_vv_aggregate_quick_upto( size_t size, Vector* a, Vector* b, dd_func aggr, dd_func f, const double threshold ); 
double c_vv_covariance( size_t, Vector*, Vector* );
double c_vv_dist_manhattan( size_t, Vector*, Vector* );
double c_vv_dist_euclidean( size_t, Vector*, Vector* );
double c_vv_dist_manhattan_upto( size_t, Vector*, Vector*, double );
double c_vv_dist_euclidean_upto( size_t, Vector*, Vector*, double );
double c_vv_squared_dist_euclidean( size_t, Vector*, Vector* );
#endif
