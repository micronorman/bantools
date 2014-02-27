package Anorman::Data::Algorithm::Watershed;

use warnings;
use strict;

use Anorman::Common;

use Anorman::Math::LabelTree;
use Anorman::Math::Set;

use List::PriorityQueue;
use GD;

use constant { NULL => -1,
	       EDGE => -2,
               MASK => -3,
               ERR  => -4,
	     };
#################################################################################
#
#TODO: REWRITE CODE TO ACCOMODATE DATA MATRICES INSTEAD OF ESOM DATA STRUCTURES
#
#################################################################################

sub new {
	my $class   = shift;

	unless (@_ == 2) {
		$class->_error("Not enough arguments\n\n" .
	       	"Usage: " . __PACKAGE__ . "::new ( [ Grid_obj ] [ Umatrix_obj ] )"); 
	}

	my $grid    = shift;
	my $umatrix = shift;

	trace_error("Not a grid")     unless $grid->isa("Anorman::ESOM::Grid");
	trace_error("Not a U-Matrix") unless $grid->isa("Anorman::ESOM::File::Umx");

	my $self      = { 'grid' => $grid, 'umatrix' => $umatrix  };

	return bless ($self, $class || ref($class));
}

sub grid {
	my $self = shift;
	return $self->{'grid'};
}

sub umatrix {
	my $self = shift;
	return $self->{'umatrix'};
}

sub mask {
	# define a pixel mask which cannot be flooded 
	my $self = shift;
	my $mask = shift;

	if (defined $mask) {
		$self->_error("Not a valid pixels mask." . 
                             " Must be array of equal size to the number of pixels") 
			unless (ref ($mask) eq 'ARRAY' && @{ $mask } eq $self->grid->size);
		$self->{'_mask'} = $mask;
	} else {
		$self->_error("No pixel-mask defined") unless defined $self->{'_mask'};
		return $self->{'_mask'};
	}
}

sub threshold {
	# set an arbitrary height at which to stop merging
	my $self      = shift;
	my $threshold = shift;

	if (defined $threshold) {
		$self->_error("Watershed threshold must be between 0.0 and 1.0") 
			unless ($threshold > 0.0 && $threshold < 1.0);
		$self->{'threshold'} = $threshold;
	} else {
		return $self->{'threshold'};
	}
}

sub tree {
	my $self        = shift;
	my @markers     = @_;
	my $num_markers = @markers;
	my $grid_size   = $self->grid->size;
	my $rows        = $self->grid->rows;
	my $cols        = $self->grid->columns;

	warn "Number of markers:\t$num_markers\n";
	warn "Size of grid:\t\t$grid_size ($rows x $cols)\n";

	my @pixel_labels = (NULL) x $grid_size;
	my @priority     = ();

	# incorporate mask into pixel-map if one was defined
	if (defined (my $mask = $self->mask)) {
		while (defined (my $i = $self->umatrix->iterate)) {
			$pixel_labels[ $i ] = MASK if $mask->[ $i ] == 1;
		}
	}

	my $tree   = Anorman::Math::LabelTree->new($num_markers);
	my $pixels = List::PriorityQueue->new;
	my $umax   = $self->umatrix->get(0);
	my $umin   = $self->umatrix->get(0);

	# make sure data is normalized
	while (defined (my $i = $self->umatrix->iterate)) {
		my $v = $self->umatrix->get( $i );

		$umax = $v > $umax ? $v : $umax;
		$umin = $v < $umin ? $v : $umin;
	}

	$self->umatrix->normalize unless ($umin == 0 && $umax == 1);

	# convert heights to grayscale [0..255] and assign as priorities
	while (defined (my $i = $self->umatrix->iterate)) {
		my $h  = (0xFF & (0xFF * $self->umatrix->get($i)));
		
		$priority[ $i ] = $h;
	}
 
	my $g_labels = Anorman::Math::Set->new(@markers);

	warn "1. Inserting markers\n";	
	
	my $i = 0;

	foreach my $p(@markers) {
		my $label = $pixel_labels[ $p ];

		if ($label == NULL) {
			$pixel_labels[ $p ] = $i;
		} elsif ($label != MASK) {
			warn "This should probably never happen!\n";
			my $new_label = $tree->merge( $label, $i );
			$pixel_labels[ $p ] =  $new_label;

			$g_labels->delete( $label, $i );
			$g_labels->insert( $new_label );
		}

		$i++;
	}	
	
	warn "2. Mapping edges around markers\n";

	foreach my $p(@markers) {
		foreach my $n( $self->grid->immediate_neighbors( $p ) ) {
			
			# add marker neighbors to priority queue and mark the as seen
			if ($pixel_labels[ $n ] == NULL) {
				$pixels->insert( $n, $priority[ $n ] );
				$pixel_labels[ $n ] = EDGE;
			}
		}
	}
	
	my $counter = 0;
	#$self->_dump_pixels( "dump" . $counter . ".png", \@pixel_labels);
	
	warn "3. Flooding...\n";

	# make set for keeping neighboring labels
	my $n_labels  = Anorman::Math::Set->new;
	
	# iterate through priority queue
	while (defined (my $p = $pixels->pop)) {
		$counter++;
		
		$n_labels->clear();

		foreach my $n( $self->grid->immediate_neighbors( $p ) ) {
			
			my $l = $pixel_labels[ $n ];

			# add new unlabeled pixels into the priority queue
			if ($l == NULL) {
				$pixels->insert( $n, $priority[ $n ] );
				$pixel_labels[ $n ] = EDGE;
			} elsif ($l != EDGE && $l != MASK) {
				$n_labels->insert( $l ) ;
			}
		}
	
		$self->_error("Assertion failure") if ($n_labels->is_empty);
		my $assigned_label = ERR;

		if ($n_labels->size == 1) {
			# assigns a single label to the current edge pixel
			$assigned_label = $n_labels->pop;
		} else {
			# creates a new label and propagates it thorugh the pixel-map
			# when an edge is adjacent to more than one label

			$assigned_label = $tree->merge( $n_labels->members );

			foreach (@pixel_labels) {
				next if ($_ < 0);
				if ( $n_labels->exists( $_ ) ) {
					$_ = $assigned_label;
				} 
			}
			
			# updates the global label set with the new label
			my $deleted  = $g_labels->delete( $n_labels->members );
			my $inserted = $g_labels->insert($assigned_label);	

			warn "Deleted: $deleted. Inserted: $inserted\n";			
		}
		
		# Error trap. Should never happen
		$self->_error("Invalid pixel-label assigned") if ($assigned_label == ERR);
		

		$pixel_labels[ $p ] = $assigned_label;
		
		#unless ($counter % 1000) {
		#	$self->_dump_pixels( "dump" . $counter . ".png", \@pixel_labels);
		#}
	}
	
	warn "\nDone in $counter steps\n";

	
	#foreach my $label( $g_labels->members ) {
	#	my $size = $tree->members( $label );

	#	warn "LABEL: $label SIZE: $size\n";
	#}
	
	return $tree;
}

sub _error {
	my $self = shift;
	&Anorman::Common::error(@_);
}

sub _dump_pixels {
	
	# Create an GD::Image object and plot the currently
	# labelled pixels as a PNG-file using an arbitrary color-wheel
	my $self = shift;

	my ($fname, $pixel_labels) = @_;

	my $rows = $self->grid->rows;
	my $cols = $self->grid->columns;
	my $im   = new GD::Image( $cols, $rows );
			
	my $white  = $im->colorAllocate(255,255,255);
	my $grey   = $im->colorAllocate(127,127,127);
	my $black  = $im->colorAllocate(0,0,0);
	
	# default ESOM color wheel 
	my @colors = ( 
			[255,0,0],
			[255,255,0],
			[0,0,255],
			[255,0,255],
			[0,255,0],
			[0,255,255],
			[255,128,0],
			[128,0,255],
			[153,114,63],
			[255,153,204],
			[153,191,63],
			[153,114,191],
			[178,255,204],
			[217,178,255],
			[89,191,191],
			[255,217,178],
			[255,255,191],
			[191,63,140],
			[0,0,127],
			[51,102,102],
			[76,76,0],
			[0,64,0],
			[102,0,0],
			[115,115,255],
			[64,0,64],
			[255,178,178],
			[255,171,15],
			[64,38,0],
			[166,102,0],
			[153,204,153],
			[153,153,204],
			[255,191,115]
		      );

	foreach (@colors) { $_ = $im->colorAllocate(@{ $_ }) };
		
	$im->transparent($white);
	$im->interlaced('true');

	foreach my $x(0 .. $rows - 1) {
		foreach my $y(0 .. $cols - 1) {
			my $i = $self->grid->coords2index( $x, $y );
			next if ($pixel_labels->[ $i ] == NULL);
				
			if ($pixel_labels->[ $i ] == EDGE) {
				$im->setPixel($y,$x,$grey);	
			} elsif ($pixel_labels->[ $i ] == MASK) {
				$im->setPixel($y,$x, $black);
			} else {
				$im->setPixel($y,$x, $colors[ $pixel_labels->[ $i ] % scalar @colors ]);
			}
		}
	}
		
	open (my $PNG, '>', $fname) or $self->_error("PNG-dump write error, $!");
	binmode $PNG;
	print $PNG $im->png;
	close $PNG;

}

1;
