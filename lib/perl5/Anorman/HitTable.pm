package Anorman::HitTable;

# May 2011, Anders Norman
# 
# major revision, Sep 2012
#
# a class for handling various data tables
# associated with search hits
#


use strict;
use Anorman::Common;

sub new {
	my $class = shift;
	my $self  = {};

	bless $self, $class;

	return $self;
}

sub open {
	my $self = shift;
	my $type = shift;
	my $file = shift;

	$self->_initialize( $file, $type );
}

sub get_record {
	my $self = shift;
	my $FH = $self->{'_fh'};

	my $line = '';
	while (defined ($line = <$FH>)) {
		next if $line =~ m/^#/;
		chomp $line;
		last;
	}
	if ($line) {
		my $hash_r = $self->parse_line( $line );
		return $hash_r;	
	} else {
		return 0;
	}
}

sub stored_records {
	my $self = shift;

	return wantarray ? @{ $self->{'_records'} } : $self->{'_records'} ;
}

sub uniq_records {
	my $self = shift;
	return @{ $self->{'_records'} }[ @{ $self->{'_uniq'} }{ @{ $self->{'_order'} } } ];
}

sub store_record {
	my $self     = shift;
	my $r        = shift;
	my $uniq_key = shift;
	
	$uniq_key    = defined $uniq_key ? $uniq_key : $r->{'q_id'};
	
	my $uniq_r      = $self->{'_uniq'};
	my $input_order = $self->{'_order'};
	my $records     = $self->{'_records'};
	my $index       = $#{ $records } + 1;

	my $bit_score = $r->{'bit_score'};

	#warn "Storing $uniq_key\n";

	if (exists $uniq_r->{ $uniq_key }) {
		my $old_bit_score = $records->[ $uniq_r->{ $uniq_key } ]->{'bit_score'};
		#warn "Record: $uniq_key already exists\n";
		if ($bit_score > $old_bit_score) {
			#warn "$bit_score > $old_bit_score. Record replaced\n";
			$uniq_r->{ $uniq_key } = $index;
			push @{ $input_order }, $uniq_key;
		} else {
			#warn "Old record was retained\n";
		}
	} else {
		#warn "New unique record created\n";
		$uniq_r->{ $uniq_key } = $index;
		push @{ $input_order }, $uniq_key;
	}
	push @{ $records }, $r;
}

sub fetch_record {
	my $self  = shift;
	my $index = shift;

	return $self->{'_records'}->[ $index ]
}

sub _sort_records {
	my $self = shift;

	@{ $self->{'_records'} } = sort { $b->{'bit_score'} <=> $a->{'bit_score'}  } 
		@{ $self->{'_records'} };

}

sub parse_line {
	my $self = shift;
	my $line = shift;
	my $p    = $self->{'_parser'};

	my @fields = @{ $p->{'fields'} };
	my @keys   = @{ $p->{'keys'} };
	my $regex  = $p->{'fs'};
	my @split  = split( $regex, $line);
	
	my %record;
	@record{ @keys } = @split[ @fields ];
	
	if ($p->{'code'}) {
		$p->{'code'}->(\%record, \@split );
	}
	return \%record;
}

sub blast_type {
	my @fields    = (0..11);
	my @keys      = qw/q_id s_id pct_id aln_len mistmatches gap_open q_beg q_end s_beg s_end eval bit_score/;
	my %package   = ( 'fields' => [ @fields ], 'keys' => [ @keys ], 'fs' => qr/\t/ );

	return \%package;
}

sub hmmscan_target_hit_type {
	my @fields  = (0..6);
	my @keys    = qw/s_id s_acc q_id q_acc eval bit_score bias s_desc/;
	my $code    = sub { $_[0]->{'s_desc'} = join (" ", @{ $_[1] }[ 18..$#{ $_[1] } ] ) };
	my %package = ( 'fields' => [ @fields ], 'keys' => [ @keys ], 'fs' => qr/\s+/, 'code' => $code );

	return \%package;
}

sub hmmscan_domain_hit_type {
	my @fields = (0..9,15..18); 	
	my @keys   = qw/s_id s_acc s_len q_id q_acc q_len eval bit_score bias dom_num s_beg s_end q_beg q_end s_desc/;
	my $code   = sub{ $_[0]->{'s_desc'} = join (" ", @{ $_[1] }[ 22..$#{ $_[1] } ]) };

	my %package = ( 'fields' => [ @fields ], 'keys' => [ @keys ], 'fs' => qr/\s+/, 'code' => $code );
	
	return \%package;
}

sub keys {
	my $self = shift;

	return @{ $self->{'_parser'}->{'keys'} };
}

sub _initialize {
	my $self        = shift;
	my $format      = shift;
	my $file        = shift;

	my %parse_types = ( 
		    'blast'      => \&blast_type,
                    'hmmscan'    => \&hmmscan_target_hit_type,
                    'hmmscandom' => \&hmmscan_domain_hit_type
                  );
	
	$self->_error ("ERROR: uknown table type \"$format\"", 1) unless $parse_types{ $format };
	
	my $FH;

	if ($file) {
		open ($FH, '<', $file) or die "ERROR: could not open $file, $1";
	} else {
		$FH = \*STDIN;
	}

	$self->{'_fh'}      = $FH;
	$self->{'_parser'}  = $parse_types{ $format }->();
	$self->{'_file'}    = $file;
	$self->{'_records'} = [];
	$self->{'_uniq'}    = {};
	$self->{'_order'}   = [];

}

sub _error {
	my $self  = shift;

	trace_error( @_ );
}
1;
