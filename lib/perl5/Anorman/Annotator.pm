package Anorman::Annotator;

BEGIN {
	require 5.012.004;
}

use Anorman::Common;
use Anorman::Common::Temp;

use File::Copy;

our $VERSION         = 0.4;
our $DEBUG           = 1;
our $HMM_DB_DIR = "/home/anorman/Bio/db";

sub DESTROY {
	my $self = shift;
	$self->_delete_tmp_files;
}   

sub new { 
	my $class      = shift;
	my $options    = shift;

	my $self  = {};
	bless $self, $class;
	
	$self->_parse_options;

	return $self;
}

sub run_pipeline {
	my $self   = shift;	
	my $input  = shift;
	my $output = shift;

	my $FH = \*STDOUT;

	my ($gf_o, $qp_o, $tmp_dir, $tmp_input) = $self->_initialize_pipeline( $input );

	$gf_o->run($tmp_input,$tmp_dir);
	my ($genes, $aa_out ) = $gf_o->get_gene_features;

	$qp_o->run( $aa_out, $tmp_dir );
	my $proteins = $qp_o->get_protein_features;

	if (defined $output) {
		open ($FH, '>', $output) or $self->_error("Could not open $output for writing, $!");
	}

	while (my ($seqid, $h) = each %{ $genes->{'seq_index'} } ) {

		foreach my $gene_feat( @{ $h->{'features'} }) {
			my @keys = qw/source type start end score strand frame/;
			my @fields = ($seqid, @{ $gene_feat }{ @keys });
			#my @attributes = join (';', @{ $gene_feat->{'attributes'} });
			print join ("\t", @fields), "\n";

			if (defined (my $prot_feats = $proteins->{ $gene_feat->{'seqid'} })) {
				foreach my $feat(@{ $prot_feats }) {
					my $beg = $fields[3] + 3 * $feat->{'q_beg'};
					my $end = $fields[3] + 3 * $feat->{'q_end'};
					
					# NOTE: needs to be proper gff, doesn't import right into Table
					print $FH "$seqid\t$feat->{'source'}\t$feat->{'type'}\t$beg\t$end\t$feat->{'bit_score'}\t$fields[6]\t.\tnote=\"$feat->{'s_desc'}\"\n";
				}
			}
		}
	}

	close $FH if $output;
}

sub number_of_genes {
	my $self = shift;
	return scalar keys %{ $self->{'gene_index'} };
}

sub number_of_seqs {
	my $self = shift;
	return scalar keys %{ $self->{'seq_index'} };
}

sub number_of_seqs_w_genes {
	my $self = shift;
	my $seqs = 0;
	foreach (values %{ $self->{'seq_index'} }) {
		$seqs++ if exists $_->{'features'}
	}
	return $seqs;
}

sub get_aa_seq {
	my $self   = shift;
	my $seq_id = shift;
	
	(exists $self->{'gene_index'}->{ $seq_id } || $self->_error( "No such gene found ($seq_id)") );

	my $seq = $self->_seq_fetcher( $seq_id, 'aa' );
}

sub get_nt_seq {
	my $self = shift;
	my $seq_id = shift;

	(exists $self->{'gene_index'}->{ $seq_id } || $self->_error( "No such gene found ($seq_id)") );

	my $seq = $self->_seq_fetcher( $seq_id, 'nt' );
}

sub coding_vs_noncoding {
	my $self = shift;

}

sub genes_list {
	my $self = shift;

	# Iterate through features in each sequence
	# and produce a list of genes
	# returns an array
	my @genes = map { $_->{'seqid'}  }
		    map { @{ $_->{'features'} } } 
		    sort { $a->{'seqnum'} <=> $b->{'seqnum'} } 
		    values %{ $self->{'seq_index'} };
	
	return @genes;
}

sub seqs_list {
	my $self = shift;
	my @seqs = map { $_->{'seqhdr'} } 
			grep { $_->{'transl_table'} != 11 }
			sort { $a->{'seqnum'} <=> $b->{'seqnum'} }
			values %{ $self->{'seq_index'} };
	return @seqs;
}

sub print_features {
	my $self = shift;
	
	while (my ($k, $v) = each %{ $self }) {
		my @keys    = qw/q_id source type q_beg q_end bit_score s_desc/;
		
		foreach my $feat(@{ $v }) {
			print join ("\t",  @{ $feat }{ @keys } ), "\n";
		}
	}
}

sub _parse_options {
	my $self = shift;
	
	warn "Eventually, some cool stuff will happen here...\n";
}

sub _initialize_pipeline  {
	my $self    = shift;
	my $input   = shift;
	my $options = shift;

	# create temporary working directory 
	my $tmp_dir = &Anorman::Common::Temp::create_dir;
	
	$self->{'_TMP_DIR'} = $tmp_dir;

	my $tmp_input = "$tmp_dir/input.fna";
	
	my $fa_o = Anorman::Fasta->new;
	$fa_o->open( $input ) if defined $input;

	open (my $FH, '>', $tmp_input) or $self->_error("Could not write to tmp file, $!");

	my $num_seqs  = 0;
	my $num_bases = 0;
	
	while ( $fa_o->iterator ){
		my $seqid = $fa_o->name;
		my $seq   = $fa_o->seq;
		
		$num_seqs++;
		$num_bases += $fa_o->length;

		print $FH ">$seqid\n";
		print $FH $seq . "\n";
	}

	close $FH;

	warn "$num_bases bases in $num_seqs sequences read\n";

	my $gf_o = Anorman::Annotator::GeneFinder->new;
	my $qp_o = Anorman::Annotator::QuickProt->new;

	return ($gf_o, $qp_o, $tmp_dir, $tmp_input);
}

sub _seq_fetcher {
	my $self  = shift;
	my $seqid = shift;
	my $key   = shift;
	
	my $seq_fetcher =  $self->{'gene_index'}->{ $seqid }->{ $key };

	my $seq;
	if (eval { $seq = &$seq_fetcher() }) {
		return $seq;
	} else {
		warn ("No $key sequence found for $seqid\n");
		return undef;
	}
}

sub _delete_tmp_files {
	my $self = shift;

	return unless (exists $self->{'_TMP_DIR'});
	warn "Deleting Temporary files..\n" if $DEBUG;
	rmdir $self->{'_TMP_DIR'} or $self->error ("Unable to unlink temporary dierectory");
	delete $self->{'_TMP_DIR'};
}

sub _error {
	shift;
	trace_error(@_);
}

1;

package Anorman::Annotator::GeneFinder;

use Anorman::Common;
use Anorman::Fasta;
use Bio::DB::Sam;
use File::Which qw(which);
use IPC::Run qw ( run );

sub new {
	my $class   = shift;

	my $self  = {};

	bless $self, $class;
	$self->_initialize;

	return $self;
}

sub run {
	my $self      = shift;
	my $input     = shift;
	my $wrk_dir   = shift;
	my $user_args = shift;	

	$self->_error( "Input file $input cannot be opened", 1) unless (-e $input);
	$self->_is_fasta( $input ) or $self->_error("$input is not FASTA",1);

	$self->{'_INPUT_FILE'}     = $input;
	$self->{'_WRK_DIR'}        = $wrk_dir if defined $wrk_dir;
	$self->{'_PROTEIN_OUT'}    = "$self->{'_WRK_DIR'}/prodigal-out.faa";
	$self->{'_CDS_OUT'}        = "$self->{'_WRK_DIR'}/prodigal-out.fna";
	$self->{'_GENE_TABLE_OUT'} = "$self->{'_WRK_DIR'}/prodigal-out.gff";
	$self->{'_RAW_GENE_CALLS'} = "$self->{'_WRK_DIR'}/prodigal-raw_gene_calls.txt";
	
	$self->_run_prodigal;
}

sub get_gene_features {
	my $self      = shift;
	my $usr_opt   = shift;

	my $gff_file       = $self->{'_GENE_TABLE_OUT'};
	my $nt_file        = $self->{'_CDS_OUT'};
	my $aa_file        = $self->{'_PROTEIN_OUT'}; 
	my $raw_calls_file = $self->{'_RAW_GENE_CALLS'};

	# override variables with user input
	if (defined $usr_opt && ref $usr_opt eq 'HASH') {
		($gff_file, $nt_file, $aa_file, $raw_calls_file) =
			@{ $usr_opt }{ qw/gff nt aa raw/ };
	}
	my %results   = ();

	warn "Processing results...\n" if $DEBUG;

	$results{'seq_index'}  = $self->_seq_index_from_gff( $gff_file );;
	$results{'gene_index'} = $self->_gene_index( $results{'seq_index'});

	my $fai_nt = $self->_load_fai( $nt_file ) if $nt_file;
	my $fai_aa = $self->_load_fai( $aa_file ) if $aa_file;
	
	warn "Appending gene fetchers..\n" if $DEBUG;

	# add sequence fetchers to results. Sequences will only be loaded on request
	foreach my $seq_feature( values %{ $results{'gene_index'} } ){
		$seq_feature->{'aa'} = $self->_append_seq_fetcher( $seq_feature, $fai_aa )
			if $aa_file;
		$seq_feature->{'nt'} = $self->_append_seq_fetcher( $seq_feature, $fai_nt )
			if $nt_file;
	}
	#$self->_parse_raw_gene_calls;
	
	my $object = bless (\%results, 'Anorman::Annotator');
	return ($object, $aa_file );

}

sub _load_fai {
	my $self = shift;
	my $file = shift;

	warn "Fetching fasta index for $file...\n" if $DEBUG;

	my $Fai = Bio::DB::Sam::Fai->load( $file );
	
	return $Fai;
}

sub _is_fasta {
	# NOTE:implement a fasta check
	return 1;
}

sub _initialize {
	my $self      = shift;

	$self->{'_PRODIGAL_EXE'}   = which('prodigal') 
		|| $self->_error( "Cannot run prodigal. Executable not in path", 1);
	$self->{'_WRK_DIR'}        = ".";
	$self->{'_INPUT_FILE'}     = '';
	$self->{'_PROTEIN_OUT'}    = '';
	$self->{'_CDS_OUT'}        = '';
	$self->{'_GENE_TABLE_OUT'} = '';
	$self->{'_RAW_GENE_CALLS'} = '';

	my %default_prodigal_args = (
		'-i' => \$self->{'_INPUT_FILE'    },
		'-a' => \$self->{'_PROTEIN_OUT'   },
		'-d' => \$self->{'_CDS_OUT'       },
		'-o' => \$self->{'_GENE_TABLE_OUT'},
		'-s' => \$self->{'_RAW_GENE_CALLS'},
		'-p' => 'meta',
		'-f' => 'gff',
		'-m' => '',
		'-q' => ''
	);

	$self->{'_PRODIGAL_ARGS'} = \%default_prodigal_args;
}

sub _run_prodigal {
	my $self     = shift;
	my @cmd      = map { $_ eq '' ? () : $_ } 
		       map { ref($_) ? $$_ : $_ } 
		       		($self->{'_PRODIGAL_EXE'}, %{ $self->{'_PRODIGAL_ARGS'} });
	my ($in, $out, $err);

	warn "Running prodigal...\n";
	warn join (" ", @cmd), "\n" if $DEBUG;
	
	&IPC::Run::run (\@cmd, \$in, \$out, \$err) or $self->_error( "Prodigal terminated prematurely: $err",1 ) ;
}



sub _append_seq_fetcher {
	my $self         = shift;
	my $seq_feature  = shift;
	my $index        = shift;

	return sub {$index->fetch( $seq_feature->{'seqid'} ) };
}

sub _seq_index_from_gff {
	my $self     = shift;
	my $gff_path = shift;
	
	(-e $gff_path || $self->_error("No gene table found. Run Gene Finder first",1));
	warn "Indexing genes...\n" if $DEBUG;
	my %results   = ();

	open (my $FH, '<', $gff_path) or $self->_error( "Could not retrieve gene table ($gff_path)" );
	
	my $line = <$FH>;
	chomp $line;

	$self->_error( "Not a proper gff-header: $line", 1) unless $line =~ m/^##gff-version\s+\d+/;
	
	my $seqnum  = 0;
	my $genenum = 0;

	while (defined (my $line = <$FH>)) {
		chomp $line;
		if ($line =~ m/^# Sequence Data: (.*)/) {
			
			# Create a header of metadata for each sequence
			my %meta_data = ();
			my @fields = split /;/, $1;
			
			$line = <$FH>;
			$line =~ m/^# Model Data: (.*)/;

			push @fields, split /;/, $1;

			foreach my $string(@fields) {
				my ($key, $val) = $string =~ m/^(\w+)=\"?(.*?)\"?$/;
				$meta_data{ $key } = $val;
			}

			$seqnum            = $meta_data{ 'seqnum' };
			$genenum           = 0;
			my ($seqid)        = $meta_data{'seqhdr'} =~ m/^(\S+)(?:\s+|$)/;
			$results{ $seqid } = \%meta_data;
		} else {
			my %feature = ();
			my @fields = qw/seqid source type start end score strand frame attributes/;
			@feature{ @fields } = split /\t/, $line;
			my $seqid = $feature{ 'seqid' };
		
			# calculate gene length
			$feature{'length'} = $feature{'end'} - $feature{'start'} + 1;

			# Append gene number suffix to name (i.e. <sequence_name>_<gene_number>)
			$genenum++;
			$feature{ 'seqid' } =~  s/$/_$genenum/;

			# Handle the attributes field
			my @att = split /;|=/, $feature{ 'attributes' };
			shift @att; # annoyingly the first semicolon creates an empty field...
			my %att = @att;
			$feature{'attributes'} = \%att;
			
			# Add gene feature to results
			push @{ $results{ $seqid }->{'features'} }, \%feature; 
		}

	}
	return \%results;
}

sub _gene_index {
	my $self       = shift;
	my $gene_table = shift || $self->_error( "Must have sequence index to create gene index");

	my %index = ();

	while (my ($seqid, $seq_ref) = each %{ $gene_table }) {
		next unless exists $seq_ref->{'features'};
		my $a = $seq_ref->{'features'};
		@index{ map { $_->{'seqid'} } @{ $a } } = @{ $a };
	}
	return \%index;
}
sub _error {
	shift;
	trace_error(@_);
}

1;

package Anorman::Annotator::QuickProt;

=head1 NAME
Anorman::Annotator::QuickProt
=head1 SYNOPSIS
    Runs a quick analysis of protein sequences
    By running hmmscan on Pfam-A and TIGRFAMs
    An optional search (using usearch) can also
    be run against UniRef

    October 2012, Anders Norman anorman@berkeley.edu

=cut


use File::Which qw(which);
use Anorman::Common;
use Anorman::HitTable;
use TokyoCabinet;

sub new {
	my $class   = shift;
	my $self  = {};

	bless ($self, $class || ref $class);
	$self->_initialize(@_);
	return $self;
}

sub run {
	my $self    = shift;
	my $input   = shift;
	my $wrk_dir = shift || ".";

	$self->{'_FAA_FILE_IN'}        = $input;

	$self->{'_USEARCH_LOG'}        = "$wrk_dir/usearch64.log";
	$self->{'_USEARCH_EVALUE'}     = "1";
	$self->{'_USEARCH_HITS_OUT'}   = "$wrk_dir/ublast-out.txt";

	my @dbs = qw/Pfam-A Pfam-B TIGRFAMs_13.0/;

	for my $db(@dbs) {
		$self->{'_DB_NAME'}            = $db;
		$self->{'_HMMSCAN_DB'}         = "$HMM_DB_DIR/$db.hmm";
		$self->{'_HMMSCAN_DOMTBL_OUT'} = "$wrk_dir/hmmscan-out.domtbl.$db.txt";
		$self->{'_HMMSCAN_RAW_OUT'}    = "$wrk_dir/hmmscan-out.raw.$db.txt";

		$self->_run_hmmscan( $db );
		$self->fetch_hmm_results;
	}
	
	$self->_run_usearch;
	$self->fetch_usearch_results;

}

sub fetch_hmm_results {
	my $self  = shift;
	my $input = shift || $self->{'_HMMSCAN_DOMTBL_OUT'};
	my $db    = shift || $self->{'_DB_NAME'};

	my $fetch = $self->{'_FETCH_HITS'};
	
	warn "Processing hmmscan results...\n" if $DEBUG;

	$fetch->open( $input, "hmmscandom" );

	while (my $record = $fetch->get_record) {
		my $uniq_id = "$record->{'q_id'} $record->{'dom_num'}";
		$fetch->store_record( $record, $uniq_id );
	}

	foreach my $r( $fetch->uniq_records ) {
		my $q_id = $r->{'q_id'};
		$r->{'source'} = $db;
		$r->{'type'} = "protein_hmm_match";
		push @{ $self->{'annotations'}->{ $q_id } }, $r;
	}
}

sub fetch_usearch_results {
	my $self  = shift;
	my $input = shift || $self->{'_USEARCH_HITS_OUT'};
	my $fetch = $self->{'_FETCH_HITS'};

	warn "Processing usearch results...\n" if $DEBUG;

	$fetch->open ( $input, "blast" );

	while (my $r = $fetch->get_record) {
		$r->{'q_id'} =~ s/^(\S+)(?:\s+.*)?$/$1/;
		$fetch->store_record( $r );
	}

	my $hdb   = TokyoCabinet::HDB->new;
	$hdb->open("/data1/blastdb/uniref/uniref90.fasta.tch");

	foreach my $r( $fetch->uniq_records ) {
		
		my $q_id = $r->{'q_id'};
		my $s_id = $r->{'s_id'};

		my $db_string = $hdb->get( $s_id );

		@{ $r }{ qw/s_desc s_seq/ } = 
			$db_string =~ m/\{"description"\:"(.*?)","sequence"\:"(.*?)"\}$/;
		$r->{'s_len'} = length $r->{'s_seq'};
		$r->{'s_cov'} = $r->{'aln_len'} / $r->{'s_len'};
		$r->{'type'}   = "protein_match";	
		$r->{'source'} = "UniRef90";
		push @{ $self->{'annotations'}->{ $q_id } } , $r;
	}
}

sub get_protein_features {
	my $self = shift;

	return bless $self->{'annotations'}, 'Anorman::Annotator';
}

sub _initialize {
	my $self    = shift;
	my $input   = shift;
	my $wrk_dir = shift || ".";

	# confirm that hmmscan will run
	if ($self->{'_HMMSCAN_EXE'} = which('hmmscan')) { 
		warn "Hmmscan path OK\n" if $DEBUG;
	} else {
		warn "WARNING: Will not be able to run hmmscan. Executable not in path\n";
	}
	
	# confirm that usearch will rin
	if ($self->{'_USEARCH64_EXE'} = which('usearch64')) {
		warn "Usearch (64-bit version) ok\n" if $DEBUG;
	} else {
		warn "WARNING: Usearch (64 bit-version) was not found. Executable not in path\n";
	}
	

	my %default_hmmscan_args = ( 
			"--domtblout" => \$self->{'_HMMSCAN_DOMTBL_OUT'},
		     	"-o"	      => \$self->{'_HMMSCAN_RAW_OUT'},
		     	"-T"          => 20,
			"--noali"     => '',
			"--cpu"       => $ENV{'OMP_THREAD_LIMIT'} || 0
	);

	$self->{'_HMMSCAN_ARGS'} = \%default_hmmscan_args;

	my %default_usearch_args = ( 
		     "-threads"   => $ENV{'OMP_THREAD_LIMIT'} || 0,
		     "-ublast"    => \$self->{'_FAA_FILE_IN'},
		     "-db"        => "/data1/blastdb/uniref/uniref90.udb",
		     "-evalue"    => \$self->{'_USEARCH_EVALUE'},
		     "-blast6out" => \$self->{'_USEARCH_HITS_OUT'},
		     "-quiet"     => '',
		     "-log"       => \$self->{'_USEARCH_LOG'}
	);

	$self->{'_USEARCH_ARGS'} = \%default_usearch_args;
	
	$self->{'_FETCH_HITS'} = Anorman::HitTable->new();
}

sub _run_hmmscan {
	my $self = shift;
	my ($in,$out,$err);

	
	# construct command string
	my @cmd = map { $_ eq '' ? () : $_ } 
		  map { ref($_) ? $$_ : $_ }  
		  ($self->{'_HMMSCAN_EXE'}, 
		   %{ $self->{'_HMMSCAN_ARGS'} },
		   $self->{'_HMMSCAN_DB'},
		   $self->{'_FAA_FILE_IN'}
		  );
	warn "Running hmmscan ($self->{'_HMMSCAN_DB'}) ...\n" if $DEBUG;
	warn join (" ", @cmd), "\n" if $DEBUG;

	&IPC::Run::run (\@cmd, \$in, \$out, \$err)
		or $self->_error( "hmmscan terminated prematurely: $err",1 ); 
}

sub _run_usearch {
	my $self = shift;

	my ($in, $out, $err);

	my @cmd = map { $_ eq '' ? () : $_ }
		  map { ref($_) ? $$_ : $_ }
		  ($self->{'_USEARCH64_EXE'},
		  %{ $self->{'_USEARCH_ARGS' } }, 
		 );
	warn "Running usearch...\n" if $DEBUG;
	warn join (" ", @cmd), "\n" if $DEBUG;
	&IPC::Run::run (\@cmd, \$in, \$out, \$err)
		or $self->_error( "usearch terminated prematurely: $err",1 );
}

sub _error {
	shift;
	trace_error(@_);
}

1;
