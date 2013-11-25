package Anorman::Uclust;

use strict;
use warnings;
use Common::Math;

our $VERSION = 0.3;


=head1
GetUcClusters parses the output generated with uclust using the --uc parameter
And returns a hash references. 

Fields: 	1  = Type, 
			2  = ClusterNr, 
			3  = SeqLength/ClusterSize, 
			4  = PctId,
			5  = Strand,
			6  = QueryStart,
			7  = SeedStart,
			8  = Alignment,
			9  = Label,
			10 = Target

Types:  	L = LibSeed
			S = NewSeed
			H = Hit
			R = Reject
			D = LibCluster
			C = NewCluster
			N = NotMatched

For C and D types, PctId is average id with seed.

NOTE: For some reason PctID is in field 8 for D type clusters

QueryStart and SeedStart are zero-based relative to start of sequence.
If minus strand, SeedStart is relative to reverse-complemented seed.
=cut

sub GetUcClusters {

	my ($FileName) 		= @_;
	my %CLUSTER_INDEX	= ( 'LIST' => [], 'SEQUENCES' => {}, 'CLUSTERS'  => {} );
	
	open ( my $CLUSTER_FH, '<', $FileName ) or die "Could not open file $FileName, $!\n";

	my $Counter = 0;

	while ( defined( my $line = <$CLUSTER_FH> ) ) {

		next unless $line =~ m/^[LSHRDCN]\s+/;
		chomp $line;

		my @fields = split( "\t", $line );

		die "$FileName is Not a correctly formatted cluster file" if 9 > @fields;

		# Fetch variables for each field
		my (
			$Type,   $ClstrNr, $Size,      $PctId, $Strand,
			$QStart, $SStart,  $Alignment, $Label, $Target
		) = @fields;

		unless ( exists $CLUSTER_INDEX{ 'CLUSTERS' }{ $ClstrNr } ) {
			$CLUSTER_INDEX{ 'CLUSTERS' }{ $ClstrNr } =
			{    # Initialize standard keys for any new clusters
				'CLST_NUM' => 0,	'CLST_SEED' => '',	
				'CLST_HITS' => {},	'CLST_SIZE' => 0,
				'CLST_PCTID_AVG' => '*','CLST_LIBFLAG' => 0,
				'CLST_SEEDLEN' => 0
			}	
		}
		
		my $ClusterRef 		    = $CLUSTER_INDEX{ 'CLUSTERS' }{ $ClstrNr };
		my $ListRef		    = $CLUSTER_INDEX{ 'LIST' };

		$ClusterRef->{ 'CLST_NUM' } = $ClstrNr;

		if ( $Type eq 'S' ) {
			$ClusterRef->{ 'CLST_SEED' }    = $Label;
			$ClusterRef->{ 'CLST_SEEDLEN' } = $Size;
			$ClusterRef->{ 'CLST_SIZE' }++;
			push @{$ListRef}, $ClstrNr;

			$CLUSTER_INDEX{'SEQUENCES'}{$Label} = $ClstrNr;
		}
		elsif ( $Type eq 'L' ) {
			$ClusterRef->{ 'CLST_SEED' }    = $Label;
			$ClusterRef->{ 'CLST_SEEDLEN' } = $Size;
			$ClusterRef->{ 'CLST_LIBFLAG' } = 1;
			push @{$ListRef}, $ClstrNr;
		}
		elsif ( $Type eq 'C' ) {
			$ClusterRef->{ 'CLST_PCTID_AVG' } = $PctId;
		}
		elsif ( $Type eq 'D' ) {
			$ClusterRef->{ 'CLST_PCTID_AVG' } = $Alignment;
		}
		else {
			# Types H, N and R 
			$ClusterRef->{ 'CLST_HITS' }->{ $Label } = $PctId;
			$ClusterRef->{ 'CLST_SIZE' }++;

			$CLUSTER_INDEX{ 'SEQUENCES' }{ $Label }  = $ClstrNr;
		}

		print STDERR '.' unless ($Counter % 10000);
		$Counter++;
	}
	close $CLUSTER_FH;

	return \%CLUSTER_INDEX;
}

sub ReCalcMeanPctId {

	# Will take the mean of each pct. identity
	my ($ClusterRef) = @_;

	return if $ClusterRef->{ 'CLST_PCTID_AVG' } eq '*';
	return if $ClusterRef->{ 'CLST_SIZE' } == 0;

	my @PctIds    = values %{ $ClusterRef->{ 'CLST_HITS' } };
	my $MeanPctId = Math::Common::Mean( @PctIds );

	$ClusterRef->{ 'CLST_PCTID_AVG' } = $MeanPctId;
}

sub RareFact {

	my ($ClusterRef) = @_;
	my %CLUSTER_COUNT;
	my %SAMPLE_COUNT;
	my $Counter = 1;
	while (my ($Label, $ClusterNr) = each %{ $ClusterRef->{'SEQUENCES'} }) {
		next if $ClusterNr eq '*';
		next if ($ClusterRef->{'CLUSTERS'}->{$ClusterNr}->{'CLST_SIZE'} < 10);
		my $SampleName = substr ( $Label, 0, index ( $Label, '_' ));
		$SAMPLE_COUNT{ $SampleName }++;
		$CLUSTER_COUNT{ $SampleName }{ $ClusterNr } = 1;
		unless ($Counter % 10000) {
			print $Counter;
			foreach my $SampleName(sort { $a cmp $b } keys %CLUSTER_COUNT) {
				print "\t" . $SAMPLE_COUNT{$SampleName} . "\t", scalar keys %{ $CLUSTER_COUNT{ $SampleName } };
			}
			print "\n";
		}
		$Counter++;
	}

}
sub PrintCluster {
	my ($ClusterRef) = @_;

	return if not ref $ClusterRef eq 'HASH';
	
	my @ClusterVals = (	$ClusterRef->{ 'CLST_NUM' },		$ClusterRef->{ 'CLST_SIZE' },
				$ClusterRef->{ 'CLST_SEEDLEN' },  	$ClusterRef->{ 'CLST_PCTID_AVG' },
				$ClusterRef->{ 'CLST_SEED' } 
	);

	# Include Sample Counts if they exist
	if (exists $ClusterRef->{ 'CLST_SMPLCOUNT' }) {
		my @SampleCounts = ( '' ); # Make a spacer column in the table so sample count stick out more
		foreach my $SampleName(sort keys %{ $ClusterRef->{ 'CLST_SMPLCOUNT' } }) {
			push @SampleCounts, $ClusterRef->{ 'CLST_SMPLCOUNT' }->{$SampleName};
		}
		push @SampleCounts, ''; # Add another spacer at the end

		splice ( @ClusterVals,3,0,@SampleCounts );
	}
	print join ( "\t", @ClusterVals ), "\n";
}
	
sub PruneCluster {
	my ( $ClusterRef, $PruneKey, $Value ) = @_;

	return unless $ClusterRef->$PruneKey < $Value;
}

sub SortClusters {

	my ( $ClusterRef, $SortKey, $ReverseBit ) = @_;
	my @SortList;
	
	if ( $ReverseBit ) {
		@SortList = sort { 	
			$ClusterRef->{ 'CLUSTERS' }->{ $b }->{ $SortKey }
			<=>
			$ClusterRef->{ 'CLUSTERS' }->{ $a }->{ $SortKey }
			} keys %{ $ClusterRef->{ 'CLUSTERS' }};
	}
	else {
		@SortList = sort {
                        $ClusterRef->{ 'CLUSTERS' }->{ $a }->{ $SortKey }
                        <=>
                        $ClusterRef->{ 'CLUSTERS' }->{ $b }->{ $SortKey }
                        } keys %{ $ClusterRef->{ 'CLUSTERS' }};
	}

	return \@SortList; 
}

sub CountSamples {
	# Needs a hash reference to the cluster index and the delimiter
	# that specifies the break-point for the sample-name
	# I.e the sample name ABC_FX008N01XGHFS and elimiter '_' 
	# would indicate that the tag FX008N01XGHFS belongs to sample ABC
	# By default all samples will be counted but individual sample names can also be specified

	my ( $ClusterRef, $Delimiter, @CountIncludeList ) = @_;

	my (%SAMPLE_NAMES,%SAMPLE_INCLUDE);
	my $CountListBit = 0;

	if (scalar @CountIncludeList >= 1) {
		$CountListBit = 1;
		%SAMPLE_INCLUDE = map { $_ => 1 } @CountIncludeList;
	}

	$Delimiter = '_' unless defined $Delimiter;
	
	#### NOTE: Insert some sort of Delimiter sanity check here ###
	my $Counter = 0;
	
	while ( my ( $Label, $ClusterNum ) = each %{ $ClusterRef->{ 'SEQUENCES' }}) {

		# Skip counting seeds in type D clusters
		if ( $ClusterRef->{ 'CLUSTERS' }->{ $ClusterNum }->{ 'CLST_SEED' } eq $Label ) {
			next if $ClusterRef->{ 'CLUSTERS' }->{ $ClusterNum }->{ 'CLST_LIBFLAG' };
		}

		my $SampleName;
		$SampleName = $1 if $Label =~ m/(.*)_scaffold/;
		$SampleName = $1 if $Label =~ m/(.*)_contig/;
		
		if ($CountListBit) {
			next unless (exists $SAMPLE_INCLUDE{ $SampleName });
		}

		$SAMPLE_NAMES{ $SampleName } = 1 unless exists $SAMPLE_NAMES{ $SampleName };
		$ClusterRef->{'CLUSTERS'}->{ $ClusterNum }->{ 'CLST_SMPLCOUNT' }->{ $SampleName } ++;
	
		print STDERR '.' unless ($Counter % 10000);
		$Counter++;
	}
	
	if (%SAMPLE_NAMES) {
		foreach my $SampleName(keys %SAMPLE_INCLUDE) {
			warn "WARNING: No samples named $SampleName were found\n" if not exists $SAMPLE_NAMES{ $SampleName };
		}
	} else {
		warn "WARNING: No sample names were found\n";
		return;
	}
	
	# Add zero sample count if no samples were counted in a cluster
	foreach my $SampleName( keys %SAMPLE_NAMES ) {
		foreach my $ClusterNum( keys %{ $ClusterRef->{'CLUSTERS' }}) {
			my $NumSam = scalar $ClusterRef->{ 'CLUSTERS' }->{ $ClusterNum }->{ 'CLST_SMPLCOUNT' };
			next if scalar keys %SAMPLE_NAMES == $NumSam;
			unless ( exists $ClusterRef->{ 'CLUSTERS' }->{ $ClusterNum }->{ 'CLST_SMPLCOUNT' }->{ $SampleName }) {
				$ClusterRef->{ 'CLUSTERS' }->{ $ClusterNum }->{ 'CLST_SMPLCOUNT' }->{ $SampleName } = 0;
				print STDERR '.' unless ($Counter % 10000);
				$Counter++;
			}
		}
	}
}

1;
__END__
