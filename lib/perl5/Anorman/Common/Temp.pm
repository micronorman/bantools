package Anorman::Common::Temp;

use strict;

use Cwd;
use File::Copy;
use File::Temp qw( tempdir );
use File::Basename;

my $TMP_ROOT  = $ENV{'TMP'} || "/tmp";
my $USER      = $ENV{'USER'};
my $PROG_NAME = basename( $0 );
my $CWD       = getcwd;

if ($PROG_NAME eq '-e') {
	$PROG_NAME = 'inline';
}

$PROG_NAME =~ tr/\./_/;

use vars qw($USER $PROG_NAME $TMP_ROOT $CWD);

#my $template  = "$ENV{'USER'}.$progname.XXXX";
#my $tmp_dir   = tempdir ( $template, DIR => $TMP );

sub create_dir {
    my $prefix    = shift || "$USER.$PROG_NAME";
    my $temp_root = shift || $TMP_ROOT;
    
    my $template = "$prefix.XXXX";
    my $temp_dir = tempdir ( $template, DIR => $temp_root );

    return $temp_dir;
}

1;
