package Anorman::ESOM::GrowGrid;

# A module for handling growing of ESOM weight grids
# Internally, the grid is copied and expanded in both directions. New weight
# vectors are interpolated according to their neighboring vectors

use vars qw($VERSION @EXPORT @ISA);

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw (grow_grid);

$VERSION = '0.4';


use Anorman::Common;
use Anorman::ESOM::Grid;
use Anorman::Data::Matrix;
use POSIX qw(floor);
use List::Util qw(min max);

# default internal interpolator
my $interp   = Anorman::ESOM::GrowGrid::Interpolator::Mean->new();

# grows the grid and interpolates between old neurons to fill in larger grid
sub grow_grid {
	&_check_grid($_[0]);
	&_check_growth_dims(@_);

	my ( $old_grid, $new_rows, $new_cols ) = @_;

	warn "Grow grid [ " . $old_grid->rows . " x " . $old_grid->columns . " ] => [ $new_rows x $new_cols ]\n";

	my $tmp_grid    = Anorman::ESOM::Grid::ToroidEuclidean->new;
	my $tmp_weights = Anorman::Data::Matrix::DensePacked->new( $new_cols * $old_grid->rows, $old_grid->dim );

	$tmp_grid->rows( $old_grid->rows );
	$tmp_grid->columns( $new_cols );
	$tmp_grid->dim( $old_grid->dim );
	$tmp_grid->set_weights( $tmp_weights );
	
	$interp->set_grid( $tmp_grid );

	&_grow_columns( $old_grid, $tmp_grid );

	my $new_grid    = Anorman::ESOM::Grid::ToroidEuclidean->new;
	my $new_weights = Anorman::Data::Matrix::DensePacked->new( $new_rows * $new_cols, $tmp_grid->dim );

	$new_grid->rows( $new_rows);
	$new_grid->columns( $new_cols );
	$new_grid->dim( $tmp_grid->dim );
	$new_grid->set_weights( $new_weights );

	$interp->set_grid( $new_grid );

	&_grow_rows( $tmp_grid, $new_grid );

	warn "Done growing\n";

	return $new_grid; 
}

sub _grow_rows {
	warn "Growing rows...\n";
	my ($old_grid, $new_grid ) = @_;

	my ($old_rows, $old_cols) = ($old_grid->rows, $old_grid->columns);
	my ($new_rows, $new_cols) = ($new_grid->rows, $new_grid->columns);
	my $dim = $old_grid->dim;

	my $new_weights = $new_grid->get_weights;

	# calculate number of interpolation steps per row
	my $row_step = max(1,floor( 0.5 + ($old_rows / max( 1, $new_rows - $old_rows)))); 	

	my $counter_all = 0;
	my $counter     = 0;

	my ($c, $r, $s);

	$c = -1;
	while ( ++$c < $new_cols ) {
		
		# create buffer for row slice (i.e. a row of neruon-vectors)
		my $row = Anorman::Data::Matrix::DensePacked->new( $new_rows, $dim );

		my $counter_row = 0;
		my $counter_nan = 0;

		$r = -1;
		while ( ++$r < $new_rows) {
			
			# transfer existing neuron from old grid
			$s = -1;
			while ( ++$s < $row_step ) {
				if ($r < $new_rows) {
					my $old_index  = $old_grid->coords2index($r - $counter_nan, $c);
					my $old_neuron = $old_grid->get_neuron( $old_index );

					$row->view_row( $r )->assign( $old_neuron );
					$r++;
					$counter_row++;
				}

			}

			# insert empty neuron
			if ($r < $new_rows) {
				$row->view_row( $r )->assign( nan );
				$counter_row++;
				$counter_nan++;
			}
		}

		# transfer expanded row slice to new grid
		my $a = $counter_all - 1;
		while ( ++$a < ($counter_all + $counter_row) ) {
			my $index = (( $a - $counter_all) * $new_cols) + $counter;
			my $buffer_row = $new_weights->view_row( $index );
			my $row_slice  = $row->view_row( $a - $counter_all );

			$buffer_row->assign( $row_slice );
			
		}

		$counter_all += $counter_row;
		$counter++;
	}

	print STDERR $new_weights;
	# interpolate into empty neurons
	my $i = -1;
	while ( ++$i < $new_weights->rows ) {
		my $probe_val = $new_weights->view_row( $i )->get(0);
		
		if ($probe_val != $probe_val) { # test for NaN values
			$new_weights->view_row( $i )->assign( $interp->interpolate_row($i) );
		}
	}	
}

sub _grow_columns {
	warn "Growing columns...\n";
	my ($old_grid, $new_grid ) = @_;

	my ($old_rows, $old_cols) = ($old_grid->rows, $old_grid->columns);
	my ($new_rows, $new_cols) = ($new_grid->rows, $new_grid->columns);

	my $dim     = $old_grid->dim;
	my $new_weights = $new_grid->get_weights;

	# calculate number of interpolation steps per column
	my $col_step = max(1,floor( 0.5 + ($old_cols / max( 1, $new_cols - $old_cols)))); 	

	my $counter_all = 0;

	my ($c, $r, $s);

	$r = -1;
	while ( ++$r < $old_rows ) {
		
		# create buffer for column slice
		my $col = Anorman::Data::Matrix::DensePacked->new( $new_cols, $dim );

		my $counter_col = 0;
		my $counter_nan = 0;

		$c = -1;
		while ( ++$c < $new_cols) {
			
			# transfer existing neuron from old grid
			$s = -1;
			while ( ++$s < $col_step ) {
				if ($c < $new_cols) {
					my $old_index  = $old_grid->coords2index($r, $c - $counter_nan );
					my $old_neuron = $old_grid->get_neuron( $old_index );

					$col->view_row( $c )->assign( $old_neuron );
					$c++;
					$counter_col++;
				}

			}

			# insert empty neuron
			if ($c < $new_cols) {
				$col->view_row( $c )->assign( nan );
				$counter_col++;
				$counter_nan++;
			}
		}

		# transfer expanded row slice to new grid
		my $a = $counter_all - 1;
		while ( ++$a < ($counter_all + $counter_col) ) {
			my $buffer_col = $new_weights->view_row( $a );
			my $col_slice  = $col->view_row( $a - $counter_all );

			$buffer_col->assign( $col_slice );
			
		}

		$counter_all += $counter_col;
	}

	print STDERR $new_weights;
	# interpolate into empty neurons
	my $i = -1;
	while ( ++$i < $new_weights->rows ) {
		my $probe_val = $new_weights->view_row( $i )->get(0);
			
		if ($probe_val != $probe_val) { # test for NaN values
			$new_weights->view_row( $i )->assign( $interp->interpolate_col($i) );
		}
	}
}

sub _check_growth_dims {
	my ($grid, $rows, $cols) = @_;

	if ($rows < $grid->rows || $cols < $grid->columns) {
		trace_error("Impossible to grow something smaller! Dimensions of new grid [ $rows x $cols ] must be equal to or greater than old grid [ " . $grid->rows . " x " . $grid->columns . " ]");
	}
}

sub _check_grid {
	trace_error("Input data is not a grid object") unless _is_grid($_[0]);
}

sub _is_grid {
	return ref($_[0]) =~ m/Anorman::ESOM::Grid::/;
}

package Anorman::ESOM::GrowGrid::Interpolator;

use strict;

use Anorman::Common;

sub new {
	return bless ( { '_rec_grid' => undef }, $_[0] );
} 

sub set_grid {
	my $self = shift;
	Anorman::ESOM::GrowGrid::_check_grid($_[0]);
	$self->{'_rec_grid'} = $_[0];
}

1;

package Anorman::ESOM::GrowGrid::Interpolator::Mean;

# empty neurons are fed the adjoining neurons (unless they are also empty) and divided by the number of added neighbors

use strict;
use parent -norequire, 'Anorman::ESOM::GrowGrid::Interpolator';

use Anorman::Data::LinAlg::Property qw( :vector );
use Anorman::Data::Functions::VectorVector qw (vv_add_assign);
use Anorman::Data::Functions::Vector qw(v_div_assign);
use Anorman::Data::Vector;

sub interpolate {
	my $self = shift;
	my $rec_grid = $self->{'_rec_grid'};

	my ($r, $c) = ($rec_grid->rows, $rec_grid->columns );

	my @neighbors = $rec_grid->immediate_neighbors( $_[0] );

	my $tmp_neuron = Anorman::Data::Vector::DensePacked->new( $rec_grid->dim );
	$tmp_neuron->assign(0);
	my $count = 0;

	foreach my $n(@neighbors) {
		my $neigh_vec = $rec_grid->get_weights->view_row($n);
		my $probe_val = $neigh_vec->get(0);
	
		if ($probe_val == $probe_val) { # any there values here?
			vv_add_assign( $tmp_neuron, $neigh_vec );
			$count++;
		}
	}

	v_div_assign( $tmp_neuron, $count ) unless $count == 0;

	return $tmp_neuron;
}

sub interpolate_row {
	my $self = shift;
	return $self->interpolate($_[0]);
}

sub interpolate_col {
	my $self = shift;
	return $self->interpolate($_[0]);
}


1;

package Anorman::ESOM::GrowGrid::Interpolator::PreviousNeighbor;

# empty class for now...

use strict;
use parent -norequire, 'Anorman::ESOM::GrowGrid::Interpolator';

use Anorman::Data::LinAlg::Property qw( :vector );
use Anorman::Data::Vector;

sub interpolate {

}

sub interpolate_row {

}

sub interpolate_col {

}

1;

