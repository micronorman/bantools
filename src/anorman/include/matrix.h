#ifndef ANORMAN_MATRIX_H
#define ANORMAN_MATRIX_H

#include "data.h"

int c_m_index( Matrix*, int, int );
double c_m_get_quick( Matrix*, int, int );
void c_m_set_quick( Matrix*, int, int, double);
double c_m_sum( Matrix* );

#endif
