package Anorman::ESOM::Cooling;

use strict;
use Anorman::Common;
use POSIX qw/ceil/;

sub new {
	my $class = shift;
	my $self  = bless ( {}, $class || ref( $class ) );

	if (@_ == 3) {
		@{ $self }{ qw/_start _steps _end/ } = ( @_ );
	} elsif (@_ == 0) {
		@{ $self }{ qw/_start _steps _end/ } = (1.0,100,0.0);
	} else {
		$self->_error("Usage: " . __PACKAGE__ . "::new( start, steps, end )");
	}

	return $self;
}

sub get {
	my $self = shift;
	my $step = shift;

	return $self->{'_start'} if $step <= 0;
	return $self->{'_end'} if $step >= ($self->{'_steps'} - 1);
	return $self->_calculate( $step );
}

sub get_as_int {
	my $self = shift;
	my $step = shift;

	return ceil( $self->get( $step ) );
}
sub _error {
	shift;
	trace_error(@_);
}

1;

package Anorman::ESOM::Cooling::Cache;

use parent -norequire,'Anorman::ESOM::Cooling';

sub new { 
	my $class = shift;
	my $self  = $class->SUPER::new( shift, shift, shift );
	my $size  = defined $_[ 0 ] ? shift : $self->{'_steps'} - 1;
	
	if ($size > 0) {
		$self->{'_cache'} = [];
		$self->{'_size'}  = $size;
	};

	return $self;
}

sub _init {
	my $self = shift;
	$self->_fill_cache(1);
}

sub _fill_cache {
	my $self           = shift;
	$self->{'_offset'} = shift;

	if (exists $self->{'_cache'}) {
		@{ $self->{'_cache'} } = 
			map { $self->_calculate( $self->{'_offset'} + $_ ) } (0..$self->{'_size'} - 1);
	}
}

sub get {
	my $self = shift;
	my $step = shift;
	
	return $self->{'_start'} if $step <= 0;
	return $self->{'_end'}   if ($step >= ($self->{'_steps'} - 1));

	if ( ($self->{'_offset'} <= $step) && ($step <= ($self->{'_offset'} + $self->{'_size'})) ) {
		return $self->{'_cache'}->[ $step - $self->{'_offset'} ];
	} else {
		$self->_fill_cache( $step );
		return $self->{'_cache'}->[ 0 ];
	}
}

1;

package Anorman::ESOM::Cooling::Linear;

use strict;
use parent -norequire,'Anorman::ESOM::Cooling::Cache';

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	$self->_init;

	return $self;
}

sub _init {
	my $self = shift;
	$self->{'_diff'} = ($self->{'_start'} - $self->{'_end'}) / $self->{'_steps'};
	$self->SUPER::_init;
}
sub _calculate {
	my $self = shift;
	my $step = shift;

	return $self->{'_start'} - ($step * $self->{'_diff'});
}

package Anorman::ESOM::Cooling::Exponential;

use strict;

use parent -norequire,'Anorman::ESOM::Cooling::Cache';

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);
	$self->_init;

	return $self;
}

sub _init {
	my $self = shift;
	my $end  = $self->{'_end'} == 0 ? 0.1 : $self->{'_end'};

	$self->{'_diff'} = -log( $end / $self->{'_start'} ) / $self->{'_steps'};
	$self->SUPER::_init;
}

sub _calculate {
	my $self = shift;
	my $step = shift;

	return $self->{'_start'} * exp( -$step * $self->{'_diff'} );
}

1;
