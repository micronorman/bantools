#include "error.h"
#include <stdio.h>

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

