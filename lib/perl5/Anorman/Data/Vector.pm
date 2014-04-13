package Anorman::Data::Vector;

use strict;
use warnings;

use Anorman::Common qw(sniff_scalar trace_error);
use Anorman::Data::Config qw( :string_rules );
use Anorman::Data::LinAlg::Property qw( :vector );
use Anorman::Math::Functions;
use Anorman::Math::VectorFunctions;

use Scalar::Util qw(blessed looks_like_number refaddr);

my %ASSIGN_DISPATCH = (
	'NUMBER'      => \&_assign_Vector_from_NUMBER,
	'ARRAY'       => \&_assign_Vector_from_ARRAY,
	'OBJECT'      => \&_assign_Vector_from_OBJECT,
	'OBJECT+CODE' => \&_assign_Vector_from_OBJECT_and_CODE,
	'CODE'        => \&_assign_Vector_from_CODE
);

# Universal matrix get/set commands. Performs sanity check on indexes

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

	$self->aggregate( $_[0], Anorman::Math::Functions::identity ) if @_ == 1;

	my $a;

	if (@_ == 2) {
		my ($aggr,$f) = @_;

		my $i = $self->size - 1;
		
		$a = $f->( $self->get_quick( $i ) );

		while ( --$i >= 0 ) {
			$a = $aggr->( $a, $f->( $self->get_quick($i) ) );
		}
	} elsif (@_ == 3) {
		my ($other, $aggr, $f) = @_;
		
		$self->_check_size($other);
		
		my $i = $self->size - 1;
		
		$a = $f->( $self->get_quick( $i ), $other->get_quick( $i ) );

		while ( --$i >= 0 ) {
			$a = $aggr->( $a, $f->( $self->get_quick($i), $other->get_quick($i) ) );
		}
	}
		
	return $a;
}

sub aggregate_upto {
	my ($self, $other, $aggr, $f, $th) = @_;
	$self->_check_size($other);

	return undef if ($self->size == 0);

	my $i = 0;
	my $a = $f->( $self->get_quick( $i ), $other->get_quick( $i ) );

	while( $a <= $th && ++$i < $self->size ) {
		$a = $aggr->( $a, $f->( $self->get_quick( $i ), $other->get_quick( $i ) ) );
	}

	return $a;
}

sub normalize {
	my $self = shift;
	my $F = Anorman::Math::Functions->new();
	my $max = $self->aggregate($F->max, $F->identity);
	my $min = $self->aggregate($F->min, $F->identity);

	return if ($max == 1 && $min == 0);

	$self->assign( $F->minus($min) );
	$self->assign( $F->div($max-$min));
}

sub ztrans {
	my $self = shift;

	my $F  = Anorman::Math::Functions->new;
	my $VF = Anorman::Math::VectorFunctions->new;

	my $mean = $VF->mean->( $self );
	my $std  = $VF->stdev->( $self );

	$self->assign( $F->minus( $mean ) );
	$self->assign( $F->div( $std ) );
}

sub rztrans {
	my $self = shift;

	my $F  = Anorman::Math::Functions->new;
	my $VF = Anorman::Math::VectorFunctions->new();

	my $mean = $VF->robust_mean->( $self );
	my $std  = $VF->robust_stdev->( $self );

	$self->assign( $F->minus( $mean ) );
	$self->assign( $F->div( $std ) );
}

sub view_part {
	my $self = shift;
	return $self->_view->_v_part(@_);
}

sub view_selection {
	my $self    = shift;
	my $indexes = shift;

	if (!defined $indexes) {
		$indexes = [ 0 .. $self->size - 1 ];
	}

	my $offsets = [ map { $self->_index($_) } @{ $indexes } ];

	return $self->_view_selection_like( $offsets );
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

	$tail =  $self->size if ( $self->size < $tail);
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

	return $self->aggregate( Anorman::Math::Functions::plus, Anorman::Math::Functions::identity ); 
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

sub _to_string {
	my $self   = shift;
	my $n      = $self->size;
	my $string = '';

	$string .= $VECTOR_ENDS->[0];
	$string .= join($VECTOR_SEPARATOR, map { sprintf( $FORMAT, $_ ) } @{ $self });
	$string .= $VECTOR_ENDS->[1];

	return $string;
}

sub _to_short_string {
	my $self = shift;
	return "[ " . $self->size . " ]";
}

sub _check_size {
	if ($_[0]->size != $_[1]->size) {
		my ($self, $other) = @_;
		$self->_error("Vectors have different sizes: (" . $self->size . " and " . $other->size . ")" );
	} 
}

1;
