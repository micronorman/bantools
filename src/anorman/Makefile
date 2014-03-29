CC      = gcc
CCFLAGS = -arch x86_64 -arch i386 -g -O2 -Wall -pipe -DPERL_DARWIN -fno-strict-aliasing -fstack-protector -fPIC
INC_DIR = -Iinclude -Iinclude/functions

all:	vector.o

matrix.o:	vector.c
	$(CC) $(Cflags) $(INC_DIR) -c vector.c
