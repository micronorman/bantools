#include "data.h"
#include "error.h"
#include "matrix.h"
#include "stdio.h"

Matrix*
c_m_alloc_from_matrix( Matrix * mm, 
                       const size_t k1, 
                       const size_t k2,
                       const size_t n1,
                       const size_t n2)
{
    Matrix* m;

    if (n1 == 0) {
        C_ERROR_VAL ("Matrix rows (n1) must be positive integer", C_EINVAL, 0);
    } else if (n2 == 0) {
        C_ERROR_VAL ("Matrix columns (n2) must be positive integer", C_EINVAL, 0);
    } else if (k1 + n1 > mm->rows) {
        C_ERROR_VAL ("New matrix exceeds height of the original", C_EINVAL, 0);
    } else if (k2 + n2 > mm->columns) {
        C_ERROR_VAL ("New matrix exceeds width of the original", C_EINVAL, 0);
    }

    m = ((Matrix*) malloc (sizeof (Matrix)));

    if (m == 0) {
        C_ERROR_VAL ("Failed to allocate space for matrix struct", C_ENOMEM, 0);
    }

    m->elements      = mm->elements;
    m->rows          = n1;
    m->columns       = n2;
    m->row_zero      = k1 * mm->row_stride;
    m->column_zero   = k2 * mm->column_stride;
    m->row_stride    = mm->row_stride;
    m->column_stride = mm->column_stride;
    m->view_flag     = 1;

    return m;
}

void
c_m_free( Matrix* m ) {
       
    if (!m) {
        return;
    }
    /* do not free elements if
       struct is a view         */
    if (m->elements && !m->view_flag) {
        free( m->elements );
    }
   
    free( m ); 
}

void
c_m_set_all( Matrix* m, double x ) {
    double* elems = m->elements;

    const size_t cs = m->column_stride;
    const size_t rs = m->row_stride;
    size_t index = c_m_index( m, 0,0 );

    int row = (int) m->rows;
    while ( --row >= 0) {
        size_t i = index;

        int column = (int) m->columns;
        while (--column >= 0) {
            elems[ i ] = x;
            i += cs;
        }

        index += rs;
    }
}

Matrix*
c_m_part( Matrix* m, 
          const size_t i, const size_t j,
          const size_t n1, const size_t n2)
{
    if (n1 == 0) {
        C_ERROR_VAL ("Matrix rows (n1) must be positive integer", C_EINVAL, 0);
    } else if (n2 == 0) {
        C_ERROR_VAL ("Matrix columns (n2) must be positive integer", C_EINVAL, 0);
    } else if (i + n1 > m->rows) {
        C_ERROR_VAL ("Rows overflow matrix", C_EINVAL, 0);
    } else if (j + n2 > m->columns) {
        C_ERROR_VAL ("Columns overflows matrix", C_EINVAL, 0);
    } else if (i > m->rows) {
        C_ERROR_VAL ("Row index is out of range", C_EINVAL, 0);
    } else if (j > m->columns) {
        C_ERROR_VAL ("Column index is out of range", C_EINVAL, 0);
    }

    m->rows          = n1;
    m->columns       = n2;
    m->row_zero     += i * m->row_stride;
    m->column_zero  += j * m->column_stride;
    m->view_flag     = 1;
    
    return m;
}

/* optimized matrix-matrix multiplication (with loop unrolling) */
Matrix* c_mm_mult ( Matrix* A, Matrix* B, Matrix* C, double alpha, double beta) {
    const size_t m = A->rows;
    const size_t n = A->columns;
    const size_t p = B->columns;

    const double* A_elems = A->elements;
    const double* B_elems = B->elements;
    double* C_elems = C->elements;

    const size_t cA = A->column_stride;
    const size_t cB = B->column_stride;
    const size_t cC = C->column_stride;

    const size_t rA = A->row_stride;
    const size_t rB = B->row_stride;
    const size_t rC = C->row_stride;

    static size_t BLOCK_SIZE = 30000;
    size_t m_optimal = (BLOCK_SIZE - n) / (n+1);
    if (m_optimal <= 0) m_optimal = 1;
    int blocks = m/m_optimal;
    size_t rr = 0;
    if (m % m_optimal != 0) blocks++;

    while ( --blocks >= 0 ) {
        size_t jB =     c_m_index(B,0,0);
        size_t indexA = c_m_index(A, rr,0);
        size_t jC =     c_m_index(C, rr,0);
        rr += m_optimal;
        if (blocks == 0) m_optimal += m - rr;

        int j = (int) p;
        while ( --j >= 0) {
            size_t iA = indexA;
            size_t iC = jC;
            int i = (int) m_optimal;
            while ( --i >= 0 ) {
                size_t kA = iA;
                size_t kB = jB;

                long double s = 0.0;

                // loop unrolled 
                kA -= cA;
                kB -= rB;

                int k = (int) n % 4;
                while ( --k >= 0 ) {
                    s += A_elems[ kA += cA ] * B_elems[ kB += rB ];
                }

                k = n / 4;
                while ( --k >= 0 ) {
                    s += A_elems[ kA += cA ] * B_elems[ kB += rB ];
                    s += A_elems[ kA += cA ] * B_elems[ kB += rB ];
                    s += A_elems[ kA += cA ] * B_elems[ kB += rB ];
                    s += A_elems[ kA += cA ] * B_elems[ kB += rB ];
                }

                C_elems[ iC ] = alpha * s + beta * C_elems[ iC ];
                iA += rA;
                iC += rC;
            }
            jB += cB;
            jC += cC;
        }
    }

    return C;
}

/* optimized matrix-vector multiplication (with loop unrolling) */
Vector* c_mv_mult ( Matrix *A, Vector* y, Vector* z, double alpha, double beta ) {
    const double* A_elems = A->elements;
    const double* y_elems = y->elements;
    double* z_elems = z->elements;

    const size_t As = A->column_stride;
    const size_t ys = y->stride;
    const size_t zs = z->stride;

    size_t indexA = c_m_index(A,0,0);
    size_t indexy = y->zero;
    size_t indexz = z->zero;

    int cols = (int) A->columns;
    int row  = (int) A->rows;
    while ( --row >= 0 ) {
        long double sum = 0;

        size_t i = indexA - As;
        size_t j = indexy - ys;

        int k = cols % 4;
        while ( --k >= 0 ) {
            sum += A_elems[ i += As ] * y_elems[ j += ys ];
        }

        k = cols / 4;
        while ( --k >= 0 ) {
            sum += A_elems[ i += As ] * y_elems[ j += ys ];
            sum += A_elems[ i += As ] * y_elems[ j += ys ];
            sum += A_elems[ i += As ] * y_elems[ j += ys ];
            sum += A_elems[ i += As ] * y_elems[ j += ys ];
        }

        z_elems[ indexz ] = alpha * sum + beta * z_elems[ indexz ];
        indexA += A->row_stride;
        indexz += zs;
    }

    return z;
}

void c_mm_copy( Matrix* A, Matrix* B) {
    double* A_elems = A->elements;
    const double* B_elems = B->elements;

    const size_t    A_cs = A->column_stride;
    const size_t    B_cs = B->column_stride;
    const size_t    A_rs = A->row_stride;
    const size_t    B_rs = B->row_stride;
    size_t B_index = (int) c_m_index( B, 0,0 );
    size_t A_index = (int) c_m_index( A, 0,0 );

    int row = (int) A->rows;
    while ( --row >= 0) {
        int i = A_index;
        int j = B_index;

        int column = (int) A->columns;
        while (--column >= 0) {
            A_elems[ i ] = B_elems[ j ];
            i += A_cs;
            j += B_cs;
        }

        A_index += A_rs;
        B_index += B_rs;
    }
}
 
double c_m_sum( Matrix* m ) {
    double sum = 0;
    
    const double* elem = m->elements;
	
    size_t index = c_m_index(m, 0,0);
    size_t    cs = m->column_stride;
    size_t    rs = m->row_stride;
    int   row = (int) m->rows;

    while( --row >= 0) {
        size_t i      = index;
        int column = (int) m->columns;

        while( --column >= 0) {       
            sum += elem[i];
              i += cs;
        }

	index += rs;
    }

    return sum;
}


int c_mm_add( Matrix* A, Matrix* B) {

    const size_t M = A->rows;
    const size_t N = A->columns;

    if (B->rows != M || B->columns != N) {
        C_ERROR("Matrices must have same dimensions", C_EBADLEN);
    }
          double* A_elems = A->elements;
    const double* B_elems = B->elements;

    const size_t    A_cs = A->column_stride;
    const size_t    B_cs = B->column_stride;
    const size_t    A_rs = A->row_stride;
    const size_t    B_rs = B->row_stride;

    size_t B_index = (int) c_m_index( B, 0,0 );
    size_t A_index = (int) c_m_index( A, 0,0 );

    int row = (int) A->rows;
    while ( --row >= 0) {
        size_t i = A_index;
        size_t j = B_index;

        int column = (int) A->columns;
        while (--column >= 0) {
            A_elems[ i ] += B_elems[ j ];
            i += A_cs;
            j += B_cs;
        }

        A_index += A_rs;
        B_index += B_rs;
    }

    return C_SUCCESS;
}

int c_mm_sub( Matrix* A, Matrix* B) {

    const size_t M = A->rows;
    const size_t N = A->columns;

    if (B->rows != M || B->columns != N) {
        C_ERROR("Matrices must have same dimensions", C_EBADLEN);
    }
          double* A_elems = A->elements;
    const double* B_elems = B->elements;

    const size_t    A_cs = A->column_stride;
    const size_t    B_cs = B->column_stride;
    const size_t    A_rs = A->row_stride;
    const size_t    B_rs = B->row_stride;

    size_t B_index = (int) c_m_index( B, 0,0 );
    size_t A_index = (int) c_m_index( A, 0,0 );

    int row = (int) A->rows;
    while ( --row >= 0) {
        size_t i = A_index;
        size_t j = B_index;

        int column = (int) A->columns;
        while (--column >= 0) {
            A_elems[ i ] -= B_elems[ j ];
            i += A_cs;
            j += B_cs;
        }

        A_index += A_rs;
        B_index += B_rs;
    }

    return C_SUCCESS;
}

int c_mm_mul( Matrix* A, Matrix* B) {

    const size_t M = A->rows;
    const size_t N = A->columns;

    if (B->rows != M || B->columns != N) {
        C_ERROR("Matrices must have same dimensions", C_EBADLEN);
    }
          double* A_elems = A->elements;
    const double* B_elems = B->elements;

    const size_t    A_cs = A->column_stride;
    const size_t    B_cs = B->column_stride;
    const size_t    A_rs = A->row_stride;
    const size_t    B_rs = B->row_stride;

    size_t B_index = (int) c_m_index( B, 0,0 );
    size_t A_index = (int) c_m_index( A, 0,0 );

    int row = (int) A->rows;
    while ( --row >= 0) {
        size_t i = A_index;
        size_t j = B_index;

        int column = (int) A->columns;
        while (--column >= 0) {
            A_elems[ i ] *= B_elems[ j ];
            i += A_cs;
            j += B_cs;
        }

        A_index += A_rs;
        B_index += B_rs;
    }

    return C_SUCCESS;
}

int c_mm_div( Matrix* A, Matrix* B) {

    const size_t M = A->rows;
    const size_t N = A->columns;

    if (B->rows != M || B->columns != N) {
        C_ERROR("Matrices must have same dimensions", C_EBADLEN);
    }
          double* A_elems = A->elements;
    const double* B_elems = B->elements;

    const size_t    A_cs = A->column_stride;
    const size_t    B_cs = B->column_stride;
    const size_t    A_rs = A->row_stride;
    const size_t    B_rs = B->row_stride;

    size_t B_index = (int) c_m_index( B, 0,0 );
    size_t A_index = (int) c_m_index( A, 0,0 );

    int row = (int) A->rows;
    while ( --row >= 0) {
        size_t i = A_index;
        size_t j = B_index;

        int column = (int) A->columns;
        while (--column >= 0) {
            A_elems[ i ] /= B_elems[ j ];
            i += A_cs;
            j += B_cs;
        }

        A_index += A_rs;
        B_index += B_rs;
    }

    return C_SUCCESS;
}

int c_m_scale( Matrix* A, double x ) {

    const size_t M = A->rows;
    const size_t N = A->columns;

    double* elems = A->elements;

    const size_t cs = A->column_stride;
    const size_t rs = A->row_stride;

    size_t index = c_m_index( A, 0,0 );

    int row = (int) A->rows;
    while ( --row >= 0) {
        size_t i = index;

        int column = (int) A->columns;
        while (--column >= 0) {
            elems[ i ] *= x;
            i += cs;
        }

        index += rs;
    }

    return C_SUCCESS;
}

int c_m_add_constant( Matrix* A, double x ) {

    const size_t M = A->rows;
    const size_t N = A->columns;

    double* elems = A->elements;

    const size_t cs = A->column_stride;
    const size_t rs = A->row_stride;

    size_t index = c_m_index( A, 0,0 );

    int row = (int) A->rows;
    while ( --row >= 0) {
        size_t i = index;

        int column = (int) A->columns;
        while (--column >= 0) {
            elems[ i ] += x;
            i += cs;
        }

        index += rs;
    }

    return C_SUCCESS;
}

