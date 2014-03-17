package Anorman::ESOM::Math::Mahalanobis;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data::Algorithms::MahalanobisDistance;
use Anorman::ESOM;

sub new {
	my $that  = shift;
	my $class = ref $that || $that;

	my $esom = shift;

	if ($esom->_has_wts) {
		trace_error("No class mask present") unless $esom->_has_cmx;

	} elsif ($esom->_has_lrn) {
		trace_error("No class data present") unless $esom->_has_cls;
	}

	my $classes     = $esom->class_table;
	my $bestmatches = $esom->bestmatches;

	my %mhdist = ();

	foreach my $class(@{ $esom->class_table }) {
		next unless $class->index > 0;

		my $name    = $class->name;
		my $members = $class->members;
		my $size = @{ $members };
			
		print "[ $name $size ]\n";
		my $matrix = $esom->weights->data->view_selection( $members );

		my $mh = Anorman::Data::Algorithms::MahalanobisDistance->new( $matrix->copy );
		$mhdist{ $class->index } = $mh;	
	}
	my $self = { 'esom' => $esom };

	bless ($self, $class);

}

sub apply {

}

sub quick_apply {

}

1;

