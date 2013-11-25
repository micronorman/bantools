# a basic fasta parsing module, largely stolen from
# Peter Wad Sackett
#
# Anders Norman 2009

package Anorman::Fasta;

use strict;

use Anorman::Common;
use Anorman::Common::Iterator;

sub new {
# initialize new fasta object
	my $class  = shift;
	my $iter   = Anorman::Common::Iterator->new( RS => "\n>" );
	my $self   = bless ( {'_iter' => $iter, '_parser' => \&_parse_fasta  }, ref($class) || $class);
	
	return $self;
}

sub open {
	my $self = shift;
	my $iter = $self->{'_iter'};
	my $fn   = shift;

	$iter->open($fn);
}

sub close {
	my $self = shift;
	my $iter = $self->{'_iter'};

	$iter->close;
}

sub iterator {
	my $self   = shift;
	my $iter   = $self->{'_iter'};

	$iter->NEXT;

	return undef unless $iter->MORE;

	my $record = $iter->CALLBACK( $self->{'_parser'} ); 
	
	if (defined $record) {
		$self->{'_rec'} = $record;
	} else {
		$self->_error("BOOooo...");
	}

	return 1;
}

sub header {
# return the name of the sequence
	my $self = shift;
	my $rec  = $self->{'_rec'} || $self->_error("No FASTA-record loaded",1);

	return $rec->{'header'};
}

sub name {
# return name truncated to the first whitespace character
	my $self = shift;
	my $rec  = $self->{'_rec'} || $self->_error("No FASTA-record loaded",1);
	my $name = $rec->{'header'};
	
	return ($name =~ m/^(.+?)\s+/) ? $1 : $name;
}

sub seq {
# return the sequence with the Seq command
	my $self = shift;
   	my $rec  = $self->{'_rec'} || $self->_error("No FASTA-record loaded",1);
   	return $rec->{'seq'};
}

sub length {
# return sequence length with the Length command
   my $self = shift;
   my $rec  = $self->{'_rec'} || $self->_error("No FASTA-record loaded",1);

   return length $rec->{'seq'};
}

sub _parse_fasta {
	my $self = shift;
        
	$self->REGEX( qr/^>?(.*?)\n(.*)/s );

	my ($header, $seq) = $self->MATCH;

	if (!defined $seq) { 
		my $index = $self->INDEX;	
		trace_error("Invalid Fasta record in entry $index");
		return undef;
	}

	$seq =~ tr/\n//d;

	if ($seq lt 'A') {
		warn "Sequence: $header is empty!\n";
	}
	
	return { 'header' => $header, 'seq' => $seq, 'length' => length $seq };
}

sub _error {
	shift;
	trace_error(@_);
}

1;
