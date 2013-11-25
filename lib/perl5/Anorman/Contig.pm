package Anorman::Contig;
# A class for contigs. Nuff said for now...

use Anorman::Common qw(trace_error);

sub new {
	my $class = shift;
	
	$class->_error("Usage: " . __PACKAGE__ . "new ( %arguments )") unless @_;
	my %args  = @_;

	$class->_error("Cannot construct Contigs object without either sequence identifier (seqid) or target identifier (tid)") 
		if (!exists $args{ seqid } && !exists $args{ tid });
	
	my $self = {};

	if (exists $args{ bah }) {
		$class->_error("cannot invoke bam methods without a Target identifier (tid)") unless exists $args{ tid };
		
		$self->{'bai_fetch'} = _bai_fetch( $args{ tid } );	
		$self->{'bai_cov'}   = _bai_cov( $args{ tid } );
		#$self->{'length'}    = $args{ bah }->target_len->[ $args{ tid } ];
		#$self->{'seqid'}     = $args{ bah }->target_name->[ $args{ tid } ];
	}
	
	if (exists $args{ fai }) {
		$class->_error("Cannot invoke fai methods without a Sequence Identifier (seqid)") unless exists $args{ seqid }; 
		$self->{'fai_fetch'} = sub { return $args{ fai }->seq( $args{ seqid }, @_ ) };
	}

	return bless ( $self, ref $class || $class );
}

sub length {
	my $self = shift;
	my $length = exists $self->{'length'} ? $self->{'length'} : length ( $self->seq );

	$self->{'length'} = $length;

	return $length;
}

sub seq {
	my $self = shift;

	if (exists $self->{'fai_fetch'}) {
		return $self->{'fai_fetch'}->(@_);
	} elsif (exists $self->{'seq'}) {
		my $length = defined $self->{'length'} ? $self->{'length'} : length $self->{'seq'};
		return $self->{'seq'};
	}
}

sub coverage {
	my $self = shift;
	return $self->{ bai_cov }( @_ );
}

sub reads {

}

sub _bai_fetch {
	my $tid  = shift;
	my $code = sub {
		my $index = shift;
		my $bam   = shift;

		return $index->fetch($bam,$tid,@_);
	};

	return $code;
}

sub _bai_cov {
	my $tid = shift;
	my $code = sub {
		my $index = shift;
		my $bam   = shift;

		return $index->coverage($bam, $tid, @_);
	};

	return $code;
}

sub _error {
	shift;
	trace_error(@_);
}
1;
