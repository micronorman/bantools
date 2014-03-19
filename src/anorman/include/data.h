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

struct matrix_struct
{
    size_t rows;
    size_t columns;
    size_t row_zero;
    size_t column_zero;
    size_t row_stride;
    size_t column_stride;
    double *elements;
    int view_flag;
};

typedef struct matrix_struct Matrix;

struct select_matrix_struct
{
    size_t rows;
    size_t columns;
    size_t row_zero;
    size_t column_zero;
    size_t row_stride;
    size_t column_stride;
    size_t offset;
    size_t *row_offsets;
    size_t *column_offsets;
    double *elements; 	
    int view_flag;
};

typedef struct select_matrix_struct SelectedMatrix;

struct vector_struct
{
    size_t size;
    size_t zero;
    size_t stride;
    double *elements;
    int view_flag;
};

typedef struct vector_struct Vector;

struct select_vector_struct
{
    size_t size;
    size_t zero;
    size_t stride;
    size_t offset;
    size_t *offsets;
    double* elements;
    int view_flag;
};

typedef struct select_vector_struct SelectedVector;

struct intlist_struct
{
    size_t size;
    int* elements;
};

typedef struct intlist_struct IntList;

struct doublelist_struct
{
    size_t size;
    double* elements;
};

typedef struct doublelist_struct DoubleList;

struct intdoublemap_struct
{
    char* states;
    size_t *table;
    double* values;
    int   distinct;
};

typedef struct intdoublemap_struct IntDoubleMap;


#endif
