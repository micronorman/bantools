package Anorman::ESOM;

# class dealing specifically with ESOM grids and combining
# the various data formats such as datapoints and classes
# includes unified method for loading lrn-, wts-, cls-, bm-files
# etc.

our $VERSION = '0.8.3';

use strict;
use warnings;

use Anorman::Common;

use Anorman::ESOM::Datapoint;
use Anorman::ESOM::File;
use Anorman::ESOM::Grid;
use Anorman::ESOM::SOM;
use Anorman::ESOM::BMSearch;

use Anorman::ESOM::UMatrixRenderer qw(render);
use Anorman::ESOM::Projection qw(project classify);

use overload 
	'""' => \&_stringify;

sub new {
        my $class   = shift;
        my $self    = bless ( {}, ref ($class) || $class);

	return $self;
}

# General accessors
sub rows       { $_[0]->{'rows'}       }
sub columns    { $_[0]->{'columns'}    }
sub neurons    { $_[0]->{'neurons'}    }
sub datapoints { $_[0]->{'datapoints'} }
sub dimensions { $_[0]->{'dim'}        }
sub classes    { $_[0]->{'classes'}    }

sub data {
	my $self = shift;
	return undef unless &_has_lrn( $self );
	return $self->{'lrn'};
}

sub class_mask {
	my $self = shift;
	return undef unless &_has_cmx( $self );
	return $self->{'cmx'};
}

sub bestmatches {
	my $self = shift;

	return $self->{'bm'} if &_has_bm($self);

	if (&_has_wts($self) && &_has_lrn($self)) {
		$self->{'bm'} = project( $self->{'lrn'}, $self->{'wts'} ); 
	}
}

sub data_classes {
	my $self = shift;

	return $self->{'cls'} if &_has_cls($self);

	if (&_has_bm($self) && &_has_cmx($self)) {
		$self->{'cls'} = classify( $self->{'bm'}, $self->{'cmx'} );
	}

	return $self->{'cls'};
}

sub names {
	my $self = shift;

	return $self->{'names'} if $self->_has_names();
}

sub open {
	my $self   = shift;
	my $fn     = shift;

	my $file = Anorman::ESOM::File->new( $fn );

	$file->load( $fn );

	$self->add_new_data( $file );

	return $file;
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

	return $self->{'grid'} if defined $self->{'grid'};

	if (&_has_grid($self)) {
		$self->{'grid'} = Anorman::ESOM::Grid::ToroidEuclidean->new;
		$self->{'grid'}->rows( $self->{'rows'} );
		$self->{'grid'}->columns( $self->{'columns'} );

		if (&_has_wts( $self )) {
			$self->{'grid'}->set_weights( $self->_wts->data );
		}
	}

	return $self->{'grid'};
}

sub umatrix {
	my $self = shift;

	# Render a new U-Matrix if Weights data is present
	unless (&_has_umx($self)) {
		warn "No U-Matrix present\n" if $VERBOSE;
		if (&_has_grid($self)) {
			$self->{'umx'} = Anorman::ESOM::File::Umx->new( $self->{'rows'}, $self->{'columns'} );
			$self->{'umx'}->data( render( $self->grid ) );
		}
	}

	return $self->{'umx'};
}

sub weights {
	my $self = shift;

	unless (&_has_wts($self)) {
		warn "No weights present\n" if $VERBOSE;
		if (&_has_lrn($self) && &_has_trainer($self)) {
			$self->train;
		}
	}

	return $self->{'wts'};
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

	$self->{'SOM'} = Anorman::ESOM::SOM::Online->new();
	$self->{'SOM'}->BMSearch( Anorman::ESOM::BMSearch::Simple->new() );

	trace_error("Cannot train without lrn-data") unless &_has_lrn($self);
	
	$self->{'SOM'}->data( $self->{'lrn'}->data );

	if (&_has_wts($self)) {
		$self->{'SOM'}->grid ( Anorman::ESOM::Grid::ToroidEuclidean->new( $self->_wts->rows, $self->_wts->columns, $$self->_wts->dimensions ) );
		$self->{'SOM'}->grid->set_weights( $self->_wts->data );
	} else {
		# Otherwise initialize grid from training data
		$self->{'SOM'}->grid( Anorman::ESOM::Grid::ToroidEuclidean->new( 109, 182, $self->_lrn->dimensions ) );
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
	my $wts = Anorman::ESOM::File::Wts->new( $grid->rows, $grid->columns, $grid->dim );

	$wts->data( $grid->get_weights );
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

# When adding new data, check for size consistency
sub _check_new_data {
	my $self    = shift;
	my $input   = shift;
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

# Internal Accessors
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
sub _has_grid       { return (defined $_[0]->rows && defined $_[0]->columns) };
sub _has_wts        { return (defined $_[0]->_wts)      }
sub _has_umx        { return (defined $_[0]->_umx)      }
sub _has_neurons    { return (defined $_[0]->neurons)   }
sub _has_datapoints { return (defined $_[0]->datapoints)}
sub _has_dims       { return (defined $_[0]->dimensions)}
sub _has_classes    { return (defined $_[0]->classes)   }
sub _has_trainer    { return (defined $_[0]->_SOM)      }

# Stringification
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
	$string .= "\nHas Class Mask:\t\t"  . (&_has_cmx($self) ? 'Yes, coverage: ' .
		(100 * $self->_cmx->size / $self->neurons) : 'No');
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
