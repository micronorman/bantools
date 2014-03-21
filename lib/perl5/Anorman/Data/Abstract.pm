package Anorman::Data::Abstract;

use strict;
use warnings;

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


sub _elements   {  $_[0]->{'_ELEMS'} }
sub _is_view    {  $_[0]->{'_VIEW'}  }
sub _is_no_view { !$_[0]->{'_VIEW'}  }

sub clone {
	my $self  = shift;
	my $class = ref $self;

	my $clone = {};
	%{ $clone } = %{ $self };
	bless ( $clone, $class );

	$clone->{'_VIEW'} = 1;

	return $clone;
}

sub copy {
	my $self = shift;
	my $copy = $self->like;

	$copy->assign( $self );

	return $copy;
}

1;

