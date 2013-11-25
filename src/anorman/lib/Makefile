CC      = gcc
Cflags = -fPIC -Wall -Werror -g -pg  # gprof
INC_DIR = -I ../include/

all:	matrix.o

matrix.o:	matrix.c
	$(CC) $(Cflags) $(INC_DIR) -c matrix.c
