package Anorman::ESOM::ParserFactory;

use strict;
use warnings;

use Anorman::Common;
use Anorman::Common::Color;
use Anorman::ESOM::ClassTable;
use Anorman::ESOM::DataItem;

# Header parser dispatch table
my %parse_header = ( 
	'bm'    => [ \&_header_matrix_dims, \&_header_datapoints ],
	'cls'   => [ \&_header_datapoints,  \&_header_classes ],
	'cmx'   => [ \&_header_neurons,     \&_header_classes ],
	'lrn'   => [ \&_header_datapoints,  \&_header_numdims, \&_header_col_types, \&_header_var_names ],
	'names' => [ \&_header_datapoints ],
	'wts'   => [ \&_header_matrix_dims, \&_header_numdims, \&_header_col_types ],
	'umx'   => [ \&_header_matrix_dims ],
	'rgb'   => [] # No header 
);

# Line parsers
my %parse_line = ( 
	'cls'   => sub { my ($s,$r) = splice @_,0,2; $s->add(@_) if $_[1] },
	'cmx'   => sub { my ($s,$r) = splice @_,0,2; $s->add(@_) if $_[1] },
	'names' => sub { my ($s,$r) = splice @_,0,2; $s->add( Anorman::ESOM::DataItem::KeyName->new(@_) ) },
	'bm'    => sub { my ($s,$r) = splice @_,0,2; $s->add( Anorman::ESOM::DataItem::BestMatch->new(@_) ) },
	'lrn'   => sub { my ($s,$r) = splice @_,0,2; &_add_matrix_row( $s, $r, \@_ ) },
	'wts'   => sub { my ($s,$r) = splice @_,0,2; &_add_matrix_row( $s, $r, \@_ ) },
	'umx'   => sub { my ($s,$r) = splice @_,0,2; &_add_matrix_row( $s, $r, \@_ ) },
	'rgb'   => sub { my ($s,$r) = splice @_,0,2; $s->data->add( Anorman::Common::Color->new(@_) ) }
);

# Header builders
my %build_header = (
	'bm'    => [ \&_build_matrix_dims, \&_build_datapoints ],
	'cls'   => [ \&_build_datapoints,  \&_build_classes ],
	'cmx'   => [ \&_build_neurons,     \&_build_classes ],
	'lrn'	=> [ \&_build_datapoints,  \&_build_numdims, \&_build_col_types, \&_build_var_names ],
	'names' => [ \&_build_datapoints ],
	'wts'	=> [ \&_build_matrix_dims, \&_build_numdims, \&_build_col_types ],
	'umx'	=> [ \&_build_matrix_dims ],
	'rgb'	=> [ ]
);

# Line builders
my %build_line = (
	'cls'   => sub { my ($s,$r) = @_; return join ("\t", $s->keys->get( $r ), $s->data->get( $r ) ) },
	'cmx'   => sub { my ($s,$r) = @_; return join ("\t", $s->keys->get( $r ), $s->data->get( $r ) ) },
	'names' => sub { my ($s,$r) = @_; return join ("\t", @{ $s->data->get( $r ) }) },
	'bm'    => sub { my ($s,$r) = @_; return join ("\t", @{ $s->data->get( $r ) }) },
	'lrn'   => sub { return join ("\t", &_build_matrix_row(@_) ) },
	'wts'   => sub { return join ("\t", &_build_matrix_row(@_) ) },
	'umx'   => sub { return join ("\t", &_build_matrix_row(@_) ) },
	'rgb'   => sub { my ($s,$r) = @_; return join ("\t", @{ $s->data->get( $r ) }) }
);

# Column types
use constant {
	NULL  => 0,
	DATA  => 1,
	CLASS => 3,
	KEYS  => 9
};

##### PARSER CONSTRUCTOR ######
sub new {
	my $class  = shift;
	my $type   = shift;
	my $parser = {};
	
	$parser->{'TYPE'}            = $type;
	$parser->{'HDR_PARSE_STACK'} = $parse_header{ $type };
	$parser->{'HDR_BUILD_STACK'} = $build_header{ $type };
	$parser->{'LINE_PARSER'}     = $parse_line{ $type };
	$parser->{'LINE_BUILDER'}    = $build_line{ $type };

	return bless ( $parser, $class ); 
}

sub type {
	my $self = shift;
	return $self->{'TYPE'};
}

sub header_parser {
	my $self   = shift;
	return $self->_package_command_stack( 'HDR_PARSE_STACK' );
}

sub header_builder {
	my $self = shift;
	return $self->_package_command_stack( 'HDR_BUILD_STACK' );
}

sub line_builder {
	my $self = shift;
	return $self->_package_command_line( 'LINE_BUILDER' );
}

sub line_parser {
	my $self = shift;
	my $cmd  = $self->{'LINE_PARSER'};

	return sub {
			my $self   = shift;
			my $stream = shift;	

			while ($stream->MORE) {
				$cmd->( $self, $stream->INDEX, $stream->ARRAY );
				$stream->NEXT;
			}
			
		}
}

sub _package_command_line {
	my $self   = shift;
	my $cmd    = shift;

	return sub { $self->{ $cmd }->(@_) }
}

sub _package_command_stack {
	my $self   	  = shift;
	my $command_stack = shift;

	return sub { 
		foreach my $cmd(@{ $self->{ $command_stack } }) {
			$cmd->(@_);
		}
	}
}


###### PARSER FUNCTIONS ######
sub _header_datapoints {
	my $self = shift;
	$self->{'datapoints'} = shift @{ $self->header };
}

sub _build_datapoints {
	my $self = shift;
	push @{ $self->{'header'} }, defined $self->{'datapoints'} ? $self->{'datapoints'} : $self->{'data'}->size;
}

sub _header_numdims {
	my $self = shift;
	$self->{'dim'} = shift @{ $self->header };
}

sub _build_numdims {
	my $self = shift;

	$self->{'dim'}++ if (exists $self->{'key_column'}   && $self->{'key_column'}   != -1);
	$self->{'dim'}++ if (exists $self->{'class_column'} && $self->{'class_column'} != -1);

	push @{ $self->{'header'} }, $self->{'dim'};
}

sub _header_matrix_dims {
	my $self = shift;
	my ($rows,$cols) = split /\s+/, shift @{ $self->header };

	$self->{'rows'}    = $rows;
	$self->{'columns'} = $cols;
	$self->{'neurons'} = $rows * $cols;
}

sub _build_matrix_dims {
	my $self    = shift;
	my $rows    = $self->rows;
	my $columns = $self->columns;

	push @{ $self->{'header'} }, join (" ", $rows, $columns);
}

sub _header_neurons {
	my $self = shift;
	$self->{'neurons'} = shift @{ $self->header };
}

sub _build_neurons {
	my $self = shift;
	
	push @{ $self->{'header'} }, $self->{'neurons'};
}

sub _header_col_types {
	my $self = shift;
	my $line = shift @{ $self->header };

	my @tokens = split /\t/, $line;
	$self->{'col_types'} = [ @tokens ];

	foreach (0 .. $#tokens) {
		my $type = $tokens[$_];

		if ($type == DATA) {
			push @{ $self->{'data_columns'} }, $_;
		} elsif ($type == CLASS) {
			$self->{'class_column'} = $_;
			$self->{'dim'}--;
		} elsif ($type == KEYS) {
			$self->{'key_column'} = $_;
			$self->{'dim'}--;
		} else {
			trace_error("Illegal column type $type") unless ($type == NULL);
		}
	}

	my $dim = scalar @{ $self->{'data_columns'} };

	if (defined $self->{'dim'} && $self->{'dim'} != $dim) {
		trace_error("Number of data columns ($dim) does not match number in header ($self->{'dim'})");
	}

	$self->{'dim'} = $dim;
}

sub _build_col_types {
	my $self = shift;

	if ($self->{'type'} eq 'wts') {
		@{ $self->{'col_types'} } = (1) x $self->{'dim'};
	}

	push @{ $self->{'header'} }, join ("\t", @{ $self->{'col_types'} });
}

sub _header_var_names {
	my $self      = shift;
	my $line      = shift @{ $self->header };
	my $col_types = $self->{'col_types'};
	my @tokens    = split /\t/, $line;
	my @names     = @tokens[ @{ $self->{'data_columns'} } ];

	foreach (0 .. $#tokens) {
		if ($col_types->[ $_ ] == KEYS) {
			$self->{'key_column_name'}   = $tokens[ $_ ];
		} elsif ($col_types->[ $_ ] == CLASS) {
			$self->{'class_column_name'} = $tokens[ $_ ];
		}
	}

	$self->{'var_names'} = \@names;
}

sub _build_var_names {
	my $self      = shift;
	my @var_names = ();

	@var_names[ @{ $self->{'data_columns'} } ] = @{ $self->{'var_names'} };

	if ($self->{'key_column'} != -1) {
		$var_names[ $self->{'key_column'} ] = $self->{'key_column_name'};
	}

	if ($self->{'class_column'} != -1) {
		$var_names[ $self->{'class_column'} ] = $self->{'class_column_name'};
	}

	push @{ $self->{'header'} }, join ("\t", @var_names );
}

sub _header_classes {
	my $self    = shift;
	my $classes = defined $self->{'classes'} ? $self->{'classes'} : Anorman::ESOM::ClassTable->new;
	
	while ( defined (my $line = shift @{ $self->header } )) {
		my ($index, $name, @rgb) = $line =~ m/^(\d+)(?:\s+([ !-~]+))?(?:\s+(\d+)\s+(\d+)\s+(\d+)$)?/;

		my $color = Anorman::Common::Color->new( \@rgb ) if (defined $rgb[2]);

		$classes->add($index, $name, $color);
	}

	if (defined $classes->get_by_index(0)) {
		$classes->add( 0, 'NO_NAME', Anorman::Common::Color->new('WHITE') );
	}
}

sub _build_classes {
	my $self = shift;
	return undef unless defined $self->{'classes'};

	foreach my $class( @{$self->{'classes'} }) {
		push @{ $self->{'header'} }, join ("\t", $class->index, $class->name, @{ $class->color });
	}
}

sub _add_matrix_row {
	my ($self, $row, $A) = @_;

	my @data = @{ $A };

	@data = @data[@{ $self->{'data_columns'} }] 
		if (exists $self->{'data_columns'} && (scalar @data != scalar @{ $self->{'data_columns'} }));

	$self->data->view_row( $row )->assign(\@data);
}

sub _build_matrix_row {
	my ($self, $row) = @_;

	my @row = ();
	my $data_row = $self->{'data'}->view_row( $row );

	if ($self->{'type'} eq 'lrn') {
		$row[ $self->{'key_column'} ]        = $self->{'keys'}->get( $row );
		@row[ @{ $self->{'data_columns'} } ] = @{ $data_row };
	} else {
		@row = @{ $data_row };
	}

	return join ("\t", @row);
}

1;
