package Anorman::ESOM::Projection;

use strict;
use warnings;

use Anorman::Common;

use Anorman::ESOM::BMSearch qw(bm_brute_force_search);
use Anorman::ESOM::DataItem;
use Anorman::ESOM::File;
use Anorman::ESOM::Grid;

use vars qw(@ISA @EXPORT_OK);

@ISA       = qw(Exporter);
@EXPORT_OK = qw(project classify);

sub project {
	my ($lrn, $wts) = @_;

	trace_error("Not a lrn-file") unless $lrn->isa('Anorman::ESOM::File::Lrn');
	trace_error("Not a wts-file") unless $wts->isa('Anorman::ESOM::File::Wts');
	trace_error("Dimensions do not match") if ($wts->dimensions != $lrn->dimensions);

	my $rows    = $wts->rows;
	my $columns = $wts->columns;

	my $bm = Anorman::ESOM::File::BM->new();
	
	$bm->rows( $rows );
	$bm->columns( $wts->columns );
	$bm->datapoints( $lrn->datapoints );

	my $grid    = Anorman::ESOM::Grid::Rectangular->new;
	
	$grid->rows( $rows );
	$grid->columns( $columns );

	my $weights = $wts->data; 
	my $size    = $lrn->size;

	warn "Projecting data onto weights...\n" if $VERBOSE;

	my $i = -1;
	while ( ++$i < $size ) {
		my $index  = $lrn->keys->get( $i );
		my $vector = $lrn->data->view_row( $i );

		my $neuron_i  = bm_brute_force_search( $vector, $weights );
		my $bestmatch = Anorman::ESOM::DataItem::BestMatch->new( $index,
									 $grid->index2row( $neuron_i ),
									 $grid->index2col( $neuron_i ) );

		$bm->add( $bestmatch ); 
	}

	return $bm;
}

sub classify {
	my ($bmfile, $cmxfile) = @_;
	
	my $class_mask  = $cmxfile->map;
	my $bestmatches = $bmfile->data;

	trace_error("Not a bm-file") unless $bmfile->isa('Anorman::ESOM::File::BM');
	trace_error("Not a cmx-file") unless $cmxfile->isa('Anorman::ESOM::File::ClassMask');
	trace_error("Class mask has the wrong number of neurons") if $bmfile->neurons != $cmxfile->neurons;

	my $cls  = Anorman::ESOM::File::Cls->new();
	my $grid = Anorman::ESOM::Grid::Rectangular->new;

	$grid->rows( $bmfile->rows );
	$grid->columns( $bmfile->columns );

	$cls->classes( $cmxfile->classes );

	foreach my $bm( @{ $bestmatches }) {
		my $neuron_i = $grid->coords2index( $bm->row, $bm->column );

		$cls->add( $bm->index, $class_mask->{ $neuron_i } );
	}

	return $cls;
}

1;
