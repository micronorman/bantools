package Anorman::Data::Vector::SelectedDense;

use parent 'Anorman::Data::Vector';

sub new {
	my $class = ref ($_[0]) ? ref shift : shift;

	if (@_ != 2 && @_ != 6) {
		$class->_error("Wrong number of arguments");
	}
	
	my ( 
             $size,
	     $elems,
             $zero,
             $stride,
             $offsets,
	     $offset
           );
	
	my $self = $class->SUPER::new();
	if (@_ == 2) {
		$zero      = 0;
		$stride    = 1;
		
		($size,
		 $elems,
		 $offsets,
		 $offset ) = ( scalar @{ $_[1] }, $_[0], $_[1], 0 ); 
	} else {
		($size,
                 $elems,
                 $zero,
                 $stride,
                 $offsets,
                 $offset) = @_;
	}		

	$self->_setup( $size, $zero, $stride );

	$self->{'_ELEMS'}  = $elems;
	$self->{'offsets'} = $offsets;
	$self->{'offset'}  = $offset;
	$self->{'_VIEW'}   = 1;

	return $self;
}

sub _offset {
	my $self = shift;
	return $self->{'offsets'}->[ $_[0] ];
}

sub _index {
	my $s = shift;
	return $s->{'offset'} + $s->{'offsets'}->[ $s->{'0'} + $_[0] * $s->{'stride'} ]; 
}

sub _have_shared_cells_raw {
	return ($_[0]->{'_ELEMS'} eq $_[1]->{'_ELEMS'});

}

sub _setup {
	my $self = shift;

	if (@_ == 1) {
		$self->SUPER::_setup( $_[0] );
		$self->{'stride'} = 1;
		$self->{'offset'} = 0;
	} else {
		$self->SUPER::_setup(@_);
	}
}

sub get_quick {
	my $s = shift;
	return $s->{'_ELEMS'}->[ $s->{'offset'} + $s->{'offsets'}->[ $s->{'0'} + $_[0] * $s->{'stride'} ] ];
}

sub set_quick {
	my $s = shift;
	$s->{'_ELEMS'}->[ $s->{'offset'} + $s->{'offsets'}->[ $s->{'0'} + $_[0] * $s->{'stride'} ] ] = $_[1];
}

sub _view_selection_like {
	my $self = shift;
	return $self->new($self->{'_ELEMS'}, $_[0] );
}

1;
