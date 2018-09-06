#!/usr/bin/perl

my $fn="statcfg";

use LoxBerry::Web;
use LoxBerry::Log;
require "$lbpbindir/libs/Stats4Lox.pm";
use CGI;

# my $template = HTML::Template->new(
    # filename => "$lbptemplatedir/statcfg.html",
    # global_vars => 1,
    # loop_context_vars => 1,
    # die_on_bad_params => 0,
# #    associate => %pcfg,
# );

our $cgi = CGI->new;
$cgi->import_names('R');

my $statid;
my $statcfg_file;


if ($R::statid) {
	$statid = $R::statid;
}

# Read Statistics.json


LoxBerry::Web::lbheader("Stat4Lox Configuration", undef, undef);

# Parameter statid may be directly the filename, or the id)
if (-e "$configfolder/$statid") {
	$statcfg_file = $statid;
} else {
	# If file not exists, it was presumably a real statid - reading from statistics.json
	my $statsparser = Stats4Lox::JSON->new();
	my $statsobj = $statsparser->open(filename => $statisticsfile, readonly => 1);
	if(! defined $statsobj->{Stat}->{$statid}->{statCfgFile} and ! -e $statsobj->{Stat}->{$statid}->{statCfgFile}) {
		LOGERR "$fn: Sent statid $statid or file does not exist";
	} else {
		$statcfg_file = $statsobj->{Stat}->{$statid}->{statCfgFile};
	}
	undef $statsobj;
	undef $statsparser;
}

LOGDEB "$fn: Stat file that is opened: $statcfg_file";

my $statcfgparser = Stats4Lox::JSON->new();
my $statcfgobj = $statcfgparser->open(filename => "$configfolder/$statcfg_file");

print Dumper($statcfgobj);

	
	



# my $json = Stats4Lox::read_file("$main::statisticsfile");
# $json =~ tr/\r\n//d;

# $template->param('statsdata', $json) if ($json);





print $template->output();

LoxBerry::Web::lbfooter();



