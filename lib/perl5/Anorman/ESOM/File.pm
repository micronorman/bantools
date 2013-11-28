package Anorman::ESOM::File;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Common::Iterator;

use Anorman::Data::List;
use Anorman::Data::Hash;
use Anorman::Data;

use Anorman::ESOM::File::List;
use Anorman::ESOM::File::Map;
use Anorman::ESOM::File::Grid;
use Anorman::ESOM::File::Matrix;

use Anorman::ESOM::File::BM;
use Anorman::ESOM::File::ClassMask;
use Anorman::ESOM::File::Cls;
use Anorman::ESOM::File::ColorTable;
use Anorman::ESOM::File::Lrn;
use Anorman::ESOM::File::Names;
use Anorman::ESOM::File::Umx;
use Anorman::ESOM::File::Wts;

use Anorman::ESOM::ParserFactory;

our $DELIMITER      = "\t";
our $HEADER_PREFIX  = "%";
our $COMMENT_PREFIX = "#";


our %FILETYPES = (
	'lrn'   => 'Multivariate Data',  
        'cov'	=> 'Covariance Data',
	'cls'   => 'Classification',
	'names' => 'Names',
	'wts'   => 'ESOM weights',
	'bm'    => 'Bestmatches', 
	'umx'   => 'ESOM U-matrix',
	'cmx'   => 'Class mask',
	'rgb'   => 'Color table'
);

my %CLASS_NAMES = (
	'lrn'	=> 'Lrn',
	'cls'	=> 'Cls',
	'cov'	=> 'Covariance',
	'names' => 'Names',
	'wts'	=> 'Wts',
	'bm'	=> 'BM',
	'umx'	=> 'Umx',
	'cmx'	=> 'ClassMask',
	'rgb'	=> 'ColorTable'
);

my %TYPES = reverse %CLASS_NAMES;

sub new {
	my $class    = shift;
	my $arg      = shift;

	my ($type,$filename);

	# Construct object from child caller
	if ($class ne __PACKAGE__ ) {
		warn __PACKAGE__ . " was called by child constructor $class\n" if $DEBUG;
		$filename = $arg;
		($type) = $class =~ /.+::(\w+)$/;
		$type = $TYPES{ $type };
	} else {
		# Attempt to derive type from filename
        	if ($arg =~ m/.*\.(\w{2,5})$/) {
			$filename = $arg;
			warn "Input $filename looks like a filename\n" if $DEBUG;
			$type     = $1;
			warn "Looks like it's a $type-file\n" if $DEBUG;

		# Otherwise assume that a type was passed directly
		} else {
			warn "Looks like type $type was passed\n" if $DEBUG;
			$type = $arg;
		}
	
		# Data type sanity check
		trace_error( "No file type defined" ) if (!defined $type);
		trace_error( "Unknown filetype $type" )  if !exists $FILETYPES{ $type };

		$class .= '::' . $CLASS_NAMES{ $type };
		
		warn "Reconstructing as child-class $class with $filename\n" if $DEBUG;

		return $class->new( $filename );
	}

	# Generate the appropriate parser for the current file type
	my $parser = Anorman::ESOM::ParserFactory->new( $type );
	my $self   = {  'type'     => $type,
			'filename' => $filename,
			'header'   => [],
			'parser'   => $parser
		     }; 
	return bless ( $self, $class ); 
}

sub load {
	my $self   = shift;
	my $stream = Anorman::Common::Iterator->new( IG => qr/^[#\n]/,
						     HDR => qr/^$HEADER_PREFIX\s?/,
						     FS => qr/$DELIMITER/
						   );

	$self->{'filename'} = shift if defined $_[0];
	
	# Open a filehandle if there's a file (otherwise STDIN is the input);
	if (defined $self->{'filename'}) {
		warn "Loading $FILETYPES{ $self->{'type'} } from file $self->{'filename'}\n" if $VERBOSE;
		$stream->open( $self->{'filename'}) if defined $self->{'filename'};
	}
	
	# Load header
	$self->_load_header( $stream );

	# Initialize data-space
	$self->_init() ;

	# Load data
	$self->_load_data( $stream );

	# Close filehandle
	$stream->close if defined $self->{'filename'};
}

sub save {
	my $self = shift;
	my $FH   = \*STDOUT;

	$self->{'filename'} = shift if defined $_[0];

	if (defined $self->{'filename'}) {
		warn "Writing $FILETYPES{ $self->{'type'} } to file $self->{'filename'}\n" if $VERBOSE;
		open ($FH, '>', $self->{'filename'}) or trace_error("Could not write to file $self->{'filename'}. $!");
	} 

	$self->_build_header;

	foreach my $line(@{ $self->{'header'} }) {
		print $FH "%$line\n"; 
	}

	my $line_builder = $self->parser->line_builder;
	my $size         = $self->size;
	my $i            = -1;

	while ( ++$i < $size ) {
		print $FH $line_builder->( $self, $i ) . "\n";
	}

	close $FH if defined $self->{'filename'};
}

###### UNIVERSAL OBJECT ACCESSORS #######

# Internal parser of the current data type
sub parser     { $_[0]->{'parser'} }
sub header     { $_[0]->{'header'} }
sub type       { $_[0]->{'type'} }
sub rows       { $_[0]->{'rows'} }
sub keys       { $_[0]->{'keys'} }
sub columns    { $_[0]->{'columns'} }
sub neurons    { $_[0]->{'neurons'} }
sub datapoints { $_[0]->{'datapoints'} }
sub dimensions { $_[0]->{'dim'} }
sub data       { $_[0]->{'data'} }
sub classes    { $_[0]->{'classes'} }
sub size       { if (defined $_[0]->{'data'}) { $_[0]->{'data'}->size } else {0} }
  
sub set_datapoints { $_[0]->{'datapoints'} = $_[1] }

sub filename   { 
	my $self = shift;
	return $self->{'filename'} unless defined $_[0];

	$self->{'filename'} = shift;
}

sub description {
	my $self = shift;
	return $FILETYPES{ $self->{'type'} };
}

###### INTERNAL UNIVERSAL FILE METHODS #######

sub _init {
	# Dummy method
}

# Build a header for the current filetype
sub _build_header {
	my $self = shift;
	$self->{'header'} = [];

	my $build_header = $self->parser->header_builder; 

	$build_header->( $self, $self->{'header'} );
}

# Load header from an open file
sub _load_header {
	my $self   = shift;
	my $stream = shift;

	$self->{'header'} = $stream->HEADER;

	my $parse_header = $self->parser->header_parser;

	$parse_header->( $self, $stream );
}

# Load data from an open file
sub _load_data {
	my $self   = shift;
	my $stream = shift;

	# Fetch appropriate line parser
	my $parse_line = $self->parser->line_parser;

	# Execute parser on stream
	$parse_line->( $self, $stream );
}


sub _type_from_fn {
	my $self = shift;

	trace_error("No filename was given") unless (defined $_[0]);

        $_[0]=~ m/.*\.(\w{2,5})$/;
	
	$self->{'type'} = $1;
}

1;











