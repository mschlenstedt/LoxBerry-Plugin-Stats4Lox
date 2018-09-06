use LoxBerry::System;
require "$lbpbindir/libs/S4LJson.pm";
use LoxBerry::Log;
use strict;

# Debugging
use Data::Dumper;

package Stats4Lox;

our $ConfigVersion = 2;

my %dbsettings;
my $installfolder = $LoxBerry::System::lbhomedir;
my $psubfolder = $LoxBerry::System::lbpplugindir;

## Routines to run on every inclusion
#####################################

our $pcfgfile = "$LoxBerry::System::lbpconfigdir/stats4lox.cfg";
our $pcfg;

$main::htmlhead = "<script src='js/stats4lox.js'></script>\n"; 

# Create config file if not exist

if (! -e $pcfgfile) {
		$pcfg = new Config::Simple(syntax=>'ini');
		$pcfg->param("Main.ConfigVersion", "0");
		$pcfg->write($pcfgfile);
}

$pcfg = new Config::Simple($pcfgfile);
$pcfg->autosave(1);

# RRD Database folder
if ($pcfg->param('Main.rrdfolder') and ! -e $pcfg->param('Main.rrdfolder')) {
	# Configured BUT does not exists
	# -> Do nothing
}
if (! $pcfg->param('Main.rrdfolder')) {
	# Not configured at all --> set default
	$pcfg->param('Main.rrdfolder', "$LoxBerry::System::lbpdatadir/databases");
}

if (! $pcfg->param('Main.configfolder') or ! -e $pcfg->param('Main.configfolder')) {
	# Configured OR does not exists --> set default
	$pcfg->param('Main.configfolder', "$LoxBerry::System::lbpdatadir/s4ldata");
}

if (! $pcfg->param('GRAFANA.rrdserverport')) {
	$pcfg->param('GRAFANA.rrdserverport', "3001");
}
# RRDCACHED default parameters
if (! $pcfg->param('RRD.RRDCACHED_ADDRESS')) {
	$pcfg->param('RRD.RRDCACHED_ADDRESS', '/var/run/rrdcached.sock');
}
if (! $pcfg->param('RRD.RRDCACHED_enabled')) {
	$pcfg->param('RRD.RRDCACHED_enabled', 'True');
}
if (LoxBerry::System::is_enabled($pcfg->param('RRD.RRDCACHED_enabled'))) {
	$main::RRDCACHED_ADDRESS = $pcfg->param('RRD.RRDCACHED_ADDRESS');
}

# Finally import to CFG namespace
$Stats4Lox::pcfg->import_names('CFG');

# DATA MIGRATION STEPS
if ($pcfg->param("Main.ConfigVersion") < $ConfigVersion) {
	require "$LoxBerry::System::lbpbindir/libs/Migration.pm";
	Stats4Lox::Migration::data_migration()
}

# Defining globals to main namespace (we need it a lot!)
$main::configfolder=$pcfg->param("Main.configfolder");
$main::statisticsfile=$main::configfolder . "/statistics.json";



# Access config variables by $CFG::MAIN_RRDFOLDER (all uppercase)

######################################
## Functions to run on demand

############################
# Main Navigation Bar
############################
sub navbar_main
{
	my ($selected) = @_;
	
	$main::navbar{10}{Name} = "Statistiken";
	$main::navbar{10}{URL} = './index.cgi';
	 
	$main::navbar{20}{Name} = "Import";
	$main::navbar{20}{URL} = './import.cgi';
	 
	# $main::navbar{30}{Name} = "Charts";
	# $main::navbar{30}{URL} = './charts.cgi';
	
	# $main::navbar{40}{Name} = "Indexes";
	# $main::navbar{40}{URL} = './indexes.cgi';
	

	$main::navbar{90}{Name} = "Einstellungen";
	$main::navbar{90}{URL} = './general_settings.cgi';

	$main::navbar{95}{Name} = "Grafana Integration";
	$main::navbar{95}{URL} = './grafana.cgi';
	
	$main::navbar{99}{Name} = "Über...";
	$main::navbar{99}{URL} = './about.cgi';

	$main::navbar{$selected}{active} = 1;

}

use base 'Exporter';
#our @EXPORT = (
#
#);

############################
# Get database template
############################
sub get_dbsettings
{
	if (! %dbsettings) {
		open(F,"<$CFG::MAIN_CONFIGFOLDER/dbsettings.dat");
        my @data = <F>;
        foreach (@data) {
            s/[\n\r]//g;
            # Comments
            if ($_ =~ /^\s*#.*/) {
                next;
            }
            my @fields = split(/\|/);
            if ($fields[0]) { 
				$dbsettings{$fields[0]}{Name} = $fields[1];
			}
		}
		close (F);
	}

	return %dbsettings;
}

#####################################################
# Create hash of DBs by loxonename
#####################################################
#
# Usage: 
# 	require "$lbpbindir/libs/Stats4Lox.pm";
# 	my %dbs = Stats4Lox::get_databases_by_name();
# 	my $loxonename = "puffertemp";
#	my $description = %dbs{$loxonename}{Description};

sub get_databases_by_name 
{
	my %entries;
	
	open(F,"<$CFG::MAIN_CONFIGFOLDER/databases.dat");
	my @data = <F>;
	close (F) ;
		
	# Loop over DB
	foreach (@data){
		# my @single_template = @template;
		s/[\n\r]//g;
		# Comments
		if ($_ =~ /^\s*#.*/) {
			next;
		}
		my @fields = split(/\|/);
		my $loxonename = lc($fields[3]);
		$entries{$loxonename}{dbid} = $fields[0];
		$entries{$loxonename}{dbidstr} = sprintf("%04d", $fields[0]);
		$entries{$loxonename}{Step} = $fields[1];
		$entries{$loxonename}{Description} = $fields[2];
		$entries{$loxonename}{Miniserver} = $fields[4];
		$entries{$loxonename}{Min} = $fields[5];
		$entries{$loxonename}{Max} = $fields[6];
		$entries{$loxonename}{Place} = $fields[7];
		$entries{$loxonename}{Category} = $fields[8];
		$entries{$loxonename}{UID} = $fields[9];
		$entries{$loxonename}{Unit} = $fields[10];
		$entries{$loxonename}{Block} = $fields[11];
	}
	return %entries;
}	 

#####################################################
# Create hash of DBs by dbid
#####################################################
# Usage: 
# 	my %dbs = Stats4Lox::get_databases_by_id();
# 	my $statid = 2;
#	my $description = %dbs{$statid}{Description};

sub get_databases_by_id 
{
	my %entries;
	
	open(F,"<$CFG::MAIN_CONFIGFOLDER/databases.dat");
	my @data = <F>;
	close (F) ;
		
	# Loop over DB
	foreach (@data){
		# my @single_template = @template;
		s/[\n\r]//g;
		# Comments
		if ($_ =~ /^\s*#.*/) {
			next;
		}
		my @fields = split(/\|/);
		my $dbid = lc($fields[0]);
		$entries{$dbid}{dbidstr} = sprintf("%04d", $fields[0]);
		$entries{$dbid}{Step} = $fields[1];
		$entries{$dbid}{Description} = $fields[2];
		$entries{$dbid}{Loxonename} = $fields[3];
		$entries{$dbid}{Miniserver} = $fields[4];
		$entries{$dbid}{Min} = $fields[5];
		$entries{$dbid}{Max} = $fields[6];
		$entries{$dbid}{Place} = $fields[7];
		$entries{$dbid}{Category} = $fields[8];
		$entries{$dbid}{UID} = $fields[9];
		$entries{$dbid}{Unit} = $fields[10];
		$entries{$dbid}{Block} = $fields[11];
	}
	return %entries;
}	 

#############################################
# Reads a full file and returns it as string
# Parameter: $filename, Returns: $content
sub read_file
{
	my ($filename) = @_;
	local $/=undef;
	open FILE, $filename or return undef;
	my $string = <FILE>;
	close FILE;
	print STDERR "read_file: $filename finished\n";
	return $string;
}

sub write_file
{
	my ($filename, $string) = @_;
	open(my $fh, '>', $filename) or return undef;
	print $fh $string;
	close $fh;
	return 1;
}


# Compares the S4L database timestamp with a Configfile timestamp
sub update_grafana_dashboard
{
	# print STDERR "update_grafana_dashboard\n";
	# We need mtime in epoch
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
		$atime,$mtime,$ctime,$blksize,$blocks) = stat("$main::statisticsfile");
	
	# Leave if the the dashboards are up-to-date
	return if ($CFG::GRAFANA_LAST_DASHBOARD_UPDATE and $mtime < $CFG::GRAFANA_LAST_DASHBOARD_UPDATE);
		
	# Generate dashboard json
	print STDERR "update_grafana_dashboard: Need to update\n";
	
	require JSON;
	require Clone;
	my $dashtmpl = JSON::from_json(read_file("$LoxBerry::System::lbpdatadir/grafana-templates/grafana_dashboard_template.json"));
	my $paneltmpl = JSON::from_json(read_file("$LoxBerry::System::lbpdatadir/grafana-templates/grafana_panel_template.json"));
	
	# print STDERR "dashtmpl: title " . $dashtmpl->{title} . "\n";
	
	my %rrd_dbs = get_databases_by_id();
	my @panels = ( );
	foreach my $rrdidx (sort keys %rrd_dbs) {
		my $panel = Clone::clone($paneltmpl);
		$panel->{id} = $rrdidx+0;
		$panel->{title} = $rrd_dbs{$rrdidx}{Description};
		$panel->{targets}[0]->{refId} = "A";
		$panel->{targets}[0]->{target} = $rrd_dbs{$rrdidx}{dbidstr} . ":value";
		$panel->{targets}[0]->{type} = "timeserie";
		push(@panels, $panel);
	}
	
	$dashtmpl->{panels} = \@panels;
	
	my $dashjson = JSON::to_json($dashtmpl, {pretty => 1});
	write_file("$LoxBerry::System::lbpdatadir/grafana-dashboards/Stats4Lox.json", $dashjson);
	$pcfg->param('GRAFANA.Last_Dashboard_Update', time);
	$pcfg->write;
	
}



# Executed after every successful or unsuccessful termination
END
{
	if (LoxBerry::System::is_enabled($CFG::GRAFANA_ENABLERRDSERVER)) {
		update_grafana_dashboard();
	}
}

sub data_migration 
{
	## Migrate to V1
	if($pcfg->param("Main.ConfigVersion") < 1) {
		require File::Copy;
		mkdir "$LoxBerry::System::lbpdatadir/stats4lox";
		File::Copy::move("$LoxBerry::System::lbpconfigdir/databases.dat", "$LoxBerry::System::lbpdatadir/stats4lox/");
		File::Copy::move("$LoxBerry::System::lbpconfigdir/dbsettings.dat", "$LoxBerry::System::lbpdatadir/stats4lox/");
		File::Copy::move("$LoxBerry::System::lbpconfigdir/id_databases.dat", "$LoxBerry::System::lbpdatadir/stats4lox/");
		$pcfg->param("Main.ConfigVersion", 1);
	}
	
	# Migrate to V2
	if($pcfg->param("Main.ConfigVersion") < 2 ) {
	
	
	
	
	}

}





#####################################################
# Finally 1; ########################################
#####################################################
1;
