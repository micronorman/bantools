package Anorman::Data::Vector;

use strict;

use Anorman::Common qw(sniff_scalar trace_error);
use Scalar::Util qw(blessed looks_like_number refaddr);
use Anorman::Data::LinAlg::Property qw( :vector );
use Anorman::Data::Vector::Dense;
use Anorman::Data::Vector::DensePacked;

use parent 'Anorman::Data';

BEGIN {
	require 5.006;
}

use overload
	'""'  => \&_to_string,
	'=='  => \&equals,
	'@{}' => \&_to_array,
	'+'   => \&_add,
	'+='  => \&_add_assign;

my %ASSIGN_DISPATCH = (
	'NUMBER'      => \&_assign_Vector_from_NUMBER,
	'ARRAY'       => \&_assign_Vector_from_ARRAY,
	'OBJECT'      => \&_assign_Vector_from_OBJECT,
	'OBJECT+CODE' => \&_assign_Vector_from_OBJECT_and_CODE,
	'CODE'        => \&_assign_Vector_from_CODE
);

# constructor (dummy)
sub new {
	my $class = ref $_[0] || $_[0];
	my $self  = {
	    'size'   => 0,
            '0'      => 0,
            'stride' => 0,
            '_ELEMS' => [],
            '_VIEW'  => undef
	};

	return bless ( $self, $class );
}

# accessors
sub size {
	return $_[0]->{'size'};
}

sub stride {
	return $_[0]->{'stride'};
}

sub zero {
	return $_[0]->{'0'};
}

sub elements {
	return $_[0]->{'_ELEMS'};
}

sub is_noview {
	return (!defined $_[0]->{'_VIEW'});
}

# general element retrieval
sub get {
	my $self = shift;
	$self->_check_index( $_[0] );
	return $self->get_quick( $_[0] );
}

sub set {
	my $self = shift;
	$self->_check_index( $_[0] );
	return $self->set_quick( $_[0], $_[1] );
}

sub aggregate {
	my $self = shift;

	my ($aggr,$f) = @_;

	my $i = $self->size - 1;
	my $a = $f->( $self->get_quick( $i ) );

	while ( --$i >= 0 ) {
		$a = $aggr->( $a, $f->( $self->get_quick($i) ) );
	}

	return $a;
}

# return copy of identical type
sub copy {
	my $self = shift;
	my $copy = $self->like;
	$copy->assign( $self );
	return $copy;
}

sub pack {
	my $self = shift;
	return $self->copy if is_packed($self);
	my $copy = Anorman::Data::Vector::DensePacked->new( $self->size );

	$copy->assign( $self );
	return $copy;
}

sub unpack {
	my $self = shift;
	return $self->copy if !is_packed($self);
	my $copy = Anorman::Data::Vector::Dense->new( $self->size );

	$copy->assign( $self );
	return $copy;
}

sub _view {
	my $self = shift;
	return $self->clone;
}

sub view_part {
	my $self = shift;
	return $self->_view->_v_part(@_);
}

sub assign {
	my ($self,$type) = ($_[0], sniff_scalar($_[1]));
	$ASSIGN_DISPATCH{ $type }->(@_); 
}

sub _assign_Vector_from_NUMBER {
	my ($self, $value) = @_;
	my $i = $self->size;
	while ( --$i >= 0 ) {
		$self->set_quick($i, $value);
	}
	1;
}

sub _assign_Vector_from_ARRAY {
	my ($self, $values) = @_;

	trace_error("Must have same number of cells") if (@{ $values } != $self->size);

	my $i = $self->size;
	while ( --$i >= 0 ) {
		$self->set_quick( $i, $values->[ $i ] );
	}	
	1;
}

sub _assign_Vector_from_OBJECT {
	my ($self, $other) = @_;
	return if ($self == $other);

	$self->_check_size($other);

	$other = $other->copy if ($self->_have_shared_cells($other));

	my $i = $self->size;

	while ( --$i >= 0) {
		$self->set_quick( $i, $other->get_quick($i));
	}
	1;
}

sub _assign_Vector_from_OBJECT_and_CODE {
	my ($self, $other, $function) = @_;

	$self->_check_size($other);
	
	my $i = $self->size;
	while ( --$i >= 0 ) {
		$self->set_quick($i, $function->($self->get_quick($i), $other->get_quick($i)));
	}
	1;
}

sub _assign_Vector_from_CODE {
	my ($self, $function) = @_;

	my $i = $self->size;
	while ( --$i >= 0 ) {
		$self->set_quick($i, $function->( $self->get_quick( $i )));
	}
	1;
}

sub _have_shared_cells {
	my ($self, $other) = @_;

	return 1 if (refaddr($self) == refaddr($other));
	return $self->_have_shared_cells_raw($other);
}

sub _have_shared_cells_raw {
	return undef;
}

sub equals {
	my $self = shift;

	if (is_vector($_[0])) {
		my $other = shift;

		# same adress?
		return 1 if (refaddr($other) == refaddr($self));

		# same dimensions?
		return vector_equals_vector( $self, $other );

	# will check if all values of the matrix equals a given value
	} else {
		my $value = shift;

		return vector_equals_value( $self, $value );
	}
}

sub swap {
	my ($self, $other) = @_;

	$self->_check_size($other);

	my $i = $self->size;
	while ( --$i >= 0 ) {
		my $tmp = $self->get_quick( $i );
		$self->set_quick( $i, $other->get_quick($i));
		$other->set_quick( $i, $tmp );
	}
}

sub dot_product {
	my $self = shift;
	my ($other, $from, $length) = @_;

	$from   = 0           if !defined $from;
	$length = $self->size if !defined $length;

	return 0 if ($from < 0 || $length <= 0);

	my $tail = $from + $length;

	$tail = $self->size  if ($self->size < $tail);
	$tail = $other->size if ($other->size < $tail);

	$length = $tail - $from;
	
	my $sum = 0;
	my $i   = $tail - 1;
	my $k   = $length;

	while ( --$k >= 0 ) {
		$sum += $self->get_quick( $i ) * $other->get_quick( $i );
		$i--;
	}

	return $sum;
}

sub sum {
	my $self = shift;
	return 0 if $self->size == 0;

	return $self->aggregate( sub { return $_[0] + $_[1] }, sub { shift } ); 
}

# (semi)private methods
sub _to_array {
	my $self   = shift;
	my $index  = $self->size;
	my $values = []; 

	while (--$index >= 0) {
		$values->[ $index ] = $self->get_quick( $index );
	}

	return $values;
}

sub _setup {
	my $self = shift;

	if (@_ != 1 && @_ != 3) {
		$self->_error("Wrong number of arguments\nUsage: " . __PACKAGE__ .
                "::_setup( size [, zero, stride ]");
	}

	my ($size, $zero, $stride) = @_;

	$self->{'_VIEW'} = 1;

	if (@_ == 1) {
		$zero   = 0;
		$stride = 1;
		$self->{'_VIEW'} = undef;
	}

	$self->{'size'}   = $size;
	$self->{'0'}      = $zero;
	$self->{'stride'} = $stride;
}

sub _to_string {
	my $self = shift;
	my $f    = $Anorman::Data::FORMAT;
	my $n    = $self->size;
	my $v;

	my $string = "{" .join(", ", map { defined ($v = $self->get_quick($_)) ? sprintf ( $f, $v ) : 'nan' } (0 .. $n -1)) . "}";

	return $string;
	#return "{" . join(",", map { $self->get_quick( $_ )|| 0 } (0 .. $self->size - 1)) . "}";
}

sub _to_short_string {
	my $self = shift;
	return "[ " . $self->size . " ]";
}

sub _check_index {
	if ($_[1] >= $_[0]->size) {
		my $self = shift;
		$self->_error("Index $_[0] out of bounds");
	}
}

sub _check_range {
	if ($_[1] < 0 || $_[1] +  $_[2] > $_[0]->size) {
		my $self = shift;
		my $size = $self->size;
		$self->_error("Index range out of bounds. Index: $_[0], Width: $_[1], Size: $size");
	}
}

sub _check_size {
	if ($_[0]->size != $_[1]->size) {
		my ($self, $other) = @_;
		$self->_error("Vectors have different sizes: (" . $self->size . " and " . $other->size . ")" );
	} 
}

sub _v_part {
	my $self = shift;

	$self->_check_range(@_);

	$self->{'0'}    += $self->{'stride'} * $_[0];
	$self->{'size'}  = $_[1];
	$self->{'_VIEW'} = 1;

	return $self;
}

sub _add {
	my ($v, $u, $rev_bit) = @_;
	
	# set up result vector
	my $r = $v->like;
	my $i = $v->size;

	# second argument is vector
	if (blessed $u) {

		while (--$i >= 0) {
			$r->set_quick( $i, $v->get_quick( $i ) + $u->get_quick( $i ) );	
		}

	# second argument is number
	} elsif (looks_like_number $u) {

		while (--$i >= 0) {
			$r->set_quick( $i, $v->get_quick( $i ) + $u );	
		}
	}

	return $r;
}

sub _add_assign {
	my ($v, $u, $rev_bit) = @_;
	my $i = $v->size;

	if (blessed $u) {
		while (--$i >= 0) {
			$v->set_quick( $i, $v->get_quick( $i ) + $u->get_quick( $i ) );	
		}
	} elsif (looks_like_number $u) {
		while (--$i >= 0) {
			$v->set_quick( $i, $v->get_quick( $i ) + $u );	
		}
	} else {
		$v->_error("Function was passed something illegal");
	}

	return $v;
}

sub _error {
	shift;
	trace_error(@_);
}


1;
