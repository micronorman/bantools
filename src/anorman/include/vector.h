#ifndef ANORMAN_VECTOR
#define ANORMAN_VECTOR
#include "data.h"

double c_v_get_quick( Vector*, int );
void   c_v_set_quick( Vector*, int, double );
int    c_v_index ( Vector*, int rank );
double c_v_sum( Vector* ); 

void   c_vv_plus_assign( Vector*, Vector* );
void   c_vv_minus_assign( Vector*, Vector* );
void   c_vv_mult_assign( Vector*, Vector* );
void   c_vv_div_assign ( Vector*, Vector* );
void   c_vv_assign( Vector*, Vector* );
void   c_vn_assign( Vector*, double );
double c_vv_dot_product ( int, Vector*, Vector*, int, int );
#endif

