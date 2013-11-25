package Anorman::ESOM::Neighborhood;

use strict;
use Anorman::Common qw(trace_error);

sub new {
	my $class = shift;
	my ($radius, $scaling) = @_;

	my $self = bless ( {} , ref $class || $class);

	$self->scaling( $scaling );
	$self->radius( $radius );

	return $self;
}

sub scaling {
	my $self = shift;
	return $self->{'_scaling'} unless defined $_[0];
	$self->{'_scaling'} = shift;
}

sub radius {
	my $self = shift;
	return $self->{'_radius'} unless $_[0];
	$self->{'_radius'} = shift;
}

sub get {
	my $self = shift;
	my $dist = shift;

	$self->_error("Distance can't be negative!") if ($dist < 0);

	return $dist <= $self->{'_radius'} ? $self->{'_scaling'} * $self->_caclulate( $dist ) : 0.0;
}

sub get_unscaled {
	my $self = shift;
	my $dist = shift;

	$self->_error("Distance can't be negative!") if ($dist < 0);

	return $dist <= $self->{'_radius'} ? $self->_caclulate( $dist ) : 0.0;
}


sub _error {
	shift;
	trace_error(@_);
}

1;

package Anorman::ESOM::Neighborhood::Cache;

use parent -norequire,'Anorman::ESOM::Neighborhood';
use Anorman::Data::Vector::DensePacked;

sub new { return shift->SUPER::new(@_) };

sub init {
	my $self = shift;
	my $dist = shift;
	my $size = $#{ $dist } + 1;
	$self->{'_weights'} = Anorman::Data::Vector::DensePacked->new( $size );

	my $i = -1;

	while (++$i < $size) {
		$self->{'_weights'}->set_quick( $i, $self->{'_scaling'} * $self->_calculate( $dist->[ $i ] ) );	
	}
}

sub get {
	my $self = shift;
	return $self->{'_weights'};

	#$self->_error("Distance from center can't be negative!") if ($dist < 0);
	
	#if ($dist <= $self->{'_radius'}) {
	#	return $self->{'_weights'}->[ $dist ] if ($dist <= $self->{'_radius'});
	#} else {
	#	return 0.0;
	#}
}

1;

package Anorman::ESOM::Neighborhood::Gaussian;

use parent -norequire,'Anorman::ESOM::Neighborhood::Cache';

sub new {
	my $class   = shift;
	my $radius  = shift;
	my $scaling = shift;
	my $self   = $class->SUPER::new($radius, $scaling);

	$self->{'_stddevs'} = defined $_[0] ? shift : 2;


	$self->init if ($radius && $scaling);

	return $self;
}

sub init {
	my $self = shift;
	$self->{'_norm'} = ( 2 * ($self->{'_radius'} + 1)**2) / ($self->{'_stddevs'}**2);
	$self->SUPER::init( shift );
}

# calculate scaling factor based on distance from center
sub _calculate {
	my $self = shift;
	return exp(( -$_[0] * $_[0]) / $self->{'_norm'});
}
1;

package Anorman::ESOM::Neighborhood::MexicanHat;

use parent -norequire,'Anorman::ESOM::Neighborhood::Cache';

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	$self->init;

	return $self;
}

sub init {
	my $self = shift;
	$self->{'_norm'} = 3.0 / ($self->{'_radius'} + 1);
	$self->SUPER::init( shift );
}

sub _calculate {
	my $self = shift;
	my $square = ( $_[0] * $self->{'_norm'} )**2;

	return ( 1.0 - $square) * exp( -$square );
}

1;

package Anorman::ESOM::Neighborhood::Cone;

use parent -norequire,'Anorman::ESOM::Neighborhood::Cache';

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	$self->SUPER::init;

	return $self;
}

sub init {
	my $self = shift;
	$self->SUPER::init( shift );
}

sub _calculate {
	my $self = shift;
	
	return (( $self->{'_radius'} + 1) - $_[0]) / ($self->{'_radius'} + 1);
}

1;

package Anorman::ESOM::Neighborhood::Epanechnikov;

use parent -norequire,'Anorman::ESOM::Neighborhood::Cache';

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	$self->init;

	return $self;
}

sub init {
	my $self = shift;
	$self->{'_norm'} = ($self->{'_radius'} + 1) * ($self->{'_radius'} + 1);
	$self->SUPER::init( shift );
	
}

sub _calculate {
	my $self = shift;

	return 1.0 - (($_[0] * $_[0]) / $self->{'_norm'});
}

1;

package Anorman::ESOM::Neighborhood::Bubble;

use parent -norequire,'Anorman::ESOM::Neighborhood::Cache';

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);

	return $self;
}

sub init {
	my $self = shift;
	$self->SUPER::init( shift );
}

sub _calculate {
	return 1.0;
}

1;
