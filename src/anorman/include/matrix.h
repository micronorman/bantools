#ifndef __ANORMAN_MATRIX_H__
#define __ANORMAN_MATRIX_H__

#include <stddef.h>
#include "data.h"

void c_mm_copy( Matrix*, Matrix* );
double c_m_sum( Matrix* );

size_t c_m_index( Matrix*, const size_t, const size_t );
double c_m_get_quick( Matrix*, const size_t, const size_t );
void c_m_set_quick( Matrix*, const size_t, const size_t, const double);

/* Declarations */

size_t c_m_index( Matrix* m, const size_t i, const size_t j ) {
    return (m->row_zero + i * m->row_stride + m->column_zero + j * m->column_stride);
}

double c_m_get_quick( Matrix* m, const size_t i, const size_t j ) {
    return m->elements[ m->row_zero + i * m->row_stride + m->column_zero + j * m->column_stride ];
}

void c_m_set_quick( Matrix* m, const size_t i, const size_t j,  const double x ) {
    m->elements[ m->row_zero + i * m->row_stride + m->column_zero + j * m->column_stride ] = x;
}

#endif
