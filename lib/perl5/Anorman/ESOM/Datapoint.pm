package Anorman::ESOM::Datapoint;

use strict;
use warnings;

use Anorman::Common;

sub new {
	trace_error("Wrong number of arguments\nUsage: " . __PACKAGE__ . "::new( index, ESOM )") unless @_ == 3;

	my ($class, $index, $ESOM) = @_;
	my $self = [ $ESOM, $index ];

	return bless ( $self, ref $class || $class );
}

sub class {
	my ($esom, $index, $class) = (@{ $_[0] }, $_[1]);

	my $cls = $esom->_cls;
	my $key = $esom->_keys->[ $index ];

	print "KEY: $key\n";

	unless (defined $class) {
		$esom->_check_formats( 'cls' );
		return $cls->get( $cls->key2pos( $key ) ) || 0;
	} else {
		$cls->set( $cls->key2pos( $key ), $class );	
	} 
}

sub bestmatch {
	my ($esom,$index) = @{ $_[0] };

	$esom->_check_formats('bm');
	return $esom->_bm->get( $index );
}

sub umatrix_height {

}

sub key {
	my $self = shift;
	return $self->[0]->_keys->[ $self->[1] ];
}

sub name {
	my $self = shift;
	$self->[0]->_check_formats('names');
	return $self->[0]->_names->get( $self->[1] );
}

sub pattern {
	my $self = shift;
	$self->[0]->_check_formats('lrn');
	return $self->[0]->_lrn->data->view_row( $self->[1] );
}

sub index {
	return $_[0]->[1];
}

1;
