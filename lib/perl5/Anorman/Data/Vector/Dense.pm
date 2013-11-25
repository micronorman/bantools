package Anorman::Data::Vector::Dense;

use strict;

use parent 'Anorman::Data::Vector';

use Anorman::Data::LinAlg::Property qw( :vector );
use Anorman::Common qw(sniff_scalar trace_error);

my %ASSIGN_DISPATCH = (
	'NUMBER'      => \&_assign_DenseVector_from_NUMBER,
	'ARRAY'       => \&_assign_DenseVector_from_ARRAY,
	'OBJECT'      => \&_assign_DenseVector_from_OBJECT,
	'OBJECT+CODE' => \&_assign_DenseVector_from_OBJECT_and_CODE,	
	'CODE'        => \&_assign_DenseVector_from_CODE
);

sub new {
	my $class = ref ($_[0]) ? ref shift : shift;

	if (@_ != 1 && @_ != 4) {
		$class->_error("Wrong number of arguments");
	}

	my ($size, $zero, $stride);
	my $self = $class->SUPER::new();

	if (@_ == 1) {
		if (ref ($_[0]) eq 'ARRAY') {
			$size    = @{ $_[0] };

			$self->_setup( $size );
			$self->assign( $_[0] );
		} else {
			$self->_setup( $_[0] );
			$self->{'_ELEMS'}->[ $_[0] - 1 ] = undef;
		}
	} else {
		my $other;
		($size, $other, $zero, $stride) = @_;
		$self->_setup( $size, $zero, $stride );
		$self->{'_ELEMS'} = $other->{'_ELEMS'};
	}

	return $self;
}

sub assign {
	my $self = shift;
	my $type = sniff_scalar($_[0]);

	# determine type of data passed
	if (@_ == 2) {
		my $arg2_type = sniff_scalar( $_[1] );
		unless ($type eq 'OBJECT' && $arg2_type eq 'CODE') {
			$self->_error("Invalid arguments. Argument 2 is not a CODE block ($type,$arg2_type)");
		}
		$type = 'OBJECT+CODE';
	}

	# execute from dispatch table
	$ASSIGN_DISPATCH{ $type }->( $self, @_ );

	return $self;
}

sub swap {
	my ($self, $other) = @_;
	
	check_vector( $other );
	return if ($self == $other);
	$self->_check_size( $other );

	$self->SUPER::swap( $other ) if ref $other ne 'Anorman::Data::Vector::Dense';

	# optimized element swapping
	my $A_elems = $self->{'_ELEMS'};
	my $B_elems = $other->{'_ELEMS'};
	my $A_str   = $self->stride;
	my $B_str   = $other->stride;
		
	my $i = $self->_index( 0 );
	my $j = $other->_index( 0 );

	my $k = $self->size;

	while (--$k >= 0) {
		($A_elems->[ $i ], $B_elems->[ $j ]) = ( $B_elems->[ $j ], $A_elems->[ $i ]);
		$i += $A_str;
		$j += $B_str;
	}

	1;
}

sub get_quick {
	my $self  = shift;

	return $self->{'_ELEMS'}->[ $self->{'0'} + $_[0] * $self->{'stride'} ];
}

sub set_quick {
	my $self  = shift;

	$self->{'_ELEMS'}->[ $self->{'0'} + $_[0] * $self->{'stride'} ] = $_[1];
}

sub like {
	my $self  = shift;
	return defined $_[0] ? $self->new( $_[0] ) : $self->new( $self->size );
}

sub dot_product {
	my ($self,$other, $from, $length) = @_;

	check_vector($other);

	if (ref $other ne 'Anorman::Data::Vector::Dense') {
		return $self->SUPER::dot_product($other, $from, $length);
	}

	$from = 0 if !defined $from;
	$length = $self->size if !defined $length;

	my $tail = $from + $length;
	return 0 if ($from < 0 || $length <= 0);

	my $size = $self->size;

	$tail = $size if ($size < $tail);
	$tail = $other->size if ($other->size < $tail);

	my $min = $tail - $from;
	
	my $i = $self->_index($from);
	my $j = $other->_index($from);

	my $a_str = $self->stride;
	my $b_str = $other->stride;

	my $a_elems = $self->{'_ELEMS'};
	my $b_elems = $other->{'_ELEMS'};

	my $sum = 0;

	# unrolled loop optimization
	$i -= $a_str;
	$j -= $b_str;

	my $k = $min / 4;
	while ( --$k >= 0) {
		$sum += $a_elems->[ $i += $a_str ] * $b_elems->[ $j += $b_str ];
                $sum += $a_elems->[ $i += $a_str ] * $b_elems->[ $j += $b_str ];
                $sum += $a_elems->[ $i += $a_str ] * $b_elems->[ $j += $b_str ];
                $sum += $a_elems->[ $i += $a_str ] * $b_elems->[ $j += $b_str ];
	}

	$k = $min % 4;
	while ( --$k >= 0) {
		$sum +=  $a_elems->[ $i += $a_str ] * $b_elems->[ $j += $b_str ]; 
	}	

	return $sum;
}


sub sum {
	my $self = shift;
	
	my $sum = 0;
	
	my $s = $self->stride;
	my $i = $self->_index(0);

	my $elems = $self->{'_ELEMS'};
	my $k = $self->size;
	while ( --$k >= 0 ) {
		$sum += $elems->[ $i ];
		$i += $s;
	}
	return $sum;
}

sub _index {
	my $self = shift;
	my $rank = shift;
	return $self->{'0'} + $rank * $self->{'stride'};
}

sub _assign_DenseVector_from_ARRAY {
	my ($self,$V) = @_;

	if ($self->is_noview) {
		$self->_error("Cannot assign values to vector object. Must have " . $self->size . " elements but has " . @{ $V })
			if (@{ $V } != $self->size);
		# direct array copy
		@{ $self->{'_ELEMS'} } = @{ $V };
	} else {
		$self->SUPER::_assign_Vector_from_ARRAY( $V );		
	}
	1;
}

sub _assign_DenseVector_from_OBJECT {
	my ($self,$other) = @_;

	if (ref $other ne 'Anorman::Data::Vector::Dense') {
		return $self->SUPER::_assign_Vector_from_OBJECT( $other );	
	}
	
	return 1 if ($self == $other);

	$self->_check_size( $other );

	# optimized element copying
	if ($self->is_noview && $other->is_noview) {
		@{ $self->{'_ELEMS'} } = @{ $other->{'_ELEMS'} };	
	}

	my $A_elems = $self->{'_ELEMS'};
	my $B_elems = $other->{'_ELEMS'};
	my $A_str   = $self->stride;
	my $B_str   = $other->stride;
		
	my $i = $self->_index( 0 );
	my $j = $other->_index( 0 );

	my $k = $self->size;

	while (--$k >= 0) {
		$A_elems->[ $i ] = $B_elems->[ $j ];
		$i += $A_str;
		$j += $B_str;
	}

	1;
}

sub _assign_DenseVector_from_OBJECT_and_CODE {
	my ($self, $other, $CODE) = @_;
	
	if (ref ($other) ne 'Anorman::Data::Vector::Dense') {
		return $self->SUPER::_assign_Vector_from_OBJECT_and_CODE( $other, $CODE );
	}

	$self->_check_size( $other );

	my $A_elems   = $self->{'_ELEMS'};
	my $B_elems   = $other->{'_ELEMS'};
	my $A_stride = $self->{'stride'};
	my $B_stride = $other->{'stride'};

	my $i   = $self->_index(0);
	my $j   = $other->_index(0);
	
	my $k = $self->{'size'};
	while ( --$k >= 0) {
		$A_elems->[ $i ] = $CODE->( $A_elems->[ $i ], $B_elems->[ $j ] );
		$i += $A_stride;
		$j += $B_stride;
	}

	1;
}

sub _assign_DenseVector_from_NUMBER {
	my ($self, $value) = @_;

	my $elems  = $self->{'_ELEMS'};
	my $i      = $self->_index(0);
	my $stride = $self->{'stride'};

	my $k = $self->{'size'};

	while ( --$k >= 0) {
		$elems->[ $i ] = $value;
		$i += $stride;
	}

	1;
}

sub _assign_DenseVector_from_CODE {
	my ($self, $CODE) = @_;

	my $elems  = $self->{'_ELEMS'};
	my $i      = $self->_index(0);
	my $stride = $self->{'stride'};

	my $k = $self->{'size'};

	while ( --$k >= 0 ) {
		$elems->[ $i ] = $CODE->( $elems->[ $i ] );
		$i += $stride;
	}

	1;
}

sub _have_shared_cells_raw {
	my ($self, $other) = @_;

	if (ref $other eq 'Anorman::Data::Vector::Dense' or ref $other eq 'Anorman::Data::Vector::SelectedDense') {
		return ($self->{'_ELEMS'} == $other->{'_ELEMS'})
	}
	return undef;	
}

1;

