package Anorman::Data::Vector::Abstract;

use parent 'Anorman::Data::Abstract';

use Anorman::Common;
use Anorman::Data::Config qw($MAX_ELEMENTS);

sub new {
	my $class = ref $_[0] || $_[0];
	my $self  = $class->SUPER::new();

	@{ $self }{ qw(size zero stride) } = (0) x 3;

	return $self;
}

# Universal object accesors
sub _elements  {  $_[0]->{'_ELEMS'} }
sub _is_view   {  $_[0]->{'_VIEW'}  }
sub _is_noview { !$_[0]->{'_VIEW'}  }

# basic vector object accesors
sub size    { $_[0]->{'size'}   };
sub _zero   { $_[0]->{'zero'}   };
sub _stride { $_[0]->{'stride'} };

# derived vector properties
sub _offset { $_[1] };
sub _rank   { $_[0]->{'zero'} + $_[1] * $_[0]->{'stride'} };
sub _index  { $_[0]->_offset( $_[0]->_rank($_[1])) }

sub _setup {
	my $self = shift;

	my ($size, $zero, $stride) = @_;

	if (@_ == 1) {
		$zero   = 0;
		$stride = 1;
	}

	$self->{'size'}   = $size;
	$self->{'zero'}   = $zero;
	$self->{'stride'} = $stride;

	trace_error("Vector is too large") if $size > $MAX_ELEMENTS;
}
 
sub _check_index {
	if ($_[1] >= $_[0]->{'size'}) {
		trace_error("Index $_[1] out of bounds");
	}
}

sub _check_range {
	if ($_[1] < 0 || $_[1] +  $_[2] > $_[0]->{'size'}) {
		my $size = $self->{'size'};
		trace_error("Index range out of bounds. Index: $_[1], Width: $_[2], Size: $size");
	}
}

sub _v_part {
	my $self = shift;

	$self->_check_range(@_);

	$self->{'zero'} += $self->{'stride'} * $_[0];
	$self->{'size'}  = $_[1];

	return $self;
}

1;


