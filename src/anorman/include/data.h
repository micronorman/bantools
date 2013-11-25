/* Define structs for different data types
 *
 * In both cases, elements are stored
 * internally in an array regardless of 
 * the number of dimension
 *
 * (C) Anders Norman, July - September 2013
 * lordnorman@gmail.com
 */

#ifndef ANORMAN_DATA_H
#define ANORMAN_DATA_H

#include <stddef.h>
#include <stdbool.h>

typedef struct {
    size_t rows;
    size_t columns;
    double* elements;
    int row_zero;
    int column_zero;
    int row_stride;
    int column_stride;
    bool view_flag;
} Matrix;

typedef struct {
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
} SelectedMatrix;


typedef struct {
    size_t size;
    double* elements;
    int zero;
    int stride;
    bool view_flag;
} Vector;

typedef struct {
    size_t size;
    double* elements;
    int zero;
    int stride;
    int offset;
    int* offsets;
    bool view_flag;
} SelectedVector;

typedef struct {
    size_t size;
    int* elements;
} IntList;

typedef struct {
    char* states;
    char* table;
    char* values;
    int   distinct;
} Map;

#endif
