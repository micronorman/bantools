CC      = gcc
Cflags = -fPIC -Wall -Werror -g -pg  # gprof
INC_DIR = -I ../include/

all:	vector.o

matrix.o:	vector.c
	$(CC) $(Cflags) $(INC_DIR) -c vector.c
