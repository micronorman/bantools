package Anorman::Data::LinAlg::CBLAS;

use strict;
use warnings;

# Wraps Matrices and Vectors to make ultrafast cblas function calls 
# Read more about cblas at
#
# http://www.prism.gatech.edu/~ndantam3/cblas-doc/doc/html/main.html

use Anorman::Common;
use Exporter;

our (@ISA, @EXPORT_OK, @EXPORT);

@ISA = qw(Exporter);

@EXPORT_OK = qw(
    XS_call_cblas_nrm2
    XS_call_cblas_dot
    XS_call_cblas_axpy
    XS_call_cblas_gemm
    XS_call_cblas_trmv
    XS_call_cblas_trsv
);

@EXPORT = @EXPORT_OK;

use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::Data::LinAlg::CBLAS',
		INC  => '-I' . $Anorman::Common::AN_SRC_DIR . '/include -I/usr/local/opt/openblas/include',
		LIBS => '-L/usr/local/opt/openblas/lib -L' . $Anorman::Common::AN_SRC_DIR . '/lib -lopenblas -landata'	

           );

use Inline C => <<'END_OF_C_CODE';

#include "data.h"
#include "perl2c.h"
#include "error.h"

#include "cblas.h"

int
XS_call_cblas_dot( SV* sv_X, SV* sv_Y, SV* result ) {
    SV_2STRUCT( sv_X, Vector, X );
    SV_2STRUCT( sv_Y, Vector, Y );

    double dot;

    if (X->size == Y->size) {
        double* const X_data = X->elements + X->zero;
        double* const Y_data = Y->elements + Y->zero;
       
        dot = cblas_ddot( (int) X->size, X_data, (int) X->stride, Y_data,
                          (int) Y->stride );
        sv_setnv( result, dot);

        return C_SUCCESS;
    } else {
        C_ERROR("Invalid length", C_EBADLEN );
    }
}

NV
XS_call_cblas_nrm2( SV* sv_X ) {
        SV_2STRUCT( sv_X, Vector, X );
        double* const X_data = X->elements + X->zero;
        return (NV) cblas_dnrm2 ( (int) X->size, X_data, (int) X->stride );
}

int XS_call_cblas_axpy( NV alpha, SV* sv_X, SV* sv_Y ) {
    SV_2STRUCT( sv_X, Vector, X);
    SV_2STRUCT( sv_Y, Vector, Y);

    if ( X->size == Y->size ) {
        double* const X_data = X->elements + X->zero; 
        double* Y_data = Y->elements + Y->zero;

        cblas_daxpy( (int) X->size, alpha, X_data, (int) X->stride, Y_data,
                     (int) Y->stride );
        return C_SUCCESS;
    } else {
        C_ERROR("Invalid length", C_EBADLEN);
    }
}

int
XS_call_cblas_gemv
  (
    IV TransA,
    NV alpha,
    SV* sv_A,
    SV* sv_X,
    NV beta,
    SV* sv_Y
  )
{
    SV_2STRUCT( sv_A, Matrix, A );
    SV_2STRUCT( sv_X, Vector, X );
    SV_2STRUCT( sv_Y, Vector, Y );

    const size_t M = A->rows;
    const size_t N = A->columns;

    if ((TransA == CblasNoTrans && N == X->size && M == Y->size)
      || (TransA == CblasTrans && M == X->size && N == Y->size))
    {
        double* const A_data = A->elements + (A->row_zero + A->column_zero);
        double* const X_data = X->elements + X->zero; 
        double* Y_data = Y->elements + Y->zero;

        cblas_dgemv( CblasRowMajor, TransA, (int) M, (int) N, alpha, A_data,
                     (int) A->row_stride, X_data, (int) X->stride, beta,
                     Y_data, (int) Y->stride);
        return C_SUCCESS; 
    } else {
        C_ERROR("Invalid length", C_EBADLEN);
    }
}

int 
XS_call_cblas_trsv
  (
    IV Uplo, 
    IV TransA,
    IV Diag, 
    SV* sv_A,
    SV* sv_X
  ) 

{
    SV_2STRUCT( sv_A, Matrix, A );
    SV_2STRUCT( sv_X, Vector, X );

    const size_t M = A->rows;
    const size_t N = A->columns;

    if (M != N) {
        C_ERROR("Matrix must be square", C_ENOTSQR);
    } else if (N != X->size) {
        C_ERROR("Invalid vector length", C_EBADLEN);
    } 
        double* const A_data = A->elements + (A->row_zero + A->column_zero);
        double* X_data = X->elements + X->zero; 

    cblas_dtrsv( CblasRowMajor, Uplo, TransA, Diag, (int) N, A_data,
                 (int) A->row_stride, X_data, (int) X->stride );
    return C_SUCCESS;
}


int
XS_call_cblas_gemm
  (
        NV alpha,
        NV beta,
        IV TransA,
        IV TransB,
        SV* sv_A,
        SV* sv_B,
        SV* sv_C
  )
{
    SV_2STRUCT( sv_A, Matrix, A );
    SV_2STRUCT( sv_B, Matrix, B );
    SV_2STRUCT( sv_C, Matrix, C );

    const size_t M = C->rows;
    const size_t N = C->columns;
    const size_t MA = (TransA == CblasNoTrans) ? A->rows    : A->columns;
    const size_t NA = (TransA == CblasNoTrans) ? A->columns : A->rows;
    const size_t MB = (TransB == CblasNoTrans) ? B->rows    : B->columns;
    const size_t NB = (TransB == CblasNoTrans) ? B->columns : B->rows;

  if (M == MA && N == NB && NA == MB)   /* [MxN] = [MAxNA][MBxNB] */
    {        
        double* const A_data = A->elements + (A->row_zero + A->column_zero);
        double* const B_data = B->elements + (B->row_zero + B->column_zero);
        double* C_data = C->elements + (C->row_zero + C->column_zero);

      cblas_dgemm (CblasRowMajor, TransA, TransB, (int) M, (int) N, (int) NA,
                   alpha, A_data, (int) A->row_stride, B_data, (int) B->row_stride, beta,
                   C_data, (int) C->row_stride );
      return C_SUCCESS;
    }
  else
    {
      C_ERROR ("invalid length", C_EBADLEN);
    }
}

int
XS_call_cblas_trmv
  ( IV Uplo,
    IV TransA,
    IV Diag,
    SV* sv_A,
    SV* sv_X
  ) 
{
    SV_2STRUCT( sv_A, Matrix, A);
    SV_2STRUCT( sv_X, Vector, X);

    const size_t M = A->rows;
    const size_t N = A->columns;

    if (M != N) {
      C_ERROR ("Matrix must be square", C_ENOTSQR);
    } else if (N != X->size) {
      C_ERROR ("Invalid length", C_EBADLEN);
    }
   double* const A_data = A->elements + (A->row_zero + A->column_zero);
   double* X_data = X->elements + X->zero; 

  cblas_dtrmv (CblasRowMajor, Uplo, TransA, Diag, (int) N, A_data,
               (int) A->row_stride, X_data, (int) X->stride);
  return C_SUCCESS;
}

END_OF_C_CODE

1;

