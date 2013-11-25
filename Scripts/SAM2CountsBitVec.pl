#!/usr/bin/env perl

use strict;
use warnings;

use List::Util qw(sum);
use Getopt::Long;
use Bio::DB::Sam;
use Bit::Vector::Overload;

use Anorman::Counts;
use Anorman::Seq;

use vars qw($FILE $HELP $VERBOSE $NO_NORMALIZE $SUBDIVIDE $GFF_FILE $CHUNK_SIZE $WINDOW_SIZE $OUTPUT);

my $BamObj         = [];
my $ROW_INDEX      = [];
my $GENE_MAP       = {};

# Defaults
my $MIN_LENGTH     = 500;
my $MAX_LENGTH     = 1<<30;
my $POS_COV_THRESH = 0.0;

# parse command line options
&GetOptions (   "help"             => \$HELP,
                "verbose"          => \$VERBOSE,
		"contig_file|f=s"  => \$FILE,
                "minlen=i"         => \$MIN_LENGTH,
		"maxlen=i"         => \$MAX_LENGTH,
                "subdivide=i"      => \$CHUNK_SIZE,
		"pos_cov_thresh=f" => \$POS_COV_THRESH,
                "gfffile=s"        => \$GFF_FILE,
                "output=s"         => \$OUTPUT
             );

if ($CHUNK_SIZE && $GFF_FILE) {
    die "Cannot perform subdivision and gene division at the same time";
} elsif ($CHUNK_SIZE) {
    $SUBDIVIDE   = 1;
    $WINDOW_SIZE = $CHUNK_SIZE unless $WINDOW_SIZE;
}

die "No BAM files specified" unless @ARGV;

# Prepare a an object refrence for each BAM file
foreach my $FILE_NAME(@ARGV) {
    my $hash_r = { 'fn' => $FILE_NAME, 'bam' => undef, 'index' => undef };
    push @{$BamObj}, $hash_r;
}

my %INCLUDE;

if ($FILE) {
	open (my $FH, '<', $FILE) or die "Could not read $FILE for opening, $!";
	while (defined (my $line = <$FH>)) {
		chomp $line;
		$line =~ s/^(\S+).*$/$1/;
		$INCLUDE{ $line } = 1;
	}
	close $FH;
}

# Fetch bam header from first BAM file to create index
warn "[ Fetching BAM header ]\n" if $VERBOSE;

$BamObj->[0]->{'bam'} = Bio::DB::Bam->open($BamObj->[0]->{'fn'});

my $bam_header        = $BamObj->[0]->{'bam'}->header;
my $target_names      = $bam_header->target_name;
my $target_lengths    = $bam_header->target_len;
my $n_targets         = $bam_header->n_targets;
my $tid               = 0;
my $seqs_to_subdivide = 0;
my $seqs_w_genes      = 0;
my $number_of_genes   = 0;
my $number_of_bases   = 0;

warn "[ Found $n_targets sequences ]\n" if $VERBOSE;

if ($FILE) {
	my $n = scalar keys %INCLUDE;
	warn "[ $n sequences in $FILE to be included ]\n";
}
# Make a gene map if a gff-file was provided

if ($GFF_FILE) {
    warn "[ Importing gene table from $GFF_FILE ]\n" if $VERBOSE;
    $GENE_MAP = &make_gene_map_from_gff_file($GFF_FILE);
}

warn "[ Building sequence index ]\n" if $VERBOSE;

while ($tid < $n_targets) {
    my $seqid  = $target_names->[$tid];
    my $length = $target_lengths->[$tid];
    
    if ($length >= $MIN_LENGTH && $length <= $MAX_LENGTH) {
    	
	if ($FILE) {
		if (!exists $INCLUDE{ $seqid }) {
			$tid++;
			next;
		}
	}

        my $index_entry = { '_tid'   => $tid, 
                            'length' => $length, 
                            'name'   => $seqid,
                          };

        # flag sequences to be subdivided
        if ($SUBDIVIDE && $length >= ($CHUNK_SIZE + $MIN_LENGTH)) {
            $index_entry->{'subdivide'} = 1;
            $seqs_to_subdivide++;
        } elsif ($GFF_FILE) { 
	    if (exists $GENE_MAP->{$seqid}) {
                $index_entry->{'genes'} = $GENE_MAP->{$seqid};
                $number_of_genes += (@{ $GENE_MAP->{$seqid} } / 2);
                $seqs_w_genes++;
	    } else {
                $tid++;
		next;
	    }
        }
        
        $number_of_bases += $length;
        push @{$ROW_INDEX}, $index_entry; 
    }
    $tid++;

}

if ($VERBOSE) {
    warn "[ Removed " . ($n_targets - scalar @{$ROW_INDEX}) .
    " < $MIN_LENGTH bp sequences. " . scalar @{ $ROW_INDEX } . " left ]\n";
    warn "[ $seqs_to_subdivide sequences will be subdivided ]\n"
        if $seqs_to_subdivide;
    warn "[ $seqs_w_genes sequences contained genes. Total number of genes $number_of_genes ]\n"
        if $seqs_w_genes;
}

undef $bam_header; 
undef $GENE_MAP;

# Fill BAM objects from each bam file
foreach my $h(@$BamObj) {
    $h->{'index'} = Bio::DB::Bam->index($h->{'fn'},1);
    $h->{'bam'}   = Bio::DB::Bam->open($h->{'fn'}) 
        unless defined $h->{'bam'};
}

# Initialize table data structure
my $table  = Anorman::Counts->new;
my $info_r = $table->table_info;
my $col_n  = 0;

# Iterate through each BAM file
foreach my $ref_i(@$BamObj) {
    $col_n++;
    
    my @column          = ();
    my $row_n           = 0;
    my $progress        = 0;
    my $prog_bar_length = 68;

    my ($sample,$bam,$index) = @{ $ref_i }{ qw/fn bam index/ };

    # get sample name from bam filename (same as POSIX basename)
    $sample      =~ s!^(?:.*/)?(.+?)(?:\.[^.]*)?$!$1!;

    push (@column, { 'name' => $sample, '_num' => $col_n } );

    warn "[ Processing $sample ]\n" if $VERBOSE;    
    
    # assemble counts from indexed sequences sequence
    foreach my $ref_j(@{$ROW_INDEX}) {
        
	my @new_rows   = ();
        my $row_info   = {};

	#NOTE: A check that the bam entry matches the index should be inserted here

        # call the coverage function from BAM-library
        $ref_j->{'_depth'} = $index->coverage($bam, $ref_j->{'_tid'},0, $ref_j->{'length'},0,1<<30);
	
	# make coverage mask
	my $local_cov_mask = &make_cov_mask( $ref_j->{'_depth'} );
        
	$ref_j->{'_global_coverage_mask'} = Bit::Vector->new( $ref_j->{'length'} ) if $col_n == 1;
	$ref_j->{'_local_coverage_mask'}  = Bit::Vector->new_Bin( $ref_j->{'length'}, $local_cov_mask );

        # extract subsequences or genes if requested
	if ($GFF_FILE) {
	    @new_rows = &add_gene_counts( $ref_j ) if $ref_j->{'genes'};
        } elsif ($ref_j->{'subdivide'}) {
            my $seq_obj = Anorman::Seq->new( $ref_j );
            @new_rows = $seq_obj->subdivide($CHUNK_SIZE,$WINDOW_SIZE,$MIN_LENGTH);
        } else {
            @new_rows = ($ref_j);
        }

	# add new data to table
        foreach my $row_r(@new_rows) {
            $row_n++;
	    my $base_count = 0;
	    
	    if ($col_n == 1) {
                my $info_r = $row_r;
                $info_r->{'_num'} = $row_n;
                $table->add_row($info_r);
            }
	    
	    my $pos_cov = $row_r->{'_local_coverage_mask'}->Norm() / $row_r->{'length'};

            if ($pos_cov >= $POS_COV_THRESH) {
	        $base_count = sum(@{ $row_r->{'_depth'} });
		$table->[0][$row_n]->{'_global_coverage_mask'} |= $row_r->{'_local_coverage_mask'};
	    }
		
	    delete $row_r->{'_depth'};
	    push (@column, $base_count);
        } 
        
        # Display a progress bar in verbose mode
        if ($VERBOSE) {
            my $completed   = int ( ($progress / $number_of_bases) * $prog_bar_length );
            my $current     = int ( ($ref_j->{'length'} / $number_of_bases) * $prog_bar_length );
            my $space       = $prog_bar_length - $current - $completed;

            print STDERR "\r0% [ " . 
                         "=" x $completed . 
                         "+" x $current . 
                         " " x $space . 
                         " ] 100%";
            $progress += $ref_j->{'length'};
        }
    }
    $table->add_col(@column);
    print STDERR "\r" . " " x 80 . "\r" if $VERBOSE;
}

foreach ($table->row_info) { $_->{'pos_cov'} = $_->{'_global_coverage_mask'}->Norm() / $_->{'length'} };

warn "Done\n";

$table->update_info;
$table->print( { 'file' => $OUTPUT } );

#=========== SUBROUTINES ===============

sub make_gene_map_from_gff_file {
    # parses a gff file and returns a hash of gene coordinates
        my $fn = shift;
        return undef if !defined $fn;

        my %GFFMAP   = ();

        open (my $FH, '<', $fn) or die "Could not open $fn, $!";

        warn "WARNING: File $fn has no gff header!\n" if not <$FH> =~ m/^##gff/;

        while (defined (my $line = <$FH>)) {
                next if $line =~ m/^#/;
                chomp $line;

                my @fields = split (/\t/, $line);
        my ($seqid,$beg,$end)  = @fields[0,3,4];
        
                push (@{ $GFFMAP{$seqid} }, ($beg,$end));
        }
        close $FH;

        return \%GFFMAP;
}

sub make_cov_mask {
	# create a position coverage mask
	my $a_ref = shift;
	return undef unless ref $a_ref eq 'ARRAY';
	
	my $mask = '';
	
	foreach my $depth(@{ $a_ref }) {
            $mask .= $depth ? 1 : 0; 
        }

	return $mask;
}

sub add_gene_counts {
	my $o_ref   = shift;
	my @a       = ();
	my $seq_obj = Anorman::Seq->new( $o_ref );
	my @genes   = @{ $o_ref->{'genes'} };
	my $counter = 1;

	while (my ($gene_beg,$gene_end) = splice (@genes,0,2)) {
	    my $index  = $gene_beg - 1;
	    my $offset = $gene_end - $gene_beg;
	    my $subseq_r = $seq_obj->slice($index,$offset);
	
	    $subseq_r->{'name'} =~ s/^(\S+)(?:\s+.*)?$/$1_$counter $gene_beg-$gene_end/;
	    $subseq_r->{'_subseq'} = $counter;
	    
	    $counter++;

	    push @a, $subseq_r;
	}
	return @a;
} 
