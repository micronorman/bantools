/* Define structs for different data types
 *
 * In both cases, elements are stored
 * internally in an array regardless of 
 * the number of dimension
 *
 * (C) Anders Norman, July 2013 - March 2014
 * lordnorman@gmail.com
 */

#ifndef __ANORMAN_DATA_H__
#define __ANORMAN_DATA_H__

#include <stddef.h>

#define MAX_NUM_ELEMENTS 2147483647

struct intlist_struct
{
    size_t size;
    int*   elements;
};

struct doublelist_struct
{
    size_t  size;
    double* elements;
};

typedef struct intlist_struct IntList;
typedef struct doublelist_struct DoubleList;

struct int_double_map_struct
{
    uint8_t  * states;
    size_t   * values;
    double   * table;
    size_t   low_water_mark;
    size_t   high_water_mark;
    double   min_load_factor;
    double   max_load_factor;
};

typedef struct int_double_map_struct IntDoubleMap;


struct vector_offsets_struct
{
    size_t  offset;
    size_t* offsets;
};

typedef struct vector_offsets_struct VectorOffsets;

struct vector_struct
{
           size_t size;
           size_t zero;
           size_t stride;
           double * elements;
    VectorOffsets * offsets;
     IntDoubleMap * hash_map;
              int view_flag;
};

typedef struct vector_struct Vector;


struct matrix_offsets_struct
{
    size_t offset;
    size_t *row_offsets;
    size_t *column_offsets;
};

typedef struct matrix_offsets_struct MatrixOffsets;

struct matrix_struct
{
           size_t rows;
           size_t columns;
           size_t row_zero;
           size_t column_zero;
           size_t row_stride;
           size_t column_stride;
           double * elements;
    MatrixOffsets * offsets;
     IntDoubleMap * hash_map;
              int view_flag;
};

typedef struct matrix_struct Matrix;

#endif
