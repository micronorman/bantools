#ifndef __ANORMAN_MATRIX_H__
#define __ANORMAN_MATRIX_H__

#include <stddef.h>
#include "data.h"

void c_mm_copy( Matrix*, Matrix* );
double c_m_sum( Matrix* );

size_t c_m_index( Matrix*, const size_t, const size_t );
double c_m_get_quick( Matrix*, const size_t, const size_t );
void c_m_set_quick( Matrix*, const size_t, const size_t, const double);

int c_mm_add( Matrix* A, Matrix* B);
int c_mm_sub( Matrix* A, Matrix* B);
int c_mm_mul( Matrix* A, Matrix* B);
int c_mm_div( Matrix* A, Matrix* B);
int c_m_scale( Matrix* A, double x );
int c_m_add_constant( Matrix* A, double x);

void c_m_show_struct( Matrix* );

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

/* DEBUGGING */
void c_m_show_struct( Matrix* m ) {
    
    fprintf( stderr, "\nContents of Matrix struct:\n" );
    fprintf( stderr, "\trows\t(%p): %lu\n", &m->rows, m->rows );
    fprintf( stderr, "\tcols\t(%p): %lu\n", &m->columns, m->columns );
    fprintf( stderr, "\tr0\t(%p): %lu\n",  &m->row_zero, m->row_zero );
    fprintf( stderr, "\tc0\t(%p): %lu\n", &m->column_zero, m->column_zero );
    fprintf( stderr, "\trstride\t(%p): %lu\n", &m->row_stride, m->row_stride );
    fprintf( stderr, "\tcstride\t(%p): %lu\n", &m->column_stride, m->column_stride );

    if (!m->elements) {
        fprintf( stderr, "\telems\t(%p): null\n",  &m->elements );
    } else {
        fprintf( stderr, "\telems\t(%p): [ %p ]\n",  &m->elements, m->elements );
    }

    if (!m->offsets) {
        fprintf( stderr, "\toffsets\t(%p): null\n", &m->offsets );
    } else {
        fprintf( stderr, "\toffsets\t(%p): [ %p ]\n", &m->offsets, m->offsets );
    }
  
    if (!m->hash_map) {
        fprintf( stderr, "\tmap\t(%p): null\n", &m->hash_map );
    } else {
        fprintf( stderr, "\tmap\t(%p): [ %p ]\n", &m->hash_map, m->hash_map );
    }
 
    fprintf( stderr, "\tview\t(%p): %d\n\n", &m->view_flag, m->view_flag );

    if (m->offsets) {
        fprintf( stderr, "\n\nOffsets: (%p)\n", &m->offsets );
        fprintf( stderr, "\toffset\t(%p): %lu\n\n", &m->offsets->offset, m->offsets->offset );
        fprintf( stderr, "\troffsets\t(%p): [ %p ]\n", &m->offsets->row_offsets, m->offsets->row_offsets );
        fprintf( stderr, "\tcoffsets\t(%p): [ %p ]\n", &m->offsets->column_offsets, m->offsets->column_offsets );
    }
}

#endif
