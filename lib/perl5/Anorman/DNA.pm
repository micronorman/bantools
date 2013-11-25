package Anorman::DNA;

use strict;
use warnings;

use Exporter;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);

@EXPORT_OK = qw(
	reverse_complement
	clean_nt
	gc_content
	mono_nt_freq
	N_vs_nonN
	non_DNA
);

%EXPORT_TAGS = ( all => [ @EXPORT_OK ] );

sub reverse_complement {
	my $seq = shift;

	return undef if not defined $seq;
	$seq =~ tr/ACTGactg/TGACtgac/;
	return reverse $seq;
}

sub clean_nt {
	my $seq = shift;

	return undef if not defined $seq;

	$seq = uc($seq);
	$seq =~ tr/[^ACTG]//;

	return $seq;
}


sub gc_content {
	my $GC = $_[0] =~ tr/GgCc/GgCc/;
	my $AT = $_[0] =~ tr/AaTt/AaTt/;

	return ($GC/($GC + $AT));
}

sub mono_nt_freq {
	my $length = length $_[0];
	my @freqs = ();

	$freqs[0] = ($_[0] =~ tr/Aa/Aa/) / $length;
	$freqs[1] = ($_[0] =~ tr/Cc/Cc/) / $length;
	$freqs[2] = ($_[0] =~ tr/Tt/Tt/) / $length;
	$freqs[3] = ($_[0] =~ tr/Gg/Gg/) / $length;

	return @freqs;
}

sub N_vs_nonN {
	my $N = $_[0] =~ tr/Nn/Nn/;

	return ($N / length $_[0]);
}

sub non_DNA {
	my $Non_DNA = $_[0] =~ tr/AaCcTtGgRrYySsWwKkMmBbDdHhVvNn.-/AaCcTtGgRrYySsWwKkMmBbDdHhVvNn.-/c;
}

#### EXPERIMENTAL #####
sub pack_2bit {
	my %dna2val = ('T' => 0, 'C' => 1, 'G' => 2, 'A' => 3 );
	my $bits   = '';
	my $seq    = shift;
	my $pos    = 0;

	while (my $nt = substr $seq, $pos, 1 || 0) {
		vec ($bits, $pos, 2) = $dna2val{ $nt };
		$pos++;
	}
	return $bits;
}

sub unpack_2bit {
	my @val2dna = ( 'T', 'C', 'G', 'A' );
	my $deq_seq = '';
	my $string  = shift;
	my $length  = length $string;
	my $pos     = 0;	

	while ($pos < (4 * $length)) { 
		my $bval = vec( $string, $pos, 2);
        	$deq_seq .= $val2dna[ $bval ];
		$pos++;
	}
	return $deq_seq;
}

sub reverse_complement_2bit {
	my $rev_seq = '';
	my $bits = shift;
	my $unpacked_length = 4 * (length $bits);
	
	for (my $pos = $unpacked_length - 1; $pos >= 0; $pos--) {
		vec ($rev_seq, $pos, 2) = vec($bits, $unpacked_length - ($pos + 1),2);
	}
	return ~$rev_seq;
}

1;
