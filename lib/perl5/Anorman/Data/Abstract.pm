package Anorman::Data::Abstract;

use strict;
use warnings;

use Anorman::Common;

use overload
	'""'  => '_to_string',
	'@{}' => '_to_array',
	'-'   => '_sub',
	'+'   => '_add',
	'*'   => '_mul',
	'/'   => '_div',
	'-='  => '_sub_assign',
	'+='  => '_add_assign',
	'*='  => '_mul_assign',
	'/='  => '_div_assign',
	'=='  => 'equals';

*_view = \&clone;

sub new {
	my $class = ref $_[0] || $_[0];
	
	return bless ( { _VIEW => 0 }, $class );
}

sub clone {
	my $self  = shift;
	my $clone = $self->_clone_self;

	$clone->_set_view(1);

	return $clone;
}

sub copy {
	my $self = shift;
	my $copy = $self->like;

	$copy->assign( $self );

	return $copy;
}

sub _clone_self {
	my $class = ref $_[0];
	my $clone = {};

	%{ $clone } = %{ $_[0] };
	
	return bless ( $clone, $class );
}


sub _set_view  { $_[0]->{'_VIEW'} = 1 }

# Overloaded operations
sub _sub { my $r = $_[0]->copy; $r->_sub_assign($_[1],$_[2]);$r }
sub _add { my $r = $_[0]->copy; $r->_add_assign($_[1],$_[2]);$r }
sub _mul { my $r = $_[0]->copy; $r->_mul_assign($_[1],$_[2]);$r }
sub _div { my $r = $_[0]->copy; $r->_div_assign($_[1],$_[2]);$r }

# Dummies. Must be overwritten
sub _add_assign {...}
sub _sub_assign {...}
sub _mul_assign {...}
sub _div_assign {...}

1;

