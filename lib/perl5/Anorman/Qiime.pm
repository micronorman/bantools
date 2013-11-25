#
# Qiime, a set of tools for dealing with various output files of the Qiime
# package
#
# May 2011, Anders Norman
#

package Qiime;

use strict;
use warnings;

sub GetOtuMap {
	# Parses the output otu mapping file from the Qiime script pick_otus.py
	# (http://qiime.sourceforge.net/scripts/pick_otus.html).
	# Each otu is represented by a tab separated line where the first column 
	# is the OTU/cluster number and the following columns are the reads that
	# are part of that cluster.
	#
	# The function returns a hash reference

	my ($FileName) = @_;
	my %CLUSTER_MAP = ( 	'SEQUENCES'	=> {},
				'CLUSTERS'	=> []
			  );
	open ( my $CLUSTER_FH, '<', $FileName) or die "Error opening mapping file $FileName $!\n";

	while ( defined ( my $line = <$CLUSTER_FH> ) ) {
		
		next unless $line =~ m/^\d+(?:\t\S+)+$/; 	# line sanity check
		
		chomp $line;

		my @fields 	= split ( "\t", $line );
		my $ClusterNr 	= shift @fields;	# remove the cluster number

		my %CLUSTER = (	'SEQUENCES'	=> \@fields,
				'CLSTR_SIZE'	=> scalar (@fields)
			      );
				
		push (@{$CLUSTER_MAP{'CLUSTERS'}}, \%CLUSTER); 

		foreach my $Sequence (@fields) {
			$CLUSTER_MAP{'SEQUENCES'}->{$Sequence} = $ClusterNr;
		}
	}

	close $CLUSTER_FH;

	return 0 unless scalar (@{$CLUSTER_MAP{'CLUSTERS'}});
	return \%CLUSTER_MAP;
}

1;
