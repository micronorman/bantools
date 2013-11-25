package Anorman::Seq;

#use Bit::Vector;

sub new {
	my ($self,$seq) = @_;
	$seq = { 'name' => '', 'length' => 0, 'seq' => '' } unless defined $seq;
	return bless ($seq, ref($self) || $self);
}

sub subdivide {
	my $self = shift;
	my ($chunk_size, $window_size, $min_leftover_length) = @_;
	
	my $beg     = 0;
	my $count   = 1;
	my @subseqs = ();
	
	# Cut slices and make new objects
	while (defined (my $subseq_obj = $self->slice($beg,$chunk_size, $min_leftover_length))) {
		
		my $seqend  = $beg + $subseq_obj->{'length'};
		my $seqbeg  = $beg + 1;

		die "Illegal chunk size $chunk_size" if $chunk_size <= 2;
		
		$subseq_obj->{'name'}    =~ s/^(\S+)(?:\s+.*)?$/$1_$count $seqbeg-$seqend/;
		$subseq_obj->{'_subseq'} = $count;
		$subseq_obj->{'_parent'} = $self->{'name'};
		$subseq_obj->{'_beg'}    = $seqbeg;

		push (@subseqs,$subseq_obj);
		
		$beg += $window_size;
		$count++;
	}
	return wantarray ? @subseqs : \@subseqs;
}

sub slice {
	# Cuts a slice out of a seq object
	# returns a new seq object

	my $self = shift;
	my $length = $self->{'length'};
	my ($beg,$offset,$minlen) = @_;
	if (!defined $minlen) { $minlen = $offset };
	my $end = $beg + $offset - 1;

	# allow smaller slice to be cut if it exceeds a minimum defined length 
	if ($end >= $length) {
	    if ($minlen >= ($length - $beg)) {
                return undef;
	    } else {
                $end = $length - 1;
		$offset = $length - $beg;
	    }
	}

	my %slice = ();

	while (my ($key,$value) = each %{ $self }) {

		# Slice arrays (e.g. depth or qual values)
		if (ref($value) eq 'ARRAY') {
			next if $length != @{ $value };
			my @arslice = @{ $value }[$beg..$end];
			$slice{ $key } = [ @arslice ];
		# Slice bitvectors
		} elsif (ref($value) eq 'Bit::Vector') {
			my $BV_slice = Bit::Vector->new($offset);
			$BV_slice->Interval_Copy($value,0,$beg,$offset);
			$slice{ $key } = $BV_slice;
		# Slice strings (e.g. nt or aa  sequence)
		} else {
			if ($length != length $value) {
				$slice{ $key } = $value;
				next;
			}
			my $strslice = substr( $value, $beg, $offset);
			$slice{ $key } = $strslice;
		};
	}
	$slice{'length'} = $offset;
	$slice{'name'}   = $self->{'name'};
	
	my $slice_ref = \%slice;
	return $slice_ref;
}

1;
