package Anorman::Wrapper::IDBA_UD;

use strict;

use File::Which;
use IPC::Run qw ( run );
use Carp;
use Data::Dumper;

require Exporter;

#our @ISA     = qw( Exporter );
#our @EXPORT  = qw( idba_ud_path );
#our $VERSION = "0.1";

our $WRK_DIR = ".";
our $TMP_DIR = $ENV{'TMP'} || "/tmp";

use vars qw($IDBA_UD_EXE);

sub idba_ud_path {
    return $IDBA_UD_EXE;
}
sub run_idba_ud {
	warn "Running idba_ud";
	my @cmd = qw( idba_ud );
        my ($in, $out, $err);
	run \@cmd, \$in, \$out, \$err;
	print $err;
}

sub collect_scaffolds {

}

sub collect_contigs {

}

sub clean_up {

}
1;
