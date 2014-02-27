package Anorman::ESOM;

# class dealing specifically with ESOM grids and combining
# the various data formats such as datapoints and classes
# includes unified method for loading lrn-, wts-, cls-, bm-files
# etc.

our $VERSION = '0.8.6';

use strict;
use warnings;

use Anorman::Common;

use Anorman::ESOM::Config;
use Anorman::ESOM::Datapoint;
use Anorman::ESOM::File;
use Anorman::ESOM::Grid;
use Anorman::ESOM::SOM;
use Anorman::ESOM::BMSearch;

use Anorman::ESOM::ImageRenderer;
use Anorman::ESOM::UMatrixRenderer;
use Anorman::ESOM::Projection qw(project classify distances);

use overload 
	'""' => \&_stringify;

sub new {
        my $that  = shift;
	my $class = ref($that) || $that;

	return bless ( {}, $class );
}

# General accessors
sub rows       { $_[0]->{'rows'}       }
sub columns    { $_[0]->{'columns'}    }
sub neurons    { $_[0]->{'neurons'}    }
sub datapoints { $_[0]->{'datapoints'} }
sub dimensions { $_[0]->{'dim'}        }
sub classes    { $_[0]->{'classes'}    }

# return training data (i.e. lrn-data)
sub training_data {
	my $self = shift;
	return undef unless &_has_lrn( $self );
	return $self->{'lrn'};
}

# return class mask object
sub class_mask {
	my $self = shift;
	return undef unless &_has_cmx( $self );
	return $self->{'cmx'};
}

# return bestmatches object. attempt to project lrn-data onto grid if there are no bestmatches
sub bestmatches {
	my $self = shift;

	return $self->{'bm'} if &_has_bm($self);

	if (&_has_wts($self) && &_has_lrn($self)) {
		$self->{'bm'} = project( $self->{'lrn'}, $self->{'wts'} ); 
	}
}

# returns a bestmatch object like above, but containing the calculated deistance between 
# data vectors and best match neurons

sub bestmatch_distances {
	my $self = shift;

	return $self->{'distances'} if (defined $self->{'distances'});

	if (&_has_lrn($self) && &_has_grid($self)) {

		my $bm   = $self->bestmatches;
		my $lrn  = $self->training_data;
		my $grid = $self->grid;

		$self->{'distances'} = distances( $lrn, $grid, $bm );
	}

	return $self->{'distances'};
}

# return object of classified data points
sub data_classes {
	my $self = shift;

	return $self->{'cls'} if &_has_cls($self);

	if (&_has_bm($self) && &_has_cmx($self)) {
		$self->{'cls'} = classify( $self->{'bm'}, $self->{'cmx'} );
	}

	return $self->{'cls'};
}

# return datapoint names
sub names {
	my $self = shift;

	return $self->{'names'} if $self->_has_names();
}

# Generic opening function for loading multiple files
# Trusts file extensions to reflect filetypes
sub open {
	my $self   = shift;

	foreach my $fn(@_) {
		my $file = Anorman::ESOM::File->new( $fn );

		$file->load( $fn );
		$self->add_new_data( $file );
	}

	1;
}

sub load_data {
	my $self = shift;
	my $fn   = shift;

	my $lrn = Anorman::ESOM::File::Lrn->new( $fn );
	$lrn->load;
	$self->add_new_data( $lrn );
}

sub load_names {
	my $self = shift;
	my $fn   = shift;

	my $names = Anorman::ESOM::File::Names->new( $fn );
	$names->load;
	$self->add_new_data( $names );
}

sub load_bestmatches {
	my $self = shift;
	my $fn   = shift;

	my $bm = Anorman::ESOM::File::BM->new( $fn );
	$bm->load;
	$self->add_new_data( $bm ); 
}

sub load_matrix {
	my $self = shift;
	my $fn   = shift;

	my $umx = Anorman::ESOM::File::Umx->new( $fn );
	$umx->load;
	$self->add_new_data( $umx );
}

sub load_weights {
	my $self = shift;
	my $fn   = shift;

	my $wts = Anorman::ESOM::File::Wts->new( $fn );
	$wts->load;
	$self->add_new_data( $wts );
	$self->grid;
}

sub add_new_data {
	my $self  = shift;
	my $input = shift;

	trace_error("Invalid input format") unless $input->isa("Anorman::ESOM::File");

	$self->_check_new_data( $input );
	$self->{ $input->type } = $input;
}

sub grid {
	my $self = shift;

	# Grid dimensions set, but no grid object present: Initialize grid object
	if (&_has_grid($self) && !defined $self->{'grid'}) {
		$self->{'grid'} = Anorman::ESOM::Grid::ToroidEuclidean->new;
		$self->{'grid'}->rows( $self->{'rows'} );
		$self->{'grid'}->columns( $self->{'columns'} );
		
		if (&_has_wts( $self )) {
			$self->{'grid'}->set_weights( $self->_wts->data );
		} elsif (&_has_dims( $self )) {

			# This will allocate an empty [ rows x columns x dims ] matrix grid
			$self->{'grid'}->dim( $self->{'dim'} );
			#$self->add_new_data( $self->{'grid'}->get_wts );
		}
	} elsif (@_ >= 1) {

		# Clear away deprecated data
		$self->clear_grid;
		
		if (@_== 1) {
			$_[0]->isa("Anorman::ESOM::Grid") or trace_error("Not a grid");
			$self->{'grid'} = $_[0];
			
		} else {
			# Set dimensions so grid initializes at the next call	
			$self->{'rows'}    = $_[0];
			$self->{'columns'} = $_[1];
			$self->{'neurons'} = $_[0] * $_[1];

			return $self->grid;
		}
	}

	return $self->{'grid'};
}

sub weights {
	my $self = shift;

	unless (&_has_wts($self)) {
		if (&_has_grid($self)) {
			$self->add_new_data( $self->grid->get_wts );
		}
	}

	return $self->{'wts'};
}

sub umatrix {
	my $self = shift;
	
	# Render a new U-Matrix if Weights data is present
	unless (&_has_umx($self)) {
		if (&_has_grid($self)) {
			my $r = Anorman::ESOM::UMatrixRenderer->new;

			$self->{'umx'} = Anorman::ESOM::File::Umx->new( $self->rows, $self->columns );
			$self->{'umx'}->data( $r->render( $self->grid ) );
		} else {
			trace_error "No U-Matrix or ESOM Grid present";
		}
	}

	return $self->{'umx'};
}

# Adds a new class to the end of the list
sub add_class {
	my $self  = shift;
	my $name  = shift;
	my $color = shift;

	unless (&_has_classes($self)) {	
		$self->{'classes'} = Anorman::ESOM::ClassTable->new();
		$self->{'classes'}->add( 1, $name, $color );
	} else {
		my $cls = $self->{'classes'}->get_highest_class_index + 1;
		$self->{'classes'}->add( $cls, $name, $color );
	}
}

sub setup_trainer {
	my $self = shift;
	my %opt  = @_;

	trace_error("Cannot initialize a trainer without data") unless &_has_lrn($self);
	trace_error("Cannot initialize a trainer without a grid") unless &_has_grid($self);
	
	$self->{'SOM'} = Anorman::ESOM::SOM::Online->new();
	$self->{'SOM'}->BMSearch( Anorman::ESOM::BMSearch::Simple->new() );
	$self->{'SOM'}->data( $self->{'lrn'}->data );
	$self->{'SOM'}->keys( $self->{'lrn'}->keys );

	my $grid = $self->{'grid'};

	if (&_has_wts($self)) {
		# If weights are already loaded use load these into the training grid
		print $self;
		$self->{'SOM'}->grid->set_weights( $self->_wts->data );
	} else {
		# Otherwise initialize grid from training data
		$self->{'SOM'}->grid( $self->{'grid'} );
		$self->{'SOM'}->init;
	}
}

sub train {
	my $self = shift;
	
	$self->{'SOM'} = shift if (defined $_[0] && $_[0]->isa("Anorman::ESOM::SOM"));
	
	trace_error("No ESOM-training set up") unless defined $self->{'SOM'};

	# run trainer
	$self->{'SOM'}->train;

	# extract trained grid
	my $grid = $self->{'SOM'}->grid;
	my $wts  = $grid->get_wts;

	$self->add_new_data( $wts );

	# Collect bestmatches
	my $bm_neurons = $self->{'SOM'}->bestmatches;

	my $bm = Anorman::ESOM::File::BM->new();
	
	$bm->rows( $grid->rows );
	$bm->columns( $grid->columns );
	
	my $i = -1;
	while ( ++$i < $self->datapoints ) {
		my $key = $i + 1;
		my $neuron_i = $bm_neurons->[$i];
		my $row = $grid->index2row( $neuron_i );
		my $col = $grid->index2col( $neuron_i );

		$bm->add( Anorman::ESOM::DataItem::BestMatch->new( $key, $row, $col ) );	
	}

	$self->add_new_data( $bm );
}

sub reset {
	...
}

# Clear functions
sub clear_umatrix {
	my $self = shift;

	delete $self->{'umx'};
}

sub clear_bestmatches {
	my $self = shift;

	delete $self->{'bm'};
	delete $self->{'distances'};
}

sub clear_data {
	my $self = shift;

	delete $self->{'bm'};
	delete $self->{'cls'};
	delete $self->{'lrn'};
	delete $self->{'distances'};
}

sub clear_classmask {
	my $self = shift;

	delete $self->{'cmx'};
	delete $self->{'cls'};
}

sub clear_grid {
	my $self = shift;

	delete $self->{'bm'};
	delete $self->{'cmx'};
	delete $self->{'grid'};
	delete $self->{'umx'};
	delete $self->{'wts'};
	delete $self->{'distances'};
}

# When adding new data, verify consistency
sub _check_new_data {
	my $self    = shift;
	my $input   = shift;

	trace_error("Input is not a valid ESOM-file") unless $input->isa("Anorman::ESOM::File");

	my $err_msg = '';

	if (&_has_datapoints($input)) {
		unless (&_has_datapoints($self)) {
			$self->{'datapoints'} = $input->datapoints;
		}	
	}

	if (&_has_grid($input)) {
		unless (&_has_grid($self)) {
			$self->{'rows'}    = $input->rows;
			$self->{'columns'} = $input->columns;
		} else {
			if ($input->rows != $self->{'rows'} || $input->columns != $self->{'columns'}) {
				$err_msg .= "\nGrid " &_2D_string($input) . " in " . $input->filename .
				" has incompatible dimensions with existing data  " . &_2D_string( $self ); 
			}
		}
	}

	if (&_has_neurons($input)) {
		unless (&_has_neurons($self)) {
			$self->{'neurons'} = $input->neurons;
		} else {
			if ($input->neurons != $self->{'neurons'}) {
				$err_msg .= "\n" . $input->type . "-data has an incompatible number of neurons (" .
				$input->neurons . ") with existing data (" . $self->{'neurons'} . ")"; 
			}	
		}
	}

	if (&_has_dims($input)) {
		unless (&_has_dims($self)) {
			$self->{'dim'} = $input->dimensions
		} else {
			if ($input->dimensions != $self->{'dim'}) {
				$err_msg .= "\n" . $input->filename . " has an incompatible number of data dimension (" .
				$input->dimensions . ") with existing data (" . $self->{'dim'} . ")"; 
			}
		}
	}

	if (&_has_classes($input)) {
		unless (&_has_classes($self)) {
			$self->{'classes'} = $input->classes;
		} else {
			if ($self->classes->size != $self->{'classes'}->size) {
				$err_msg .= "\n" . $input->filename . " has a different number of classes";
			}
		}
	}

	trace_error("Unable to import new data\n" . $err_msg ) if $err_msg ne '';

	return 1;
}

# Internal object Accessors. Nothing but syntactic sugar, really
sub _bm    { $_[0]->{'bm'}    }
sub _cls   { $_[0]->{'cls'}   }
sub _cmx   { $_[0]->{'cmx'}   }
sub _lrn   { $_[0]->{'lrn'}   }
sub _names { $_[0]->{'names'} }
sub _rgb   { $_[0]->{'rgb'}   }
sub _umx   { $_[0]->{'umx'}   }
sub _wts   { $_[0]->{'wts'}   }
sub _SOM   { $_[0]->{'SOM'}   }

# Internal data checks
sub _has_lrn        { return (defined $_[0]->_lrn)      }
sub _has_bm         { return (defined $_[0]->_bm)       } 
sub _has_names      { return (defined $_[0]->_names)    }
sub _has_cmx        { return (defined $_[0]->_cmx)      }
sub _has_cls        { return (defined $_[0]->_cls)      }
sub _has_grid       { return (defined $_[0]->rows && defined $_[0]->columns ) };
sub _has_wts        { return (defined $_[0]->_wts)      }
sub _has_umx        { return (defined $_[0]->_umx)      }
sub _has_neurons    { return (defined $_[0]->neurons)   }
sub _has_datapoints { return (defined $_[0]->datapoints)}
sub _has_dims       { return (defined $_[0]->dimensions)}
sub _has_classes    { return (defined $_[0]->classes)   }
sub _has_trainer    { return (defined $_[0]->_SOM)      }

# Stringification. To display basic information about the ESOM
sub _2D_string {
	return "[ " . $_[0]->rows . " x " . $_[0]->columns . " ]"; 
}

sub _stringify {
	my $self = shift;
	
	my $string = "\n";

	$string .= "------------------\n";
	$string .= "ESOM Data overview\n";
	$string .= "------------------\n";
	$string .= "\nHas Multivariate Data:\t" . (&_has_lrn($self) ? 'Yes, dimensions: ' .
		&_2D_string( $self->_lrn->data ) : 'No');
	$string .= "\nHas Bestmatches:\t" . (&_has_bm($self) ? 'Yes, ' .
		$self->_bm->size : 'No');
	$string .= "\nHas Data Classes:\t"     . (&_has_classes($self) ? 'Yes, ' .
		$self->classes->size : 'No');
	$string .= "\nHas Class Mask:\t\t"  . (&_has_cmx($self) ? 'Yes, coverage (%): ' .
		( sprintf("%.2f", (100 * $self->_cmx->size / $self->neurons))) : 'No');
	$string .= "\nHas Grid:\t\t"        . (&_has_grid($self) ? 'Yes, dimensions: ' .
		&_2D_string($self) . ', neurons: ' . $self->neurons : 'No');
	$string .= "\nHas U-Matrix:\t\t"    . (&_has_umx($self) ? 'Yes, dimensions: ' .
		&_2D_string($self) : 'No');
	$string .= "\nHas ESOM Weights:\t" . (&_has_wts($self) ? 'Yes, neurons: ' .
		$self->_wts->neurons : 'No');
	$string .= "\nHas ESOM Trainer:\t" . (&_has_trainer($self) ? 'Yes' : 'No');
	$string .= "\n\n";

	return $string;
}


