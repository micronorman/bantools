#include "data.h"
#include "matrix.h"

int c_m_index( Matrix* m, int row, int column ) {
    return (m->row_zero + row * m->row_stride + m->column_zero + column * m->column_stride);
}

double c_m_get_quick( Matrix* m, int row, int column) {

    double* elem = (double *) m->elements;
    return elem[ m->row_zero + row * m->row_stride + m->column_zero + column * m->column_stride ];
}

void c_m_set_quick( Matrix* m, int row, int column, double value ) {

    double *elem = (double *) m->elements;

    elem[ m->row_zero + row * m->row_stride + m->column_zero + column * m->column_stride ] = value;
}

/* optimized matrix-matrix multiplication (with loop unrolling) */
Matrix* c_mm_mult ( Matrix* A, Matrix* B, Matrix* C, double alpha, double beta) {
    int m = A->rows;
    int n = A->columns;
    int p = B->columns;

    double* A_elems = A->elements;
    double* B_elems = B->elements;
    double* C_elems = C->elements;

    int cA = A->column_stride;
    int cB = B->column_stride;
    int cC = C->column_stride;

    int rA = A->row_stride;
    int rB = B->row_stride;
    int rC = C->row_stride;

    int BLOCK_SIZE = 30000;
    int m_optimal = (BLOCK_SIZE - n) / (n+1);
    if (m_optimal <= 0) m_optimal = 1;
    int blocks = m/m_optimal;
    int rr = 0;
    if (m % m_optimal != 0) blocks++;

    while ( --blocks >= 0 ) {
        int jB = c_m_index(B,0,0);
        int indexA = c_m_index(A, rr,0);
        int jC = c_m_index(C, rr,0);
        rr += m_optimal;
        if (blocks == 0) m_optimal += m - rr;

        int j = p;
        while ( --j >= 0) {
            int iA = indexA;
            int iC = jC;
            int i = m_optimal;
            while ( --i >= 0 ) {
                int kA = iA;
                int kB = jB;

                long double s = 0.0;

                /*
                // not unrolled
                int k = n;
                while ( --k >=0 ) {
                    s+= A_elems[ kA ] * B_elems[ kB ];
                    printf("k: %d, kA: %d, kB: %d, s: %f\n",k,kA,kB,s);
                    kB += rB;
                    kA += cA;
                }
                */

                // loop unrolled 
                kA -= cA;
                kB -= rB;

                int k = n % 4;
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
    double* A_elems = A->elements;
    double* y_elems = y->elements;
    double* z_elems = z->elements;

    int As = A->column_stride;
    int ys = y->stride;
    int zs = z->stride;

    int indexA = c_m_index(A,0,0);
    int indexy = y->zero;
    int indexz = z->zero;

    int cols = A->columns;
    int row  = A->rows;
    while ( --row >= 0 ) {
        long double sum = 0;

        int i = indexA - As;
        int j = indexy - ys;
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
    double* B_elems = B->elements;

    int    A_cs = A->column_stride;
    int    B_cs = B->column_stride;
    int    A_rs = A->row_stride;
    int    B_rs = B->row_stride;
    int B_index = c_m_index( B, 0,0 );
    int A_index = c_m_index( A, 0,0 );

    int row = A->rows;
    while ( --row >= 0) {
        int i = A_index;
        int j = B_index;

        int column = A->columns;
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
    
    double* elem = (double *) m->elements;
	
    int index = c_m_index(m, 0,0);
    int    cs = m->column_stride;
    int    rs = m->row_stride;
    int   row = (int) m->rows;

    while( --row >= 0) {
        int i      = index;
        int column = (int) m->columns;

        while( --column >= 0) {       
            sum += elem[i];
              i += cs;
        }

	index += rs;
    }

    return sum;
}
