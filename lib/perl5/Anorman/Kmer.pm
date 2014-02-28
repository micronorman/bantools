package Anorman::Kmer;

use strict;

use Anorman::Common;
use Anorman::DNA qw(mono_nt_freq);

our $VERSION = 0.8;

sub new {
	my $class = shift;
	my $ksize = defined $_[0] ? shift : 4;

	# Check kmer sizes
	trace_error ("ERROR: only Kmer-sizes 1-127 allowed\n" ) 
		if ( $ksize < 1 || $ksize > 127 );
	
	my $self  = bless ( {}, ref($class) || $class);
	
	$self->{'kmers'}  = {};
	$self->{'ksize'}  = $ksize;
	$self->{'ksum'}   = 0;
	
	return $self;
}

sub init {
	my $self = shift;
	undef @{ $self->{'_sort_cache'} };
	delete $self->{'_sort_cache'};
}


sub seq {

	# loads a new sequence into the cache or returns the existing one
	my $self = shift;

	if (defined $_[0]) {
		$self->{'seq'} = shift;

		# reset all counters
		%{ $self->{'kmers'} }         = ();
		%{ $self->{'_mono_nt_freq'} } = ();
		$self->{'ksum'}               = 0;

		$self->_count_kmers;
	} else {
		return $self->{'seq'};
	} 

}

sub ksize {
	my $self = shift;
	my $k    = shift;

	if ($k) {
		$self->{'ksize'} = $k;
		$self->init;
		return;
	}

	return $self->{'ksize'};
}

sub relative_kmer_abundance {

	my $self  = shift;
	my $kmer  = shift;

	return undef unless defined $self->{'seq'};
	return 0 unless exists $self->{'kmers'}->{ $kmer };

	my @KMER = split //, $kmer;

	unless (%{ $self->{'_mono_nt_freq'} }) {
		# analyze mononucleotide frequencies
		my %mono_nt_freq        = ();
		@mono_nt_freq{ qw/A C T G/ } = mono_nt_freq( $self->{'seq'} );

		$self->{'_mono_nt_freq'} = \%mono_nt_freq;
	}		
	
	my $f = 1;
	foreach my $nt(@KMER) {
		$f *= $self->{'_mono_nt_freq'}->{ $nt };
	}

	return $self->{'kmers'}->{ $kmer } / ($self->{'ksum'} * $f); 
}

sub kmer_freq {
	my $self  = shift;
	my $kmer  = shift;

	return undef unless defined $self->{'seq'};
	return undef unless exists $self->{'kmers'}->{ $kmer };

	return $self->{'kmers'}->{ $kmer } / $self->{'ksum'}; 
}

sub sorted_kmers {
	# Dummy. Nothing to do
}

sub get_raw_counts {
	my $self   = shift;

	return wantarray ? map { $_ || 0 }@{ $self->{'kmers'} }{ $self->sorted_kmers } : $self->{'kmers'};
}

sub number_of_kmers {
	my $self = shift;
	return scalar keys %{ $self->{'kmers'} };
}

sub ksum {
	my $self = shift;
	return $self->{'ksum'};
}

sub _pick_kmer {
	my $self = shift;
	my $pos  = shift;
	return substr ($self->{'seq'}, $pos, $self->{'ksize'} ) || undef;
}

sub _reset_counts {
}

sub _count_kmers {
	my $self  = shift;

	my $pos = 0;

	while (defined (my $kmer = $self->_pick_kmer($pos) ) ) {
		
		# skip illegal Kmers entirely
		if ($self->$kmer =~ m/[^ACTG]/) {
			$pos += $self->{'ksize'};
			next;
		} 

		my $rckmer = reverse $kmer;
		$rckmer =~ tr/ACTG/TGAC/;

		$kmer = $kmer cmp $rckmer ? $kmer : $rckmer;
		$self->{'kmers'}->{ $kmer }++;
		
		$pos++;
		$self->{'ksum'}++;
	}
}

1;

package Anorman::Kmer::Cache;

use strict;
use parent -norequire,'Anorman::Kmer';

sub new {
	my $class = shift;
	my $self  = $class->SUPER::new(@_);
	
	$self->{'_kmer_cache'} = {};
	$self->init;

	return $self;
}

sub init {
	my $self = shift;
	$self->SUPER::init;
	$self->{'_kmerid'}           = 0;
	%{ $self->{'_kmer_cache'} }  = ();

	trace_error("Cannot cache kmers larger than 7 bp") if $self->{'ksize'} > 7;
	$self->_cache_all_kmers( $self->{'ksize'} );
}

sub _count_kmers {
	my $self  = shift;

	my $pos = 0;

	while (defined (my $kmer = $self->_pick_kmer($pos)) ) {
		
		if (exists $self->{'_kmer_cache'}->{ $kmer }) {
			$self->{'kmers'}->{ $kmer }++;
		} else {
			$kmer = reverse $kmer;
			$kmer =~ tr/ACTG/TGAC/;

			if (exists $self->{'_kmer_cache'}->{ $kmer }) {
				$self->{'kmers'}->{ $kmer }++;
			} else { # Illegal Kmer trap, skip
				 # past entire Kmer when they occur
				$pos += $self->ksize;
				next;
			}
		}

		$pos++;
		$self->{'ksum'}++;
	}
}

sub sorted_kmers {
	my $self = shift;
	if (exists $self->{'_sort_cache'}) {
		return @{ $self->{'_sort_cache'} };
	} else {
		$self->{'_sort_cache'} = [ 
			sort { 
				$self->{'_kmer_cache'}->{ $a } 
				<=> 
				$self->{'_kmer_cache'}->{ $b } 
			     } keys %{ $self->{'_kmer_cache'} }
		];

		return @{ $self->{'_sort_cache'} };
	}
}

sub _cache_all_kmers {
	# Recursive routine that generates all posible Kmer-pairs 
	# (represented by one pair-member) of a specified size

	my $self = shift;
	my $k    = shift;
	my $kmer = defined $_[0] ? shift : '';

	unless ($k) {
		my $rckmer = reverse $kmer;
		$rckmer =~ tr/ACTG/TGAC/;

		unless (exists $self->{'_kmer_cache'}->{ $rckmer }) {
			$self->{'_kmerid'}++;
			$self->{'_kmer_cache'}->{ $kmer } = $self->{'_kmerid'};
		}
		return;
	}

	foreach my $nt(qw/A T C G/) {
		$self->_cache_all_kmers( $k-1, $kmer . $nt);
	}
}
