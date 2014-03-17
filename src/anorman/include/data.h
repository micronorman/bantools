/* Define structs for different data types
 *
 * In both cases, elements are stored
 * internally in an array regardless of 
 * the number of dimension
 *
 * (C) Anders Norman, July 2013 - March 2014
 * lordnorman@gmail.com
 */

#ifndef ANORMAN_DATA_H
#define ANORMAN_DATA_H

#include <stddef.h>
#include <stdbool.h>
#include "ppport.h"

struct matrix_struct
{
    size_t rows;
    size_t columns;
    double* elements;
    int row_zero;
    int column_zero;
    int row_stride;
    int column_stride;
    bool view_flag;
};

typedef struct matrix_struct Matrix;

struct select_matrix_struct
{
    size_t rows;
    size_t columns;
    double* elements; 	
    int row_zero;
    int column_zero;
    int row_stride;
    int column_stride;
    int offset;
    int* row_offsets;
    int* column_offsets;
    bool view_flag;
};

typedef struct select_matrix_struct SelectedMatrix;

struct vector_struct
{
    size_t size;
    double* elements;
    int zero;
    int stride;
    bool view_flag;
};

typedef struct vector_struct Vector;

struct select_vector_struct
{
    size_t size;
    double* elements;
    int zero;
    int stride;
    int offset;
    int* offsets;
    bool view_flag;
}
;
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
    int* table;
    double* values;
    int   distinct;
};

typedef struct intdoublemap_struct IntDoubleMap;

/* Defines. extract struct from Perl scalars */
#define SV_2MATRIX( sv, ptr_name )    Matrix* ptr_name = (Matrix*) SvIV( SvRV( sv ) )
#define SV_2VECTOR( sv, ptr_name )    Vector* ptr_name = (Vector*) SvIV( SvRV( sv ) )
#define SV_2SELECTEDMATRIX( sv, ptr_name )    SelectedMatrix* ptr_name = (SelectedMatrix*) SvIV( SvRV( sv ) )
#define SV_2SELECTEDVECTOR( sv, ptr_name )    SelectedVector* ptr_name = (SelectedVector*) SvIV( SvRV( sv ) )

#endif
