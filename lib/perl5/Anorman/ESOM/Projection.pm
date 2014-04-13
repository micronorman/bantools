package Anorman::ESOM::Projection;

use strict;
use warnings;

use Anorman::Common;

use Anorman::Data;
use Anorman::ESOM::BMSearch qw(bm_brute_force_search);
use Anorman::ESOM::DataItem;
use Anorman::ESOM::File;
use Anorman::ESOM::Grid;

use vars qw(@ISA @EXPORT_OK);

@ISA       = qw(Exporter);
@EXPORT_OK = qw(project classify bestmatch_distances);

sub project {
	# projects multivariate data onto an ESOM grid
	# accepts a lrn-file object and a wts-file object.
	# returns a bm-file object
	my ($lrn, $wts) = @_;

	trace_error("Not a lrn-file") unless $lrn->isa('Anorman::ESOM::File::Lrn');
	trace_error("Not a wts-file") unless $wts->isa('Anorman::ESOM::File::Wts');
	trace_error("Vector dimension mismatch between lrn- and wts-data") if ($wts->dimensions != $lrn->dimensions);

	my $rows    = $wts->rows;
	my $columns = $wts->columns;
	my $neurons = $wts->data; 
	my $size    = $lrn->size;
	my $bm      = &_new_bm_file( $rows, $columns, $lrn->datapoints );
	my $dist    = Anorman::Data->vector( $size );
	my $grid    = Anorman::ESOM::Grid::Rectangular->new;
	
	$grid->rows( $rows );
	$grid->columns( $columns );

	warn "Projecting data onto weights...\n" if $VERBOSE;

	my $i = -1;
	while ( ++$i < $size ) {
		my $index  = $lrn->keys->get( $i );
		my $vector = $lrn->data->view_row( $i );

		my ($neuron_i, $distance) = bm_brute_force_search( $vector, $neurons );
		my $bestmatch = Anorman::ESOM::DataItem::BestMatch->new( $index,
									 $grid->index2row( $neuron_i ),
									 $grid->index2col( $neuron_i ) );

		$bm->add( $bestmatch );
		$dist->set( $i, $distance ); 
	}

	return wantarray ? ($bm, $dist) : $bm;
}

sub bestmatch_distances {
	# calculates distances between a set of data vectors and their projected bestmatches (neurons).
	# data vectors will be projected (using "project") if no bestmatch-file was provided
	# NOTE: This will override any existing bm-distances present in the provided BestMatch-file;
	my ($lrn, $grid, $bm) = @_;

	trace_error("Not a lrn-file") unless $lrn->isa('Anorman::ESOM::File::Lrn');
	trace_error("Not a valid grid object") unless $grid->isa('Anorman::ESOM::Grid');

	my $func = $grid->distance_function;
	my $size = $lrn->size;
	my $dist = Anorman::Data->packed_vector( $lrn->size );

	if (!defined $bm) {
		# Create a new bm-file if none was provided.
		($bm, $dist) = &project( $lrn, $grid->get_wts );
	} else {
		warn "Calculating bestmatch distances...\n" if $VERBOSE;

		my $i = -1;
		while ( ++$i < $size ) {
			my $index     = $lrn->keys->get( $i );
			my $vector    = $lrn->data->view_row( $i );
			my $bestmatch = $bm->get_quick( $i );
			my $neuron    = $grid->get_neuron( $bestmatch->row, $bestmatch->column );

			# Execute the distance-function embedded into the grid on each vector/neuron pair.
			my $bm_dist      = $func->apply( $vector, $neuron );

			$dist->set( $i, $bm_dist );
		}
	}	
	
	return $dist;
}

sub classify {
	# uses a class mask to classify bestmatches
	# accepts a bm-file object and a cmx-file object. 
	# returns a cls-file object
	my ($bmfile, $cmxfile) = @_;
	
	my $bestmatches = $bmfile->data;

	trace_error("Not a bm-file") unless $bmfile->isa('Anorman::ESOM::File::BM');
	trace_error("Not a cmx-file") unless $cmxfile->isa('Anorman::ESOM::File::ClassMask');
	#trace_error("Class mask has the wrong number of neurons") if $bmfile->neurons != $cmxfile->neurons;

	my $cls  = Anorman::ESOM::File::Cls->new();
	my $grid = Anorman::ESOM::Grid::Rectangular->new;

	$grid->rows( $bmfile->rows );
	$grid->columns( $bmfile->columns );

	# transfer class table to cls-file
	$cls->classes( $cmxfile->classes );

	foreach my $bm( @{ $bestmatches }) {
		my $neuron_i = $grid->coords2index( $bm->row, $bm->column );

		$cls->add( $bm->index, $cmxfile->get_by_index( $neuron_i ) );
	}

	return $cls;
}

sub _new_bm_file {
	my ($rows, $columns, $datapoints ) = @_;

	my $bm = Anorman::ESOM::File::BM->new();

	$bm->rows( $rows );
	$bm->columns( $columns );
	$bm->datapoints( $datapoints );

	return $bm;
}

1;
