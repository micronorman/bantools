package Anorman::ESOM::UMatrixRenderer;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data;

sub new {
	my $that  = shift;

	my ($class, $self);

	$class = ref $that || $that;
	$self  = { '_cached_matrix' => undef, '_wts_changed' => 1 };

	return bless ( $self, $class );
}

sub render {
	my ($self, $grid) = @_;

	trace_error("Not an ESOM grid") unless $grid->isa("Anorman::ESOM::Grid");
	trace_error("ESOM grid contains no weights data") unless (defined $grid->get_weights);

	if (!defined $self->{'_cached_matrix'} || $self->{'_wts_changed'}) {
		my $h  = $grid->rows;
		my $w  = $grid->columns;
		my $df = $grid->distance_function;

		my $matrix = Anorman::Data->matrix( $h, $w );
		warn "Calculating U-Matrix heights ...\n" if $VERBOSE;
		
		my $row = $h;
		while ( --$row >= 0 ) {
			# Calculate U-Matrix on a row-by-row basis
			my $current_row = [];

			my $column = $w;
			while ( --$column >= 0) {
				my $i     = $grid->coords2index( $row, $column );
				my $sum   = 0;
				my $n     = 0;

				foreach my $j( $grid->immediate_neighbors( $i ) ) {
					$sum += $grid->distance_function->apply_quick( $grid->get_neuron( $i ),  $grid->get_neuron( $j ) );
					$n++;
				}

				$current_row->[ $column ] = $sum / $n;
			}

			$matrix->view_row( $row )->assign( $current_row );
		}

		$matrix->normalize;


		$self->{'_cached_matrix'} = $matrix;
		$self->{'_wts_changed'}   = 0;
	}

	return $self->{'_cached_matrix'};
}

sub reset_cache {
	my $self = shift;
	undef $self->{'_cached_matrix'};
}

sub wts_changed {
	my $self = shift;
	$self->{'_wts_changed'} = 1;
}

1;
