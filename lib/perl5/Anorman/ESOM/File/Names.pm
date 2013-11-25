package Anorman::ESOM::File::Names;

use strict;
use warnings;

use parent 'Anorman::ESOM::File::Map';

use Anorman::Common;

sub new {
	my $class    = shift;
	my $filename = shift;

	my $self     = $class->SUPER::new();

	$self->{'filename'} = $filename;

	return $self;
}

sub add {
	my $self = shift;
	$self->SUPER::add(@_);

	%{ $self->{'subseqs'} } = ();
}

sub get_subseq_indexes {
	my $self = shift;
	
	my $subseq_index = $self->subseq_index;

	if (!defined (my $list = $subseq_index->{ $_[0] })) {
		warn "$_[0] not found\n";
	} else {
		return wantarray ? @{ $list } : $list;
	}
}
 
sub subseq_index {
	my $self    = shift;

	return $self->{'subseqs'} if exists $self->{'subseqs'} && %{ $self->{'subseqs'} };

	my $pattern      = shift || qr/^([!-~]+)_(\d+)\s+(\d+)-(\d+)$/;
	my $subseq_index = {};

	warn "Indexing subsequences...\n" if $VERBOSE;

	foreach my $name_item(@{ $self->data }) {
		my $name  = $name_item->name;
		my $index = $name_item->index;

		my ($seqid, $fragment_num, $beg, $end) = $name =~ m/$pattern/;

		if (defined $seqid) {
			push @{ $subseq_index->{ $seqid } }, $index;
		} else {
			$subseq_index->{ $name } = [ ($index) ];
		}
	}

	$self->{'subseqs'} = $subseq_index;
	
	return $subseq_index;
}

1;
