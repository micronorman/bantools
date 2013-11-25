package Anorman::Counts;

use Anorman::Common;
use Anorman::Math::Common;
use List::Util qw(sum min max);

sub  new {
    my $self     = shift;
    my $data_ref;

    # Construct a bare table data structure
    my %table_info    = ( 'rows' => 0, 
                          'cols' => 0,
			  'name' => 'All'
                         );
                    
    my @row_index     = ( \%table_info );
    push @{ $data_ref }, [ @row_index ];

    return bless ($data_ref, ref($self) || $self);
}    

sub open {
#NOTE: This routine is clumsy. Needs to be improved
    my $self   = shift;
    my $fn     = shift;
    my $FH     = \*STDIN;
    my $data_r = [];

    if (defined $fn) {
        open ($FH, '<', $fn) or $self->_error("[CountsTable] Could not open $fn, $!");
        warn "Opening $fn\n";
    }

    my $row_num  = 0;
    my $hdr_flag = 0;
    my $hdr_line = 0;

    while (defined (my $line = <$FH>)) {
        
        next if ($line =~ m/^#/ || $line =~ m/^(\s)*$/);
        
        $hdr_flag = ($line =~ m/^%/);
        
        chomp $line;
        
        my @F = split ("\t", $line);
        
        if ($hdr_flag) {
            $F[0] =~ s/^%\s?//;
            $hdr_line++;

            # First two lines of header specify dimensions of data
            # matrix
            $self->[0][0]->{'rows'} = $F[0] if $hdr_line == 1;
            $self->[0][0]->{'cols'} = $F[0] if $hdr_line == 2;

            # Third line specifies column types and detemines
            # how the rest of the table will be parsed
            # 9 is a row that contains the unique row index key/number (optional),
            # 1 indicates a data column 
            # 0 indicates an column containing row metadata
            # typically this will include sequence lengths and row sums
            if ($hdr_line == 3) {
                my $cols = $self->[0][0]->{'cols'};
                my $rows = $self->[0][0]->{'rows'};
		$cols-- if $F[0] == 9;

                # pre-allocate matrix
                foreach my $col_num(0..$cols) { 
                    $self->[$col_num][$rows] = undef;
                }
                $self->_error("Type line can only contain 0,1 or 9") 
                    unless grep { /^[019]$/ } @F;
                $self->[0][0]->{'col_types'} = \@F;
            }
            
            if ($hdr_line == 4) {
                my $col_num = 0;
                foreach my $c(0..$#F) {

                    my $type = $self->[0][0]->{'col_types'}->[$c];
                    
                    $self->_error("Column types not defined")
                        unless defined $type;
                    
                    if ($type == 0) {
                        my $K = lc $F[$c];
                        $self->[0][0]->{'row_keys'}->[$c] =  $K;
                    } elsif ($type == 1) {
                        $col_num++;
                        $self->[$col_num][0] = { 'name' => $F[$c], '_num' => $col_num };
                    } 
                }
            }
        } else {
            $row_num++;
            $self->[0][$row_num] = {'_num' => $row_num };

            my $col_num = 0;
            
            foreach my $c(0..$#F) {

                my $type = $self->[0][0]->{'col_types'}->[$c];

                if ($type == 0) {
                    my $idx_key = $self->[0][0]->{'row_keys'}->[$c];
                    $self->[0][$row_num]->{ $idx_key } = $F[$c];
                } elsif ($type == 1) {
                    $col_num++;
                    $self->[$col_num][$row_num] = $F[$c];
                }
            }
        }
    }
    
    close $FH unless $FH = \*STDIN;
}

sub print {
    # Prints the data table
    my $self         = shift;
    my $user_opt     = shift;
    my $info         = $self->table_info;      
    my ($cols,$rows) = $self->dims;
    my $h_cols       = $cols; 
    my $FH           = \*STDOUT;

    my %default_opt = 
        ( 'rows' => 1,
          'cols' => 1,
	  'delim' => "\t",
          'col_types' => 1,
          'header_row' => 1,
          'row_num' => 0,
          'row_info' => $info->{'row_keys'},
          'data' => 1,
          'file' => 0
        );

    my %options  = (%default_opt,%{$user_opt});
    my $opt_r    = \%options;
    my @row_keys = @{ $opt_r->{'row_info'} };
    my @header   = ();
    my @types    = ();

    if ($opt_r->{'row_num'}) {
        push (@header,'Key');
        push (@types, 9);
        $h_cols++;
    }
    if ($opt_r->{'row_info'}) {
        push (@header, map { ucfirst } @row_keys);
        push (@types, 0) foreach @row_keys;
    }
    if ($opt_r->{'data'}) {
        push (@header, $self->get_info_vals( 'name', $self->col_info));
        push (@types, 1) foreach (1..$cols);
    }
    if ($opt_r->{'file'}) {
        my $fn = $opt_r->{'file'};
        open ($FH, '>', $fn) or $self->_error("ERROR: Could not write to file $fn, $!"); 
        warn "Writing to $fn\n"; 
    }

    local $" = $opt_r->{'delim'};

    # print header
    print $FH "% $rows\n"   if $opt_r->{'rows'};
    print $FH "% $h_cols\n" if $opt_r->{'cols'};
    print $FH "% @types\n"  if $opt_r->{'col_types'};
    print $FH "% @header\n" if $opt_r->{'header_row'};
    
    # print rows
    foreach my $row_number(1..$rows) {

        my @row_info = @{ $self->[0][$row_number] }{ @row_keys };
        my @row_data = map { $self->[$_][$row_number] } (1..$cols);
        my @row      = ();
        
        # Assemble row
        push @row, $row_number if $opt_r->{'row_num'};
        push @row, @row_info   if $opt_r->{'row_info'};
        push @row, @row_data   if $opt_r->{'data'};
        
        # Then print it
        print $FH "@row\n";
    }
    close $FH unless $FH = \*STDOUT;
}

sub filter_by_info (&@) {
    # a code block (e.g. sub { $_->{'length'} < 500 } ) will be used
    # to filter through indexed entries. Returns a list of row numbers
    # that passed the filter

    warn "Filtering\n";

    my $self    = shift;
    my $filter  = shift;
    my @results = grep { $filter->($_) } @_;
    
    return map { $_->{'_num'} } @results;
}

sub pick_random {
    # picks random rows from the table
    my $self   = shift;
    my $number = shift;
    my $rows   = $self->[0][0]->{'rows'};

    # make a lookup table to ensure that the same row is not picked twice
    my %picked_numbers = ();

    # if a floating point value was passed, calculate N
    if ($number =~ /^[01]\.\d+/) {
        $self->_error("ERROR: cannot pick equal to or more than 100% randomly") if $number >= 1;
        $number = int($rows * $number);
    }

    while (scalar keys %picked_numbers < $number) {
        my $rand_number = int(rand($rows)) + 1;
        $picked_numbers{$rand_number}++;
    }
    return sort { $a <=> $b } keys %picked_numbers;
}

sub sort {
    my $self    = shift;
    my $sortkey = shift;
    my $info_r  = shift;
    my $reverse = shift;

    my $block;

    warn "Sorting with key: $sortkey\n";

    if ($reverse) {
        $block = sub ($$) { $_[1]->{$sortkey} <=> $_[0]->{$sortkey} };
    } else {
        $block = sub ($$) { $_[0]->{$sortkey} <=> $_[1]->{$sortkey} };
    }
    my @neworder = map { $_->{'_num'} } sort $block @{ $info_r };

    return wantarray ? @neworder : \@neworder;
}

sub rebuild {
    warn "Rebuilding\n";

    my $self   = shift;
    my (@rows) = (@_);

    warn "New table is empty!" if !defined $_[0];

    foreach my $col(@{ $self }) {

        my $newrow = 1;
        
        # Rearrange and cut new table. Inspired by Fisher-Yates shuffle algorithm
        foreach my $oldrow(@rows) {

            if ($oldrow > $newrow) {
                # perform swap
                ($col->[$newrow],$col->[$oldrow]) = 
                ($col->[$oldrow],$col->[$newrow]);
            }

            # update table identifier
            $self->[0][$newrow]->{'_num'} = $newrow;
            $newrow++;
        }
        # discard "swapped out" leftovers (if any)
        splice (@{$col},$newrow) if ($newrow < $self->[0][0]->{'rows'});
    }
    $self->update_info;
}

sub apply {
    
    # apply code block to each array in an array of arrays (matrix)  
    # returns a vector of results (e.g. sums of all columns)
    my $self = shift;
    my $code = shift;
    my $data = shift;
    my $opt  = shift;
    
    # Sniff data structure
    my $type = ref($data);
    my $deep = ref($data->[-1]);

    $self->_error( "Illegal Data structure. Cannot apply block" ) unless $type;

    if ($deep eq 'ARRAY' or $deep eq 'HASH' ) {
        # Applies code-block to nested data structure (2D Matrix)
	# and returns an array of results or an array reference
        my @results = map { &$code( $_, $opt ) } @{$data};
        return wantarray ? @results : \@results;
    } else {
        # Same as above, but applies code to 1D Matrix (array)
        my $result = &$code( $data, $opt );
        return $result;
        }

}


sub normalize {
    # uses 'apply' to run normalization routines on the data
    my $self   = shift;
    my $ref    = shift;
    my $method = defined $_[0] ? shift : 'by_sum';
    my $opt    = shift;

    my %METHODS = 
    
    ( 
        'by_sum'      => sub ($) { # simplest form of normalization. normalize values so the sum is 1
                                   my $data_r = shift;
	                           my $info_r = shift_info( $data_r );
	                           
				   &Anorman::Math::Common::normalize_sum( $data_r, $info_r->{'_sum'} );
                                 },
        'by_norm'     => sub ($) { my $data_r = shift;
	                           my $info_r = shift_info( $data_r );
				   my $norm   = &Anorman::Math::Common::vector_euclidean_norm( deref( $data_r ) );
	                           &Anorman::Math::Common::normalize_sum( $data_r, $norm );
                                 },
                 
        'zero_to_one' => sub ($) { my $data_r     = shift;
	                           my $info_r     = shift_info( $data_r );
			           my @a          = deref( $data_r );
                                   my ($min,$max) = (min (@a), max (@a));
				   my $range      = $max - $min;
				   
				   return undef unless $range;
				    
				   foreach (@{ $data_r }) { 
				       $$_ -= $min;
                                       $$_ /= $range;  
                                   }
				   1;
                                 },
        'logtrans'     => sub ($;$$) { my $data_r  = shift;
				       my $info_r  = shift_info( $data_r );
				  
				       &Anorman::Math::Common::normalize_BoxCox( $data_r, 0 );
				  },
	'BoxCox'       => sub     { my $data_r = shift;
                                    my $opt_r  = shift;
                                    my $info_r = shift_info( $data_r );

                                    &Anorman::Math::Common::normalize_BoxCox( $data_r, $opt->{'lambda1'}, $opt->{'lambda2'} );
                                    
                                  },
	'BoxCox_opt'   => sub     { my $data_r = shift;
	                            my $info_r = shift_info( $data_r );

				    my $lambda1 = &Anorman::Math::Common::optimize_BoxCox_lambda( $data_r, -10, 10 );
				    my $lambda2;# = &Anorman::Math::Common::optimize_BoxCox_shift_parameter( $data_r, $lambda1 );
					
				    &Anorman::Math::Common::normalize_BoxCox( $data_r, $lambda1, $lambda2 );
				    1;
	      
	                          },
        'ztrans'       => sub ($) { my $data_r = shift;
	                            my $info_r = shift_info( $data_r );
				    
				    $info_r = exists $info_r->{'_stdev'} ? $info_r : &Anorman::Math::Common::stats_lite( deref( $data_r ) );

				    my $mean  = $info_r->{'_mean'};
                                    my $stdev = $info_r->{'_stdev'};

				    return undef unless $stdev;
                      
                                    foreach (@{ $data_r }) {
                                        $$_ -= $mean;
                                        $$_ /= $stdev;
                                    }
				    1;
                                  },
         'rztrans'     => sub ($) { my $data_r = shift;
	                            my $info_r = shift_info( $data_r );
                       
				    $info_r = exists $info_r->{'_rstdev'} ? $info_r : &Anorman::Math::Common::stats_robust( deref( $data_r ) );

				    my $trmean = $info_r->{'_trmean'};
				    my $rstdev = $info_r->{'_rstdev'};
                                    return undef unless $rstdev;
                                    
				    foreach (@{ $data_r }) {
                                        $$_ -= $trmean;
                                        $$_ /= $rstdev;
                                    }
				    1;
                                  }
    );
    
    my $code = $METHODS{$method};

    if (!defined $code) {
	    $self->_error ("Unknown normalization method ($method)\nUse one of the following valid methods:\n" . 
		join (", ", sort { $a cmp $b } keys %METHODS) );
    }
    
    $self->apply($code,$ref, $opt);
}

sub calc_stats { 
        # uses 'apply' to calculate descriptive statistics on data
	my $self   = shift;
        my $data_r = shift;
        my $method = shift;


        my %METHOD = 
         (
          'quick'  => sub ($) { my $data_r = shift;
                                my $info_r = shift_info( $data_r );
                                my $stat   = &Anorman::Math::Common::stats_quick( deref( $data_r ) );
				
				@{ $info_r }{ keys %{ $stat } } = values %{ $stat };
				
				return $info_r;
                              },
          'lite'   => sub ($) { my $data_r = shift;
                                my $info_r = shift_info( $data_r );
                                my $stat   = &Anorman::Math::Common::stats_lite( deref( $data_r ) );
				
				@{ $info_r }{ keys %{ $stat } } = values %{ $stat };

				return $info_r;
                              },
          'full'   => sub ($) { my $data_r = shift ;
                                my $info_r = shift_info( $data_r );
                                my $stat   = &Anorman::Math::Common::stats_full( deref( $data_r ) );
				
				@{ $info_r }{ keys %{ $stat } } = values %{ $stat };
				
				return $info_r;
                     },
         'robust'  => sub ($) { my $data_r = shift;
	 			my $info_r = shift_info( $data_r );
				my $stat   = &Anorman::Math::Common::stats_robust( deref( $data_r ) );
			
				@{ $info_r }{ keys %{ $stat } } = values %{ $stat };

				return $info_r;
			       }
         );
        
	defined (my $code = $METHOD{$method}) or $self->_error("Cannot calculate, no method such method");

        $self->apply($code,$data_r);
}


sub add_row_stats {

    # calculate statistics on all rows
    # returns an array of hashes, one for each row
    my $self = shift;
    my $method = shift;
    my $data_r = $self->rows;

    $self->calc_stats( $data_r, $method );
}

sub add_col_stats {
    # calculate statistics on all columns
    # returns a reference to an array of hashes, one for each column
    my $self = shift;
    my $method = shift;
    my $data_r = $self->cols;

    $self->calc_stats( $data_r, $method );
}

sub add_matrix_stats {
    # calculate statistics for the whole data matrix
    # returns a hash reference
    my $self   = shift;
    my $method = shift;
    my $data_r = $self->matrix;

    $self->calc_stats( $data_r, $method );
}

sub rows {
    my $self         = shift;
    my ($cols,$rows) = $self->dims;
    my @row_numbers  = defined $_[0] ? @_ : (1..$rows);
    my $ref          = [];

    foreach my $row_n(@row_numbers) {
        push @{ $ref }, [ $self->[0][$row_n], map { \$self->[$_][$row_n] } (1..$cols) ];
    }
    
    return $ref;
}

sub cols {
    my $self         = shift;
    my ($cols,$rows) = $self->dims;
    my @col_numbers  = defined $_[0] ? @_ : (1..$cols);
    my $ref          = [];

    foreach my $col_n(@col_numbers) {
        push @{ $ref }, [ $self->[$col_n][0], map { \$self->[$col_n][$_] } (1..$rows) ];
    }

    return $ref;
}

sub matrix {
	my $self         = shift;
	my ($cols,$rows) = $self->dims;
	my $ref          = [];

	push @{ $ref }, $self->[0][0];

	foreach my $col_n(1..$cols) {
	    foreach my $row_n(1..$rows) {
	        push @{ $ref }, \$self->[$col_n][$row_n];
	    }
	}
	
	return $ref;
}

sub row_slice {
    # generates rows sliced from column a to column b
    my $self = shift;
    my ($beg_c, $beg_r, $end_c, $end_r) = (@_);
    my ($cols,$rows) = $self->dims;

    if ( $beg_r < 1 || $beg_c < 1 || $end_r > $rows || $end_c > $cols) {
        $self->_error("Cannot slice: cell numbers ($beg_c,$beg_r) - ($end_c,$end_r): out of range in $cols x $rows matrix");
    }

    my $ref = [];

    foreach my $row_num($beg_r..$end_r) {
        push @{ $ref }, [ map { \$self->[$_][$row_num] } ($beg_c..$end_c) ];
    }

    return $ref;    
}

sub col_slice {
    # generates columns sliced from row a to b
        my $self = shift;
    my ($beg_c, $beg_r, $end_c, $end_r) = (@_);
    my ($cols,$rows) = $self->dims;
    
    if ( $beg_r < 1 || $beg_c < 1 || $end_r > $rows || $end_c > $cols) {
        $self->_error("Cannot slice: cell numbers ($beg_c,$beg_r) - ($end_c,$end_r): out of range in $cols x $rows matrix");
    }
    my $ref = [];

    foreach my $col_num($beg_c..$end_c) {
        push @{ $ref }, [ map { \$self->[$col_num][$_] } ($beg_r..$end_r) ];
    }

    return $ref;
}

sub deref {
    # dereferences a data structure so that an array of references is returned
    # as an array of scalar values and an array reference is returned as an array.
    # If a normal array has been passed it is returned unchanged
    if (ref($_[0][0]) eq 'SCALAR') {
        my @a = map { $$_ } @{$_[0]};
        return @a;
    } elsif (ref($_[0]) eq 'ARRAY') {
        return @{$_[0]};
    } else {
        return @_;
    }
}
sub row_info_to_col {
    # takes all row key/values pairs and creates a new data column from values
    my $self = shift;
    my $key  = shift;

    my @dims = $self->dims;
    my @idx  = $self->row_info;

    my @new_column = map { $_->{$key} } @idx;
    my $col_index  = { 'name' => $key, '_num' => (1 + $dims[0]) };
    
    unshift @new_column, $col_index;
    
    # delete the info entry that the column was made from
    foreach ( $self->row_info ) { delete $_->{$key} };

    # return the column or add to table depending on how the
    # function was called
    if (wantarray) {
        return @new_column;
    } else {
        $self->add_col(@new_column);
        $self->update_info;
    }
}

sub collapse_cols {
    # Adds all value from several columns into a single column
    # The first column number in the stack is the target column
    my $self     = shift;
    my @cols     = @_;
    my $target   = shift @cols;
    return unless @cols;
    
    my ($cols,$rows) = $self->dims;

    # Sanity check
    foreach (@cols) { $self->_error("column number $_ out of range in $cols by $rows table") if $_ > $cols };

    foreach my $row_n(1..$rows) {
        $self->[$target][$row_n] += sum (map { $_->[$row_n]  }@{ $self }[@cols]);
    }
    
    my @cols = reverse @cols;

    foreach (@cols) { splice @{ $self }, $_, 1 };
    $self->update_info;
}

sub collapse_rows {
	my $self = shift;
	my @rows = @_;
	my $target = shift @rows;

	return unless @rows;

	my ($cols,$rows) = $self->dims;

	# Sanity check
	foreach (@rows) { $self->_error("row number $_ out of range in $cols by $rows table") if $_ > $rows };

        @rows = sort { $b <=> $a } @rows;

	foreach my $col_n(1..$cols) {
            $self->[$col_n][$target] += sum ( @{ $self->[ $col_n ] }[ @rows ] );
	    foreach (@rows) { splice @{ $self->[ $col_n ] }, $_, 1 };
	}
	foreach (@rows) { splice @{ $self->[ 0 ] }, $_, 1 };

	$self->update_info;
}

sub row_info {
    my $self = shift;
    my ($cols,$rows) = $self->dims;
    my @row_numbers  = defined $_[0] ? @_ : (1..$rows);

    my $ref = [ @{ $self->[0] }[ @row_numbers ] ];

    return wantarray ? @{ $ref } : $ref;
}

sub col_info {
    my $self = shift;
    my @dims = $self->dims;

    my $ref = [ map { $self->[$_][0] } (1..$dims[0]) ];

    return wantarray ? @{ $ref } : $ref;

}
sub table_info {
    # returns info relating to the whole table
    # which is stored in cell (0,0) as a hash-reference
    my $self = shift;

    return $self->[0][0];
}

sub get_info_vals {
    # returns specific index values given a list of tids. 
    # If no list is provided values from all entries are returned
    my $self = shift;
    my $key  = shift;
    my @idx  = @_;

    $self->_error("No such key in index: $key" ) 
        unless grep { /$key/ } keys %{ $idx[0] };

    my @values = map { $_->{$key} } @idx;

    return wantarray ? @values : \@values;
}

sub add_row {
    my $self = shift;
    my ($cols,$rows) = $self->dims;
    my $row_len = $#_;

    if ($row_len != $cols) {
        $self->_error("Cannot add row. Length <$row_len> doesn't match number of columns <$cols>");
    }
    if (ref($_[0]) ne 'HASH') {
        $self->_error("A row was added to the table that did not contain an info cell");
    }

    my $col_num = 0;
    foreach my $cell(@_) {
        $self->[$col_num][$rows + 1] = $cell;
        $col_num++;
    }

}

sub add_col {
    my $self = shift;
    my ($cols,$rows) = $self->dims;
    my $col_len = $#_;

    if ($col_len != $rows) {
        $self->_error("Cannot add column. Length <$col_len> doesn't match number of rows <$rows>");
    }
    if (ref($_[0]) ne 'HASH') {
        $self->_error("A column was added to the table that did not contain an info cell");
    }
    
    push @{ $self }, \@_;
}

sub del_row {

}

sub del_col {
    my $self = shift;
    my ($cols,$rows) = $self->dims;
    my @remove_cols = sort { $b <=> $a } @_;
    return undef if @remove_cols < 1;

    foreach my $col_num(@remove_cols) {
        $self->_error("Invalid column number $col_num. Cannot delete") unless $col_num <= $cols;
        splice (@{ $self }, $col_num, 1);
    }
}

sub update_info {
    # updates the table info so that it matches observed values
    my $self = shift;

    my $info            = $self->table_info;

    # Get table dimensions
    my ($cols,$rows)    = $self->dims;

    $info->{'rows'}     = $rows;
    $info->{'cols'}     = $cols;

    # get all row keys from the first row index
    if ($rows) {
        $info->{'row_keys'} = [ sort grep { !/^_/ } keys %{ $self->[0][1] } ];
    }
    # build a "type array" showing which columns contain row metadata and which contain count data
    my @types = (('9'),('0') x (@{ $info->{'row_keys'} }), ('1') x $cols);
    
    $info->{'col_types'} = \@types;

    # overwrite indices
    foreach (1..$cols) { $self->[$_][0]->{'_num'} = $_ };
    foreach (1..$rows) { $self->[0][$_]->{'_num'} = $_ };
}

sub dims {
    my $self = shift;
    my ($cols,$rows) = ($#{$self},$#{$self->[0]});

    return ($cols,$rows);
}

sub shift_info {
    my $data_r = shift;
    return ref($data_r->[0]) eq 'HASH' ? shift @{ $data_r } : {};
}

sub check_dims {
    # only reads the header of a table to assess its dimensions
    my $self = shift;
    my $fn   = shift;
    my $line;

    open (my $FH, '<', $fn) or die "Could not check dimensions of table $fn, $!";
    
    $line = <$FH>;
    my $rows = $1 if $line =~ m/^%\s?(\d+)\s?$/;
    
    $line = <$FH>;
    my $cols = $1 if $line =~ m/^%\s?(\d+)\s$/;
    
    close $FH;

    return ($cols,$rows);
}

sub make_copy {
	my $self  = shift;
	my $ref   = shift;

	my $info_r = shift_info( $ref );
	my @row    = deref( $ref );

	return ($info_r, @row);
}
    
sub _error {
	shift;
	trace_error(@_);
}

1;
