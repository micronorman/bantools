package Anorman::Data::Matrix::SelectedDense;

use parent 'Anorman::Data::Matrix';

use Anorman::Data::Vector::SelectedDense;

sub new {
	my $class = shift;

	if (@_ != 4 && @_ != 10) {
		$class->_error("Wrong number of arguments");
	}
	
	my ( 
             $rows,
             $columns,
	     $elems,
             $row_zero,
             $column_zero,
             $row_stride,
             $column_stride,
             $row_offsets,
             $column_offsets,
	     $offset
           );

	my $self = $class->SUPER::new();
	
	if (@_ == 4) {
		$row_zero      = 0;
		$column_zero   = 0;
		$row_stride    = 1;
		$column_stride = 1;
		
		($rows,
		 $columns,
		 $elems,
		 $row_offsets,
		 $column_offsets,
		 $offset ) = ( scalar @{ $_[1] }, scalar @{ $_[2] }, $_[0], $_[1], $_[2], $_[3] ); 
	} else {
		warn "Huh?";
		($rows,
                 $columns,
                 $elems,
                 $row_zero,
                 $column_zero,
                 $row_stride,
                 $column_stride,
                 $row_offsets,
                 $column_offsets,
                 $offset) = @_;
	}		

	$self->_setup( $rows, $columns, $row_zero, $column_zero, $row_stride, $column_stride );

	$self->{'_ELEMS'}   = $elems;
	$self->{'roffsets'} = $row_offsets;
	$self->{'coffsets'} = $column_offsets;
	$self->{'offset'}   = $offset;

	$self->{'_VIEW'} = 1;

	return $self;
}

sub _index {
	my $s = shift;
	return $s->{'offset'} + 
               $s->{'roffsets'}->[ $s->{'r0'} + $_[0] * $s->{'rstride'} ] + 
               $s->{'coffsets'}->[ $s->{'c0'} + $_[1] * $s->{'cstride'} ];
}

sub _have_shared_cells_raw {
	return ($_[0]->{'_ELEMS'} eq $_[1]->{'_ELEMS'});

}

sub _setup {
	my $self = shift;

	if (@_ == 2) {
		$self->SUPER::_setup( $_[0], $_[1] );
		$self->{'rstride'} = 1;
		$self->{'cstride'} = 0;
		$self->{'offset'}  = 0;
	} else {
		$self->SUPER::_setup(@_);
	}
}

sub _column_offset {
	my $self = shift;
	return $self->{'coffsets'}->[ $_[0] ];
}

sub _row_offset {
	my $self = shift;
	return $self->{'roffsets'}->[ $_[0] ];
}

sub view_row {
	my $self = shift;
	$self->_check_row($_[0]);

	my ($size, $zero, $stride, $offsets) = @{ $self }{ qw(columns c0 cstride coffsets) };
	my $offset = $self->{'offset'} + $self->_row_offset($self->_row_rank($_[0]));
	
	return Anorman::Data::Vector::SelectedDense->new( $size, $self->{'_ELEMS'}, $zero, $stride, $offsets, $offset );
}

sub view_column {
	my $self = shift;
	$self->_check_column($_[0]);

	my ($size, $zero, $stride, $offsets) = @{ $self }{ qw(rows r0 rstride roffsets) };
	my $offset = $self->{'offset'} + $self->_column_offset($self->_column_rank($_[0]));
	
	return Anorman::Data::Vector::SelectedDense->new( $size, $self->{'_ELEMS'}, $zero, $stride, $offsets, $offset );
}

sub get_quick {
	my $s = shift;
	return $s->{'_ELEMS'}->[ $s->{'offset'} + 
                                 $s->{'roffsets'}->[ $s->{'r0'} + $_[0] * $s->{'rstride'} ] + 
                                 $s->{'coffsets'}->[ $s->{'c0'} + $_[1] * $s->{'cstride'} ] 
                               ];
}

sub set_quick {
	my $s = shift;
	$s->{'_ELEMS'}->[ $s->{'offset'} + 
                          $s->{'roffsets'}->[ $s->{'r0'} + $_[0] * $s->{'rstride'} ] + 
                          $s->{'coffsets'}->[ $s->{'c0'} + $_[1] * $s->{'cstride'} ] 
                        ] = $_[2];
}


1;
