#ifndef __ANORMAN_ERROR_H__
#define __ANORMAN_ERROR_H__

#include <stdlib.h>
#include <stdio.h>
#include <errno.h>

enum {
    C_SUCCESS  = 0,
    C_FAILURE  = -1,
    C_CONTINUE = -1,
    C_EDOM     = 1,
    C_ERANGE   = 2,
    C_EFAULT   = 3,
    C_EINVAL   = 4,
    C_ENOMEM   = 8
};

void c_error( const char * , const char * , int , int  );
void c_warn( const char *, const char *, int );
void c_stream_printf( const char *, const char *, int, const char * );

#define C_ERROR(reason, c_errno) \
    do { \
    c_error( reason, __FILE__, __LINE__, c_errno) ; \
    return c_errno ; \
    } while (0)

#define C_ERROR_VAL(reason, c_errno, value) \
    do { \
    c_error( reason, __FILE__, __LINE__, c_errno) ; \
    return value ; \
    } while (0)

#define C_ERROR_VOID(reason, c_errno) \
    do { \
    c_error( reason, __FILE__, __LINE__, c_errno) ; \
    return ; \
    } while (0)
    
#define C_ERROR_NULL(reason, c_errno) C_ERROR_VAL(reason, c_errno, 0)

#define C_WARNING(reason) \
    do { \
    c_warn( reason, __FILE__, __LINE__) ; \
    } while (0)

void c_error( const char * reason, const char * file, int line, int c_errno ) {
    c_stream_printf("ERROR", file, line, reason);

    fflush (stdout);
    fprintf (stderr, "C Error Handler invoked.\n");
    fflush (stderr);

    abort();
}

void c_warn( const char * reason, const char * file, int line ) {
    c_stream_printf("WARNING", file, line, reason);
}

void
c_stream_printf (const char *label, const char *file, int line,
                   const char *reason) {
    fprintf( stderr, "Message from C: %s:%d: %s: %s\n", file, line, label, reason );
}
#endif
