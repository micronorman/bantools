package Anorman::Math::DistanceFactory;

use Anorman::Common;

my %SPACES = (
	'manhattan' => 1,
	'euclidean' => 1
);

sub get_function {
	my $class    = shift;
	my %user_opt = @_;

	my %opt = (
		'PACKED'    => 1,
		'THRESHOLD' => 0,
		'SPACE'     => 'euclidean',
	);

	@opt{ keys %user_opt } = values %user_opt;
	
	while (my ($setting, $value) = each %opt) {
		$class->_error("Unkown option $opt") if !exists $opt{ $setting };
		
		if ( $setting eq 'SPACE' ) {
			trace_error("Unkown Geometry $value") if !exists $SPACES{ $value };
			$self->{'SPACE'} = $value;
		} elsif ( $value != 1 && $value != 0 ) {
			trace_error("Boolean option $setting can only contain value 0 or 1");
			$opt{ $setting } = $value ? 1 : undef;
		}
	}

	if ( $opt{THRESHOLD} ) {
		return Anorman::Math::Distance::ThresholdFunction->new( %opt );
	} else {
		return  Anorman::Math::Distance::Function->new( %opt );
	} 
}	

1;

package Anorman::Math::Distance::Function;

use strict;

use Anorman::Data::LinAlg::Property qw( :vector );
use Anorman::Data::Functions::VectorVector;
use Anorman::Common;

our $PACKED;
our $SPACE;

my %FUNC_OK = (
	'euclidean' => \&Anorman::Data::Functions::VectorVector::vv_dist_euclidean,
	'manhattan' => \&Anorman::Data::Functions::VectorVector::vv_dist_manhattan
              );

sub new {
	my $class  = shift;
	my %opt    = @_;
	$PACKED = $opt{PACKED};
	$SPACE  = $opt{SPACE};

	exists $FUNC_OK{ $opt{SPACE} }|| trace_error("No such distance function $opt{SPACE}");
	
	return bless ( $FUNC_OK{ $opt{SPACE} } , $class );
}


sub apply {
	# Distance functions require two packed vectors
	my $self    = shift;
	my ($u, $v) = @_;

	trace_error("Both arguments must be vectors") if (!is_vector($u) || !is_vector($v));

	if ($PACKED) {
		# packed any unpacked vectors
		if (is_packed($u) && is_packed($v)) {
			return $self->( $u, $v );
		} elsif (is_packed($u)) {
			$v = $v->packed_copy; 
		} elsif(is_packed($v)) {
			$u = $u->packed_copy;
		} else {
			$u = $u->packed_copy;
			$v = $v->packed_copy;
		}
	}

	return $self->( $u, $v );
}

sub apply_quick {
	# skip all checks and assume that vectors are packed
	return $_[0]->($_[1],$_[2]);
}

sub function {
	my $self = shift;
	return sub { &{ $self } };
}

sub space {
	my $class = ref($_[0]);
	return $SPACE;
}

1;

package Anorman::Math::Distance::ThresholdFunction;

use strict;

use Anorman::Data::LinAlg::Property qw( :vector );
use Anorman::Data::Functions::VectorVector;
use Anorman::Common;
use POSIX qw( :float_h );

our $PACKED;
our $SPACE;
our $THRESHOLD = DBL_MAX;

my %FUNC_OK = (
	'euclidean' => \&Anorman::Data::Functions::VectorVector::vv_dist_euclidean_upto,
	'manhattan' => \&Anorman::Data::Functions::VectorVector::vv_dist_manhattan_upto
              );

sub new {
	my $class  = shift;
	my %opt    = @_;

	$PACKED = $opt{PACKED};
	$SPACE  = $opt{SPACE};

	exists $FUNC_OK{ $opt{SPACE} }|| trace_error("No such distance function $opt{SPACE}");
	
	return bless ( $FUNC_OK{ $opt{SPACE} } , $class );
}


sub apply {
	# Distance functions require two packed vectors
	my $self    = shift;
	my ($u, $v) = @_;

	trace_error("Both arguments must be vectors") if (!is_vector($u) || !is_vector($v));

	if ($PACKED) {
		# packed any unpacked vectors
		if (is_packed($u) && is_packed($v)) {
			return $self->( $u, $v );
		} elsif (is_packed($u)) {
			$v = $v->packed_copy; 
		} elsif(is_packed($v)) {
			$u = $u->packed_copy;
		} else {
			$u = $u->packed_copy;
			$v = $v->packed_copy;
		}
	} 	

	return $self->( $u, $v, $THRESHOLD );
}

sub function {
	my $self = shift;
	return sub { &{ $self } };
}

sub space {
	my $class = ref($_[0]);
	return $SPACE;
}

sub threshold {
	my $class = ref($_[0]);
	
	if (defined $_[1]) {
		$THRESHOLD = $_[1];
	} else {
		return $THRESHOLD;
	}
}

1;
