#!/usr/bin/env perl
use strict;
use warnings;

use Anorman::Fasta;
use Anorman::Kmer;
use Anorman::Counts;
use Anorman::Seq;
use Anorman::Math::Common;

use Getopt::Long;

my (
    $FILE,
    $HELP,
    $KSIZE,
    $VERBOSE,
    $MIN_LENGTH,
    $MAX_LENGTH,
    $METHOD,
    $SUBDIVIDE,
    $CHUNK_SIZE,
    $WINDOW_SIZE,
    $OUTPUT
    );

$MIN_LENGTH      = 500;
$MAX_LENGTH      = 1<<30;
$KSIZE           = 4;

$METHOD = 'raw';

&GetOptions (   "help"        => \$HELP,
	        "input=s"     => \$FILE,
		"kmersize=i"  => \$KSIZE,
                "verbose"     => \$VERBOSE,
		"method=s"    => \$METHOD,
		"minlen=i"    => \$MIN_LENGTH,
		"maxlen=i"    => \$MAX_LENGTH,
		"subdivide=i" => \$CHUNK_SIZE,
		"winsize=i"   => \$WINDOW_SIZE,
		"output=s"    => \$OUTPUT
	      );

if ($CHUNK_SIZE) {
	$SUBDIVIDE   = 1;
	if ($WINDOW_SIZE) {
	    #$OUT_PREFIX .= ".win$WINDOW_SIZE" if $OUT_PREFIX;
	} else {
	    $WINDOW_SIZE = $CHUNK_SIZE;
	}
	
	if ($VERBOSE) {
		warn "Subdivision enabled:\n";
		warn "Chunk size              = $CHUNK_SIZE\n";
		warn "Sliding window size     = $WINDOW_SIZE\n";
		warn "Minimum sequence length = $MIN_LENGTH\n";
		warn "Maximum sequence length = $MAX_LENGTH\n";
	}
}

# Initiate objects
my $fasta_o  = Anorman::Fasta->new;
my $table_o  = Anorman::Counts->new;
my $kmer_o   = Anorman::Kmer::Cache->new($KSIZE);
my $seq_o    = Anorman::Seq->new;

# Add kmer columns to table
foreach my $kmer($kmer_o->sorted_kmers) {
		
	my $col_info   = { 'name' => $kmer };
	my @new_column = ( $col_info );

	$table_o->add_col(@new_column);
}

$table_o->update_info;

warn "Counting Kmers ($KSIZE nt)\n" if $VERBOSE;

my $tid = 0;

$fasta_o->open( $FILE ) if defined $FILE;

my @lengths;

while ($fasta_o->iterator) {
	
	# Pull sequence info from fasta entry
	my $name   = $fasta_o->header;
	my $length = $fasta_o->length;
	my $seq    = $fasta_o->seq;

	next if $length < $MIN_LENGTH;

	# Transfer sequence info to seq object
	my @keys             = qw/tid name length seq/;
	@{ $seq_o }{ @keys } = ( $tid,$name,$length,$seq );
	
	$tid++;
	
	if ($SUBDIVIDE && $length >= ($CHUNK_SIZE + $MIN_LENGTH)) {
		foreach my $subseq_r( $seq_o->subdivide( $CHUNK_SIZE, $WINDOW_SIZE, $MIN_LENGTH )) {
			&add_kmer_counts_to_table( $subseq_r );
			push @lengths, $subseq_r->{'length'};
		}
	} else {
		&add_kmer_counts_to_table( $seq_o );
		push @lengths, $length;
	}
	print STDERR "\r$tid sequences processed" if $VERBOSE;
}

$fasta_o->close if defined $FILE;

# Finish off
$table_o->update_info;


if ($VERBOSE) {
	my $stats = Anorman::Math::Common::stats_full(@lengths);
	my $rows  = $table_o->[0][0]->{'rows'};
	warn "\n$rows datapoints created\n" if $VERBOSE;
	warn "Fragment lengths: $stats->{'_min'} - $stats->{'_max'} (median length: $stats->{'_median'})\n";
}

# Write output
$table_o->print( { 'file' => $OUTPUT } );

#== subsequences ==
sub add_kmer_counts_to_table {
	
	my $seq_r    = shift;
	my %row_info = ();
	my @row_data = ();
	my @keys     = qw/name length/;

	$kmer_o->seq( $seq_r->{'seq'} );

	if ($METHOD eq 'freq') {
		@row_data = map { $kmer_o->kmer_freq( $_ ) } $kmer_o->sorted_kmers; 
	} elsif ($METHOD eq 'relative') {
		@row_data = map { $kmer_o->relative_kmer_abundance( $_ ) } $kmer_o->sorted_kmers;
	} else {
		@row_data = $kmer_o->get_raw_counts;
	}

	# transfer sequence info to row info
	@row_info{ @keys } = @{ $seq_r }{ @keys };

	# create new row in table
	$table_o->add_row( \%row_info, @row_data );
}

=pod

=head1 NAME

calc_kmer_freq.pl -- Calculates k-mer frequencies of nucleotide sequences

=head1 SYNOPSIS


=cut

