package Anorman::ESOM::Grid;

use strict;

use Anorman::Common;
use Anorman::Math::DistanceFactory;
use Anorman::Data::LinAlg::Property qw(is_matrix);

# Random number generators
use Math::Random::MT::Auto qw(gaussian);
use Math::Random::MT::Auto::Range;

use Data::Dumper;

sub new {
	my $class = shift;

	$class->_error("Wrong number of arguments") if (@_ != 0 && @_ != 2);

	my $self = {};

	bless ( $self, ref $class || $class );
	
	if (@_ == 2) {
		$self->{'_size'} = $_[0];
		$self->{'_dim'}  = $_[1];
	}
	
	$self->{'_distance_function'} = Anorman::Math::DistanceFactory->get_function( SPACE => 'euclidean', PACKED => 1 );

	return $self;
}

sub dim {
	my $self = shift;

	if (defined $_[0]) { 
		$self->{'_dim'} = $_[0];
	} else {
		return $self->{'_dim'};
	}
}

sub size {
	my $self = shift;

	if (defined $_[0]) { 
		$self->{'_size'} = $_[0];
	} else {
		return $self->{'_size'};
	}
}

sub distance_function {
	my $self = shift;
	my $func = shift;

	if (defined $func) {
		#$self->_error("Not a valid distance function") unless (ref $func) =~ m/::Math::Distance::/;
		$self->{'_distance_function'} = $func;
	}

	return $self->{'_distance_function'};
}

sub init {
	my $self   = shift;
	my $desc   = shift;
	my $method = defined $_[0] ? shift : 'norm_mean_2std';

	# In the absence of any data descriptives, set everything to zero
	$method = 'zero' if !defined $desc;

	my $dim  = $self->dim;
	my $size = $self->size;  

	warn "Initializing grid (Method: $method)\n" if $VERBOSE;

	trace_error("Grid weights have not been set. Cannot initialize") unless is_matrix( $self->get_weights );

	if ($method eq 'norm_mean_2std') {
		# generate random vectors based on gaussian distribution [ mean ± 2stdevs ] from input descriptives
		my $j = -1;
		while (++$j < $dim) {
			my $sd   = $desc->stdevs->[ $j ];
			my $mean = $desc->means->[ $j ];
			my $i = $size;
			my $vals = [];

			while (--$i >= 0) {
				$vals->[ $i ] =  gaussian( 2 * $sd, $mean ); 
			}

			$self->get_weights->view_column( $j )->assign( $vals );
		}
	} elsif ($method eq 'uni_min_max') {
		# generate random vectors based on uniform distribution [ min, max ]
		my $uniform = Math::Random::MT::Auto::Range->new( LO => 0.0 , HI => 1.0, TYPE => 'DOUBLE');

		my $j = -1;
		while ( ++$j < $dim ) {
			my $min = $desc->minima->[ $j ];
			my $max = $desc->maxima->[ $j ];

			$uniform->set_range( $min, $max );
			my $i = $size;
			my $vals = [];

			while ( --$i >= 0 ) {
				$vals->[ $i ] = $uniform->rrand()
			}

			$self->get_weights->view_column( $j )->assign( $vals );
		}

	} elsif ($method eq 'uni_mean_2std') {
		my $uniform = Math::Random::MT::Auto::Range->new( LO => 0.0 , HI => 1.0, TYPE => 'DOUBLE');

		my $j = -1;
		while ( ++$j < $dim ) {
			my $sd   = $desc->stdevs->[ $j ];
			my $mean = $desc->means->[ $j ];

			$uniform->set_range( $mean - (2 * $sd), $mean + (2 * $sd) );
			my $i = $size;
			my $vals = [];

			while ( --$i >= 0 ) {
				$vals->[ $i ] = $uniform->rrand()
			}

			$self->get_weights->view_column( $j )->assign( $vals );
		}

	} elsif ($method eq 'zero') {
		$self->get_weights->assign(0);
	}
}

sub transform_radius {
	return $_[1];
}

sub _error {
	shift;
	trace_error(@_);
}

1;

package Anorman::ESOM::Grid::Matrix;

# grid data is stored in a packed dense Matrix. Indivdual neurons of size dim are stored as rows in the matrix
# inheriting classes must define the arrangement and retrieval of neurons

use strict;

use parent -norequire,'Anorman::ESOM::Grid';

use Anorman::Common;

use Anorman::Data::Matrix::DensePacked;
use Anorman::Data::LinAlg::Property qw( is_matrix );

sub new {
	my $class       = shift;

	$class->error("Wrong number of arguments") if (@_ != 0 && @_ != 2);

	my $self; 

	if (@_ == 2) {
		my ( $size, $dim ) = @_;

		$self = $class->SUPER::new( $size, $dim );
		$self->_init;
	} else {
		$self = $class->SUPER::new();
	}
	
	return $self;
}

# return a particular neuron as a row-vector
sub get_neuron {
	my $self = shift;
	return undef unless defined $self->{'_weights'};

	return $self->{'_weights'}->view_row( $_[0] );
}

sub get_weights {
	my $self = shift;
	return $self->{'_weights'};
}

sub set_weights {
	my $self = shift;
	$self->{'_weights'} = $_[0];
}

sub size {
	my $self = shift;

	if (defined $_[0]) {
		$self->SUPER::size($_[0]);
		$self->_init;
	} else {
		return $self->{'_size'};
	}
}

sub dim {
	my $self = shift;

	if (defined $_[0]) {
		$self->SUPER::dim($_[0]);
		$self->_init;
	} else {
		return $self->{'_dim'};
	}
}

sub _init {
	my $self = shift;

	my ( $size, $dim ) = @{ $self }{ qw/_size _dim/ };

	if (($size * $dim) > 0) {
		$self->{'_weights'} = Anorman::Data::Matrix::DensePacked->new( $size, $dim );
	}
}

1;

package Anorman::ESOM::Grid::Rectangular;

# grid is rectangular, i.e. arranged so that each node has 4 immediate neighbors (up, down, left, right)
use strict;
use parent -norequire, 'Anorman::ESOM::Grid::Matrix';

use Anorman::Common;
use Anorman::ESOM::File;

sub new {
	my $class = shift;
	$class->_error("Wrong number of arguments") if (@_ != 0 && @_ != 3);

	my $self;

	if (@_ == 3) {
		my ($rows, $cols, $dim) = @_;

		$self = $class->SUPER::new( $rows * $cols, $dim );

		$self->{'_rows'}    = $rows;
		$self->{'_columns'} = $cols;
	} else {
		$self = $class->SUPER::new();
	}

	return $self;
}

sub rows {
	my $self = shift;
	return $self->{'_rows'} unless defined $_[0];

	$self->{'_rows'} = $_[0];
	$self->size( $_[0] * $self->{'_columns'} );
}

sub columns {
	my $self = shift;
	return $self->{'_columns'} unless defined $_[0];
	$self->{'_columns'} = $_[0];
	$self->size( $_[0] * $self->{'_rows'} );

}

sub coords2index {
	my $self = shift;
	return _planar_coords2index($_[0], $_[1], $self->columns);
}

sub index2col {
	my $self = shift;
	return _index2col($_[0], $self->columns);
}

sub index2row {
	my $self = shift;
	return _index2row($_[0],$self->columns);
}

sub init {
	my ($self,$desc, $method) = @_;
	
	if (defined $method && $method eq 'pca') {
		warn "Initializing grid using the pca method\n";
		my $i = 0;
		while ( ++$i <= $self->rows ) {
			my $row_factor = ( $i - ($self->rows / 2) - 0.5) / (($self->rows / 2) - 0.5);

			my $j = 0;
			while ( ++$j < $self->columns ) {
				my $col_factor = ($j - ($self->columns / 2) - 0.5) / (($self->columns / 2) - 0.5);
				my $neuron = $self->get_neuron( $i - 1, $j - 1);
				my $d = -1;

				while ( ++$d < $self->dim ) {
					$neuron->set( $d, $desc->means->[ $d ] 
					+ (2 * $row_factor * $desc->first_eigenvalue  * $desc->first_eigenvector->get($d))
					+ (2 * $col_factor * $desc->second_eigenvalue * $desc->second_eigenvector->get($d)));
				}
			}
		
		}
	} else {
		$self->SUPER::init(@_);
	}
}

sub get_neuron {
	my $self = shift;

	if (@_ != 2) {
		return $self->{'_weights'}->view_row( $_[0] );
	} else {
		return $self->{'_weights'}->view_row( _planar_coords2index( $_[0], $_[1], $self->columns ) );
	}
}

sub load_weights {
	my $self     = shift;
	my $filename = shift;
	
	my $wts = Anorman::ESOM::File::Wts->new;

	$wts->load( $filename );

	my $grid = Anorman::ESOM::Grid::ToroidEuclidean->new;

	$grid->rows( $wts->rows );
	$grid->columns( $wts->columns );
	$grid->dim( $wts->dimensions );

	my $i = -1;
	while ( ++$i < $wts->neurons ) {
		$grid->get_neuron( $i )->assign( $wts->data->view_row($i) );
	}

	return $grid;
}

sub save_weights {
	my $self     = shift;
	my $filename = shift;

	my $wts = $self->get_wts;

	$wts->save( $filename );

}

sub get_wts {
	my $self = shift;

	my $wts = Anorman::ESOM::File::Wts->new( $self->rows, $self->columns, $self->dim );

	$wts->data( $self->get_weights );

	return $wts;
}


use Inline (C => Config =>
		DIRECTORY => $Anorman::Common::AN_TMP_DIR,
		NAME      => 'Anorman::ESOM::Grid::Rectangular',
		ENABLE    => AUTOWRAP =>
		LIBS      => '-L' . $Anorman::Common::AN_SRC_DIR . '/lib',
		INC       => '-I' . $Anorman::Common::AN_SRC_DIR . '/include'

           );

use Inline C => <<'END_OF_C_CODE';

static int min( int, int );
static int max( int, int );

/* grid distance functions */
int squared_eucl_grid_distance (int x1, int y1, int x2, int y2 ) {

	int dx = x1 - x2;
	int dy = y1 - y2;

	return ( dx * dx ) + ( dy * dy );
}

int manhattan_grid_distance (int x1, int y1, int x2, int y2 ) {

	return abs( x1 - x2 ) + abs( y1 - y2 );
}

int max_grid_distance (int x1, int y1, int x2, int y2, int rows, int columns) {

	return max( abs( x1 - x2 ), abs( y1 - y2) );
}

/* same as above but on toroidal grids (i.e. PacMan-space) 
 * the dimensions of the grid are required
 */

int toroid_squared_euclidean_grid_distance (int xi, int yi, int xj, int yj, int rows, int columns ) {

	int x1 = min( xi, xj );
	int x2 = max( xi, xj );
	int y1 = min( yi, yj );
	int y2 = max( yi, yj );

	int dx = min( abs( x1 - x2 ), abs( x1 + columns - x2));
	int dy = min( abs( y1 - y2 ), abs( y1 + rows - y2));

	return ( dx * dx ) + ( dy * dy );
}

int toroid_manhattan_grid_distance (int xi, int yi, int xj, int yj, int rows, int columns ) {

	int x1 = min( xi, xj );
	int x2 = max( xi, xj );
	int y1 = min( yi, yj );
	int y2 = max( yi, yj );

	int dx = min( abs( x1 - x2 ), abs((x1 + columns) - x2));
	int dy = min( abs( y1 - y2 ), abs((y1 + rows) - y2));

	return dx + dy;
}

int toroid_max_grid_distance (int xi, int yi, int xj, int yj, int rows, int columns) {
	int x1 = min( xi, xj );
	int x2 = max( xi, xj );
	int y1 = min( yi, yj );
	int y2 = max( yi, yj );

	int dx = min( abs( x1 - x2 ), abs((x1 + columns) - x2));
	int dy = min( abs( y1 - y2 ), abs((y1 + rows) - y2));

	return max(dx, dy);
}


/* grid coordinate caluclations */

int _index2col (int i, int columns) {
	return (i % columns);
}

int _index2row (int i, int columns) {
	return (int) ( i / columns );
}


int _planar_coords2index (int x, int y, int columns) {
	return x * columns + y;
}

int _toroid_coords2index (int x, int y, int rows, int columns) {
	int index = (((x + rows) % rows) * columns) + ((y + columns) % columns);
	return index;
}

void find_euclidean_toroid_grid_neighbors ( int r, int rr, int c, char* n, int rows, int columns ) {

	int* neighbor = (int*) n;

	int xc = _index2row( c, columns );
	int yc = _index2col( c, columns );

	int x;
	int y;

	int index = 0;
	for ( x = xc - r; x <= (xc + r); x++ ) {
		for ( y = yc - r; y <= (yc + r); y++) {
			int dist = toroid_squared_euclidean_grid_distance( x, y, xc, yc, rows, columns );
			
			if (dist <= rr ) {
				int index2 = _toroid_coords2index( x, y, rows, columns );
				neighbor[ index ] = index2;	
				index++;
			}
		}
	}
	
}

void find_manhattan_toroid_grid_neighbors ( int r, int rr, int c, char* n, int rows, int columns ) {

	int* neighbor = (int*) n;

	int xc = _index2row( c, columns );
	int yc = _index2col( c, columns );

	int x;
	int y;

	int index = 0;

	for ( x = xc - r; x <= (xc + r); x++ ) {
		for ( y = yc - r; y <= (yc + r); y++) {
			int dist = toroid_manhattan_grid_distance( x, y, xc, yc, rows, columns );
			
			if (dist <= rr ) {
				int index2 = _toroid_coords2index( x, y, rows, columns );
				neighbor[ index ] = index2;	
				index++;
			}
		}
	}
	
}

void find_max_toroid_grid_neighbors ( int r, int rr, int c, char* n, int rows, int columns ) {

	int* neighbor = (int*) n;

	int xc = _index2row( c, columns );
	int yc = _index2col( c, columns );

	int x;
	int y;

	int index = 0;

	for ( x = xc - r; x <= (xc + r); x++ ) {
		for ( y = yc - r; y <= (yc + r); y++) {
			int dist = toroid_max_grid_distance( x, y, xc, yc, rows, columns );
			
			if (dist <= rr ) {
				int index2 = _toroid_coords2index( x, y, rows, columns );
				neighbor[ index ] = index2;	
				index++;
			}
		}
	}
	
}

int min ( int x, int y ) {
	return x < y ? x : y;
}

int max ( int x, int y ) {
	return x > y ? x : y;
}

END_OF_C_CODE

1;

package Anorman::ESOM::Grid::ToroidRectangular;

# grid is toroidal (as opposed to planar) with an internal rectangular grid

use strict;
use parent -norequire,'Anorman::ESOM::Grid::Rectangular';

sub new { return shift->SUPER::new(@_) };

sub coords2index {
	my $self = shift;
	return Anorman::ESOM::Grid::Rectangular::_toroid_coords2index( $_[0], $_[1], $self->rows, $self->columns );
}

1;

package Anorman::ESOM::Grid::Toroid;

use strict;
use parent -norequire,'Anorman::ESOM::Grid::ToroidRectangular';

use Anorman::Common;

sub new { 
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	
	#$self->{'_neighbors'} = {};
	$self->{'_distance_cache'} = [];

	return $self;
}

sub inside_grid {
	my $self = shift;
	return 1;
}

sub neighbors {
	my $self    = shift;
	my ($c, $r) = @_;
	#my $ptr     = $self->{'_neighbors'};

	# check for neighbor map in cache
	#if (exists $ptr->{ $c }) {
	#	return $ptr->{ $c };
	# }

	# conversion of radius (euclidean distance trick) and allocation of string of unsigned integers for storing neighbors
	my $rr   = $self->transform_radius( $r );
	my $size = scalar @{ $self->{'_distance_cache'} };
	my $n    = pack("I$size" , (-1) x $size );


	#NOTE: Had to disable this giant memory leak. Consider a cache with size limit and LRU dumping policy	
	#$ptr->{ $c } = $n;
	
	$self->_find_neighbors( $r, $rr, $c, $n );
	return $n;
}

sub distances {
	# calculate distance map of all neigbors within a given radius
	# these only changes if the neighborhood radius is changed and
	# can therefore be cached before each epoch
	my $self = shift;
	my $r    = shift;
	
	return $self->{'_distance_cache'} unless defined $r;

	# flush caches
	@{ $self->{'_distance_cache'} } = ();
	#%{ $self->{'_neighbors'} } = ();

	my $rr   = $self->transform_radius( $r );

	warn "\tCaching relative grid distances\n" if $VERBOSE;

	# 
	foreach my $x( -$r..$r ) {
		foreach my $y( -$r..$r ) {
			my $dist = $self->grid_distance( 0, 0, $x, $y );
			push @{ $self->{'_distance_cache'} }, $dist if ($dist <= $rr);
		}
	}

	return $self->{'_distance_cache'};
}

sub immediate_neighbors {
	# returns the the internal indices of the 4 immediate neighbors (a.k.a the von Neumann neighborhood)
	# of a neuron
	my $self = shift;
	my $c    = shift;

	my $x = $self->index2row( $c );
	my $y = $self->index2col( $c );

	my $n = [];

	$n->[0] = $self->coords2index( $x - 1, $y);
	$n->[1] = $self->coords2index( $x + 1, $y);
	$n->[2] = $self->coords2index( $x, $y - 1);
	$n->[3] = $self->coords2index( $x, $y + 1);

	return wantarray ? @{ $n } : $n;
}

sub neighbors_XbyX {
	my $self = shift;
	my $c    = shift;
	my $X    = shift;

	my $x    = $self->index2row( $c );
	my $y    = $self->index2col( $c );
	my $n    = [];

	my $dist = int($X - 1) / 2;

	# add 8-neighborhood and include the center neuron
	for (my $i = -$dist; $i <= $dist; $i++) {
		for (my $j = -$dist; $j <= $dist; $j++) {
			push @{ $n }, 
			$self->coords2index( $x + $i, $y + $j);
		}	
	}

	return wantarray ? @{ $n } : $n;  
}

1;

package Anorman::ESOM::Grid::ToroidEuclidean;

# a toroidal grid (see above) were grid distances are calculated in Euclidean space

use strict;
use parent -norequire,'Anorman::ESOM::Grid::Toroid';

sub new { return shift->SUPER::new(@_) };

sub grid_distance {
	my $self = shift;
	return Anorman::ESOM::Grid::Rectangular::toroid_squared_euclidean_grid_distance( @_, $self->rows, $self->columns );
}

sub _find_neighbors {
	my $self = shift;
	Anorman::ESOM::Grid::Rectangular::find_euclidean_toroid_grid_neighbors(@_, $self->rows, $self->columns );
}

sub transform_radius {
	# saves having to apply sqrt in the grid distance calculations
	return ($_[1] * $_[1]);
}

1;

package Anorman::ESOM::Grid::ToroidManhattan;

# a toroidal grid (see above) were grid distances are calculated in Manhattan/taxicab space

use strict;
use parent -norequire,'Anorman::ESOM::Grid::Toroid';

sub new { return shift->SUPER::new(@_) };

sub grid_distance {
	my $self = shift;
	return  Anorman::ESOM::Grid::Rectangular::toroid_manhattan_grid_distance( @_, $self->rows, $self->columns );
}

sub _find_neighbors {
	my $self = shift;
	Anorman::ESOM::Grid::Rectangular::find_manhattan_toroid_grid_neighbors(@_, $self->rows, $self->columns );
}

package Anorman::ESOM::Grid::ToroidMax;

# a toroidal grid (see above) were grid distances are calculated in Maximum distance space

use strict;
use parent -norequire,'Anorman::ESOM::Grid::Toroid';

sub new { return shift->SUPER::new(@_) };

sub grid_distance {
	my $self = shift;
	return Anorman::ESOM::Grid::Rectangular::toroid_max_grid_distance( @_, $self->rows, $self->columns );
}

sub _find_neighbors {
	my $self = shift;
	Anorman::ESOM::Grid::Rectangular::find_max_toroid_grid_neighbors(@_, $self->rows, $self->columns );
}


1;
