#ifndef __ANORMAN_FUNCTIONS_VECTOR_H__
#define __ANORMAN_FUNCTIONS_VECTOR_H__

#include "data.h"
#include "functions/functions.h"

double c_v_aggregate_quick( size_t, Vector*, dd_func, d_func );
double c_v_aggregate_quick_upto( size_t, Vector* , dd_func, d_func , double );
double c_v_mean( size_t, Vector* );
double c_v_variance( size_t, Vector* ); 

#endif
