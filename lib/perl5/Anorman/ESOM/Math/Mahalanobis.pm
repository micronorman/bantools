package Anorman::ESOM::Math::Mahalanobis;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Data::Algorithms::MahalanobisDistance;

use Data::Dumper;

sub new {
	my $that  = shift;
	my $class = ref $that || $that;

	my $esom = shift;

	if ($esom->_has_wts) {
		trace_error("No class mask present") unless $esom->_has_cmx;
		$esom->_cmx->index_classes;

	} 

	warn "Analyzing ", $esom->weights->data->rows, " neuron grid...\n";
	my $classes     = $esom->class_table;
	my %mhdist = ();

	foreach my $class(@{ $esom->class_table }) {
		next unless $class->index > 0;

		my $name    = $class->name;
		my $members = $class->members;
		my $size = @{ $members };
			
		print "[ $name $size ]\n";

		warn "Extracting matrix view\n";
		my $matrix = $esom->weights->data->view_selection( $members, undef );
		warn "Done\n";

		my $mh = Anorman::Data::Algorithms::MahalanobisDistance->new( $matrix );
	
		$mhdist{ $class->index } = $mh;	
	}

	my $self = { 'esom' => $esom, 'mhdist' => \%mhdist };

	bless ($self, $class);

	print Dumper $self->{'mhdist'};exit;
	return $self;

}

sub apply {

}

sub quick_apply {

}

sub test_bestmatches {

}

1;

