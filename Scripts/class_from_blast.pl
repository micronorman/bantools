#!/usr/bin/env perl

use strict;
use warnings;

use Anorman::ESOM::File;
use Getopt::Long;
use Pod::Usage;

my ($blast_file,$names_file, $cls_file, $subseq_index, $sort_by_size, $min_class_size );

$min_class_size = 0;

&GetOptions(
	'help'         => sub { pod2usage ( verbose => 1 ) },
	'manual'       => sub { pod2usage ( verbose => 2 ) },
	'names|n=s'    => \$names_file,
	'blast|b=s'    => \$blast_file,
	'cls|c=s'      => \$cls_file,
	'sort_by_size' => \$sort_by_size,
	'min_size=i'   => \$min_class_size	
) or pod2usafe ( message => 'Use --help for more information', verbose => 0 ) ;

# Load names file
my $names   = Anorman::ESOM::File::Names->new( $names_file );
$names->load;
$subseq_index = $names->subseq_index;


# Load blast table
open (my $FH, '<', $blast_file) or die "ERROR opening $blast_file: $!";

my %BLAST_RESULT = ();
my %CLASS_NAME   = ();

while (defined (my $line = <$FH>)) {
	next if $line =~ /^#/;
	chomp $line;
	my ($query,$hit) = split ("\t", $line);
	$BLAST_RESULT{ $query } = $hit;
	$CLASS_NAME{ $hit } ||= 0;
	$CLASS_NAME{ $hit } += scalar @{ $subseq_index->{ $query } }
		if exists $subseq_index->{ $query };
}

close $FH;


# Make new classes according to blast hits
my $classes     = Anorman::ESOM::ClassTable->new;

# Sort and filter classes
my @class_names = grep { $CLASS_NAME{ $_ } >= $min_class_size } $sort_by_size ? 
			sort { $CLASS_NAME{ $b } <=> $CLASS_NAME{ $a } ||
			       $a cmp $b 
			     } keys %CLASS_NAME :

			sort keys %CLASS_NAME;

my $class_index = 0;
foreach my $class_name(@class_names) {
	$classes->add( ++$class_index, $class_name );
}

warn "WARNING: No classes were created\n" unless $classes->size > 1;

my $cls     = Anorman::ESOM::File::Cls->new( $cls_file );
$cls->classes( $classes );

# Classify all subsequences
my %tmp_cls = ();

while (my($seq_name, $members) = each %{ $subseq_index }) {
	if (exists $BLAST_RESULT{ $seq_name }) {
		my $class       = $classes->get_by_name( $BLAST_RESULT{ $seq_name } );

		next unless defined $class;

		my $class_index = $class->index;

		foreach my $index(@{ $members }) {
			$tmp_cls{ $index } = $class_index;
		}
	}	
}

# Add datapoint classes to cls-file
my $i = 0;
while ( ++$i <= $names->datapoints ) {
	$cls->add( $i, $tmp_cls{$i} || 0  );
}

$cls->save();

__END__

=head1 NAME

class_from_blast.pl -- Create datapoint classes from a blast table

=head1 SYNOPSIS

=over 8

=item B<class_from_blast.pl>
B<-b> I<file>
B<-n> I<file>
B<-c> I<file>
[B<--sort_by_size>]
[B<--min_size>=I<NUM>]

=back

=head1 OPTIONS


=cut
