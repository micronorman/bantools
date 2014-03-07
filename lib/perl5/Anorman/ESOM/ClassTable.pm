package Anorman::ESOM::ClassTable;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Common::Color;

use Anorman::Data::List;
use Anorman::Data::Hash;

use Anorman::ESOM::DataItem;
use Anorman::ESOM::File::ColorTable;

use overload
	'@{}' => \&_to_array,
	'fallback' => undef;

sub new {
	my $class  = shift;
	my $colors = defined $_[0] ? shift : Anorman::ESOM::File::ColorTable->new();

	my $self = { 'data'          => Anorman::Data::List->new,
		     'indexmap'      => Anorman::Data::Hash->new,
		     'namemap'       => Anorman::Data::Hash->new,
		     'class_colors'  => $colors
		};

	bless ( $self, $class );

	$self->add(0, 'NO_CLASS' ) if $colors->size == 0;

	return $self;
}

sub add {
	my $self = shift;
	my ($cls, $name, $color) = @_;

	$cls  = $self->get_highest_class_index + 1 if !defined $cls;
	$name = $cls if !defined $name;

	unless (exists $self->{'indexmap'}->{ $cls }) {
		my $new_class = Anorman::ESOM::DataItem::Class->new( $cls, $name );

		if (!defined $color) {
			if ($cls == 0) {
				$new_class->color( Anorman::Common::Color->new('WHITE') );
			} else {
				my $color = $cls % $self->{'class_colors'}->data->size;
				$new_class->color( $self->{'class_colors'}->data->get($color) );
			}
		} else {
			trace_error("Not a valid color object") unless $color->isa("Anorman::Common::Color");
			$new_class->color( $color );
		}

		$self->{'data'}->add( $new_class );
		$self->{'indexmap'}->set( $cls, $new_class );
		$self->{'namemap'}->set( $name, $new_class );
	}

	
}

sub color_table {
	return $_[0]->{'color_table'};
}

sub size {
	return $_[0]->{'data'}->size;
}

sub get {
	return $_[0]->{'data'}->get($_[1]);
}

sub get_by_index {
	return $_[0]->{'indexmap'}->get($_[1]);
}

sub get_by_name {
	return $_[0]->{'namemap'}->get($_[1]);
}

sub get_highest_class_index {
	my $self = shift;
	
	my $i   = $self->{'data'}->size;
	my $max = 0;
	while ( --$i >= 0 ) {
		my $index = $self->get($i)->index;
		$max = $index if $index > $max;
	}

	return $max;
}

sub remove {

}

sub _to_array { $_[0]->{'data'} }

sub _equals {
	my ($self,$other) = @_;

	return undef if ($self->size != $other->size);

	my $i = -1;
	while ( ++$i < $self->size ) {
		return undef if !($self->get($i) == $other->get($i));
	}
	
	return 1;
}

1;

