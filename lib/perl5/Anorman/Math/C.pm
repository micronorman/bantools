package Anorman::Math::C;

use Inline C         => 'DATA',
           DIRECTORY => '/home/anorman/tmp',
	   NAME      => 'Anorman::Math::C';
1;

__DATA__

=pod

=cut

__C__
#include <math.h>
#include <float.h>

/*

	Vector Distance Functions

*/

double vect_dist_euclidean( size_t size, char *vector1, char *vector2 ) {

 	/* Euclidean distance */
	double *v1 = (double *) vector1;
	double *v2 = (double *) vector2;
	
	int i;
	
	double norm2 = 0.0;

	for( i = 0; i < size; i++ ) {
		double d = v1[ i ] - v2[ i ];
		norm2 += d * d;
	}
	return sqrt(norm2);
}

double vect_dist_manhattan( size_t size, char *vector1, char *vector2 ) {

 	/* Manhattan distance */
	double *v1 = (double *) vector1;
	double *v2 = (double *) vector2;
	
	int i;
	
	double norm = 0.0;

	for( i = 0; i < size; i++ ) {
		double d = abs( v1[ i ] - v2[ i ] );
		norm += d;
	}
	return norm;
}

double vect_dist_euclidean_upto( size_t size, double threshold, char *vector1, char *vector2 ) {
	
  	/* Euclidean distance with threshold */
	double *v1 = (double *) vector1;
	double *v2 = (double *) vector2;
	
	int i;

	double norm2 = 0.0;

	threshold = threshold * threshold;

	for( i = 0; i < size; i++ ) {
		if ( norm2 > threshold )
		break;
		double d = v1[ i ] - v2[ i ];
		norm2 += d * d;
	}
	return sqrt(norm2);
}

double vect_dist_manhattan_upto( size_t size, double threshold, char *vector1, char *vector2 ) {
	
  	/* Manhattan distance with threshold */
	double *v1 = (double *) vector1;
	double *v2 = (double *) vector2;
	
	int i;

	double norm = 0.0;

	for( i = 0; i < size; i++ ) {
		if ( norm > threshold )
		break;
		double d = abs( v1[ i ] - v2[ i ] );
		norm += d;
	}

	return norm;
}

/*

	Vector arithmetic functions

*/

void vector_divide( size_t size, char *vector, double num ) {
	
	int i;

	double *v = (double *) vector;

	for (i = 0; i < size; i++) {
		v[ i ] = v[ i ] / num;
	}
}

void vector_multiply( size_t size, char *vector, double num ) {

	int i;

	double *v = (double *) vector;

	for (i = 0; i < size; i++) {
		v[ i ] = v[ i ] * num;
	}
}

double vector_sum( size_t size, char *vector ) {
	int i;

	double *v = (double *) vector;

	double sum = 0.0;

	for (i = 0; i < size; i++) {
		sum += v[ i ];
	}

	return sum;
}

double vector_mean( size_t size, char *vector ) {

	double *v  = (double *) vector;
	double sum = vector_sum( size, vector );

	return sum / (double) size;
}

double vector_variance( size_t size, char *vector ) {
	double *v = (double *) vector;

	double mean = vector_mean( size, vector );

	int i;
	double var = 0.0;

	for (i = 0; i < size; i++ ) {
		double diff = v[i] - mean;
		var += (diff * diff);	
	}

	return var / (size - 1);
}

void vectorvector_add( size_t size, char *vector1, char *vector2 ) {
	
	double *v1 = (double *) vector1;
	double *v2 = (double *) vector2;

	int i;

	for (i = 0; i < size; i++ ){
		v1[ i ] = v1[ i ] + v2[ i ];
	}
}

double vectorvector_dot( size_t size, char *vector1, char *vector2 ) {
	
  	double *v1 = (double *) vector1;
	double *v2 = (double *) vector2;


	int i;
  	
  	double sum = 0.0;

	for (i = 0; i < size; i++) {
		sum += v1[ i ] * v2[ i ];
	}

	return sum;
}

double vectorvector_covariance( size_t size, char *vector1, char *vector2 ) {

	double ma = vector_mean( size, vector1 );
	double mb = vector_mean( size, vector2 );

	double *v1 = (double *) vector1;
	double *v2 = (double *) vector2;

	int i = 0;
	
	double sum = 0.0;

	for (i = 0; i < size; i++) {
		sum += ( v1[ i ] - ma ) * ( v2[ i ] - mb );
	}
	
	double cov = sum / ( size - 1 );

	return cov;
}

/*

	Toroid Grid functions 

*/

void find_eucl_grid_neighbors ( int r, int rr, int c, int rows, int columns, char* n) {

	int *neighbor = (int *) n;

	int xc = index2row( c, columns );
	int yc = index2col( c, columns );

	int x;
	int y;

	int index = 0;

	for ( x = xc - r; x <= (xc + r); x++ ) {
		for ( y = yc - r; y <= (yc + r); y++) {
			int dist = squared_eucl_grid_distance( x, y, xc, yc, rows, columns );
			
			if (dist <= rr ) {
				int index2 = toroid_coords2index( x, y, rows, columns );
				neighbor[ index ] = index2;	
				index++;
			}
		}
	}
	
}

int squared_eucl_grid_distance (int xi, int yi, int xj, int yj, int rows, int columns ) {

	int x1 = min( xi, xj );
	int x2 = max( xi, xj );
	int y1 = min( yi, yj );
	int y2 = max( yi, yj );

	int dx = min( abs( x1 - x2 ), abs( x1 + columns - x2));
	int dy = min( abs( y1 - y2 ), abs( y1 + rows - y2));

	return ( dx * dx ) + ( dy * dy );
}

int manhattan_grid_distance (int xi, int yi, int xj, int yj, int rows, int columns ) {

	int x1 = min( xi, xj );
	int x2 = max( xi, xj );
	int y1 = min( yi, yj );
	int y2 = max( yi, yj );

	int dx = min( abs( x1 - x2 ), abs((x1 + columns) - x2));
	int dy = min( abs( y1 - y2 ), abs((y1 + rows) - y2));

	return dx + dy;
}

int index2col (int i, int columns) {
	return (i % columns);
}

int index2row (int i, int columns) {
	return (int) ( i / columns );
}

int toroid_coords2index (int x, int y, int rows, int columns) {
	int index = (((x + rows) % rows) * columns) + ((y + columns) % columns);
	return index;
}

int min ( int x, int y ) {
	return x < y ? x : y;
}

int max ( int x, int y) {
	return x > y ? x : y;
}

/*

   ESOM training functions

*/

void fill_column ( AV* data, int i, char *column ) {
	int j;

	double *c = (double *) column;

	for (j = 0; j < av_len(data);j++) {
		char *row = SvRV (*av_fetch( data, j, 0 ) );
		double *r = (double *) row;
		c[ j ] = r[ i ];
	}	

}

void update_neuron( size_t size, double weight, char *vector, char *neuron ) {
	
	double *v = (double *) vector;
	double *n = (double *) neuron;

	int i;
	
	for (i = 0; i < size; i++ ){
		n[ i ] = n[ i ] + ( weight * ( v[ i ] - n[ i ]) );
	}
}

int simple_bmsearch ( size_t size, char *vector, AV* neurons ) {
	
	int i;
	int bm = -1;
	
	double min       = DBL_MAX;
	double threshold = min;

	for (i = 0; i < av_len(neurons); i++ ) {
		
		char   *neuron = SvRV (*av_fetch(neurons, i, 0));
		double  dist   = vect_dist_euclidean_upto( size, threshold, vector, neuron );
		
		if (dist < min) {
			min = dist;
			bm = i;
			threshold = dist;
		}
	}

	return bm;
}

void update_neighborhood ( char *vector, size_t size, char* neighbors, char* weights, size_t num, AV* neurons ) {
	
	int i;

	double       *w = (double *) weights;
	unsigned int *n = (unsigned int *) neighbors;

	for (i = 0; i < num; i++ ) {
		char  *neuron  = SvRV (*av_fetch( neurons, n[ i ], 0) );

		if ( w[ i ] != 0.0 ) {
			update_neuron( size, w[ i ], vector, neuron );
		}
	}
}

