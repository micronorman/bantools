package Anorman::Data::Matrix::SelectedDense;

use strict;
use warnings;

use Anorman::Common;

use parent qw(Anorman::Data::Matrix::Abstract Anorman::Data::Matrix);

use Anorman::Data::Vector::SelectedDense;

sub new {
	my $that  = shift;
	my $class = ref $that || $that;


	if (@_ != 4 && @_ != 10) {
		trace_error("Wrong number of arguments");
	}
	
	my ( 
             $rows,
             $columns,
	     $elements,
             $row_zero,
             $column_zero,
             $row_stride,
             $column_stride,
             $row_offsets,
             $column_offsets,
	     $offset
           );

	my $self = bless( { '_ELEMS'   => undef,
	                    'roffsets' => [],
	                    'coffsets' => [],
	                    'offset'   => undef
	                  }, $class );
	
	if (@_ == 4) {
		$row_zero      = 0;
		$column_zero   = 0;
		$row_stride    = 1;
		$column_stride = 1;
		
		($rows,
		 $columns,
		 $elements,
		 $row_offsets,
		 $column_offsets,
		 $offset ) = ( scalar @{ $_[1] }, scalar @{ $_[2] }, $_[0], $_[1], $_[2], $_[3] ); 
	} else {
		warn "Huh?";
		($rows,
                 $columns,
                 $elements,
                 $row_zero,
                 $column_zero,
                 $row_stride,
                 $column_stride,
                 $row_offsets,
                 $column_offsets,
                 $offset) = @_;
	}		

	$self->_setup( $rows, $columns, $row_zero, $column_zero, $row_stride, $column_stride );

	$self->{'_ELEMS'}   = $elements;
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
	if ($_[0]->isa('Anorman::Data::Matrix::SelectedDensePacked') 
	    || $_[0]->isa('Anorman::Data::Matrix:::Dense')) {
		return ($_[0]->{'_ELEMS'} eq $_[1]->{'_ELEMS'});
	}
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

sub _column_offset { $_[0]->{'coffsets'}->[ $_[1] ] }
sub _row_offset    { $_[0]->{'roffsets'}->[ $_[1] ] }

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

sub _v_dice {
	my $self = shift;

	$self->SUPER::_v_dice();

	# Swap offsets between rows and columns
	($self->{'roffsets'},$self->{'coffsets'}) = ($self->{'coffsets'},$self->{'roffsets'});

	$self->{'_VIEW'} = 0;

	return $self;
}

sub _dump {
	my $elems = defined $_[0]->{'_ELEMS'} ? $_[0]->{'_ELEMS'} : 'NULL';
	my ($type)  = ref ($_[0]) =~ /\:\:(\w+)$/;
	printf STDERR ("%s Matrix dump: HASH(0x%p)\n", $type, $_[0]);
	printf STDERR ("\trows\t\t: %lu\n",    $_[0]->{'rows'}     );
    	printf STDERR ("\tcols\t\t: %lu\n",    $_[0]->{'columns'}  );
    	printf STDERR ("\tr0\t\t: %lu\n",      $_[0]->{'r0'}       );
    	printf STDERR ("\tc0\t\t: %lu\n",      $_[0]->{'c0'}       );
    	printf STDERR ("\trstride\t\t: %lu\n", $_[0]->{'rstride'}  );
    	printf STDERR ("\troffsets\t: %s\n",   $_[0]->{'roffsets'} );
    	printf STDERR ("\tcstride\t\t: %lu\n", $_[0]->{'cstride'}  );
    	printf STDERR ("\tcoffsets\t: %s\n",   $_[0]->{'coffsets'} );
    	printf STDERR ("\toffset\t\t: %lu\n",  $_[0]->{'offset'}   );

	if ($elems ne 'NULL') {
		printf STDERR ("\telements[%lu]\t: %s\n",  scalar @{ $elems }, $elems );
	} else {
		printf STDERR ("\telements[%lu]\t: %s\n",  0,$elems );

	}
    	printf STDERR ("\tview\t\t: %i\n\n",   $_[0]->{'_VIEW'}    );

}

1;
