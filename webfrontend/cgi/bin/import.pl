#!/usr/bin/perl

# fetch.pl

# Copyright 2017 Christian Fenzl, christiantf@gmx.at
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Programmablaufplan
# 
# OK Initiale Pfade berechnen
# OK Commandline-Parameter lesen
# OK Logfile initialisieren
# OK Umbenennen des Jobs in .running
# OK Job lesen
# OK Miniserver-Credentials aus Loxberry-DB lesen
# OK RRD-Pfad aus Statistik-DB auslesen (-->ist nur die Nummer, nicht notwendig)
# NOK evt. RRD-Steps aus RRD-File lesen (-->aktuell nicht erforderlich)
# OK Aus RRD letzten Timestamp lesen (epoch) und in Monat/Jahr umrechnen
# Loop über Monat/Jahr bis heute
#	Datenfile als XML vom MS holen
#   Loop
#		Ergänzen des XML um Zeit in Epoch
#		evt. INSERT für relationale DB erstellen
#	Abhängig vom Statstype
#		-> Werte interpolieren und ins XML-Objekt schreiben
#	Loop 
#		Commandline mit Datensätzen erstellen
#	Datensätze schreiben
# Job aufräumen
# evt. Polling starten





#use strict;
#use warnings;

##########################################################################
# Modules
##########################################################################

use LWP::UserAgent;
use String::Escape qw( unquotemeta );
use URI::Escape;
use XML::Simple qw(:strict);
use XML::LibXML;
use Getopt::Long;
use Config::Simple;
use File::HomeDir;
use File::Copy;
use Cwd 'abs_path';
use DateTime;
use RRDs;
use POSIX qw(strftime);

# Logfile
our $logfilepath; 
our $lf;
our @loglevels;
our $loglevel=5;

# Use loglevel with care! DEBUG=4 really fills up logfile. Use ERRORS=1 or WARNINGS=2, or disable with 0.
# To log everything to STDERR, use $loglevel=5.

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.1.2";

# Figure out in which subfolder we are installed
# Does not work (returns 'bin')
# our $psubfolder = abs_path($0);
# $psubfolder =~ s/(.*)\/(.*)\/bin\/(.*)$/$2/g;
$psubfolder = 'stats4lox';


# my $home = File::HomeDir->my_home;
$home = '/opt/loxberry';

print STDERR "Home: $home Pluginsubfolder $psubfolder\n";
my $job_basepath = "$home/data/plugins/$psubfolder/import";


my $cfg             = new Config::Simple("$home/config/system/general.cfg");
my $lang            = $cfg->param("BASE.LANG");
my $installfolder   = $cfg->param("BASE.INSTALLFOLDER");
my $miniservers     = $cfg->param("BASE.MINISERVERS");
my $clouddns        = $cfg->param("BASE.CLOUDDNS");

#
# Commandline options
#

my $jobname = '';

GetOptions ('loglevel=s' => \$loglevel,
            'job=s' => \$jobname
            );

#
# Initialize logfile
#
			
$logfilepath = "$home/log/plugins/$psubfolder/import_$jobname.log";
openlogfile();
logger(4, "Logfile $logfilepath opened");

####################################
# Rename jobfile to .running
####################################

# Check if the job file exists and is writeable
if (! -w "$job_basepath/$jobname.job") {
	logger(1, "Job $jobname does not exist or not writeable in $job_basepath - Terminating");
	exit(1);
}

# Rename the job file
if (! move("$job_basepath/$jobname.job", "$job_basepath/$jobname.running")) {
	logger(1, "Job $job_basepath/$jobname.job could not be renamed to .running - Terminating");
	exit(2);
}

###################################
# Read job file
###################################

our $job = new Config::Simple("$job_basepath/$jobname.running");
my $loxonename = $job->param("loxonename");
my $loxuid = $job->param("loxuid");
my $statstype = $job->param("statstype");
my $description = $job->param("description");
my $settings = $job->param("settings");
my $minval = $job->param("minval");
my $maxval = $job->param("maxval");
my $place = $job->param("place");
my $category = $job->param("category");
my $ms_nr = $job->param("ms_nr");
my $db_nr = sprintf("%04d", $job->param("db_nr"));
my $import_epoch = $job->param("import_epoch");

# Check the important values for further processing
logger(3, "JOB $jobname for statistic $loxonename ($place/$category) on Miniserver $ms_nr, statistic db is $db_nr");
if ($ms_nr < 1) 		{ logger(1, "Miniserver not defined - Terminating"); exit(3);}
if ($db_nr < 1) 		{ logger(1, "RRD DB number not defined - Terminating"); exit(4);}
if (! $loxuid)			{ logger(1, "Loxone UID not defined - Terminating"); exit(5);}
if ($statstype < 1)		{ logger(1, "Loxone Statistic type not defined - Terminating"); exit(6);}


###################################
# Read Miniserver credentials
# Re-used from Michael
###################################

# Miniserver data
	$miniserver = $ms_nr;
	$miniserverip        = $cfg->param("MINISERVER$miniserver.IPADDRESS");
	$miniserverport      = $cfg->param("MINISERVER$miniserver.PORT");
	$miniserveradmin     = $cfg->param("MINISERVER$miniserver.ADMIN");
	$miniserverpass      = $cfg->param("MINISERVER$miniserver.PASS");
	$miniserverclouddns  = $cfg->param("MINISERVER$miniserver.USECLOUDDNS");
	$miniservermac       = $cfg->param("MINISERVER$miniserver.CLOUDURL");

	# Use Cloud DNS?
	if ($miniserverclouddns) {
		$output = qx($home/bin/showclouddns.pl $miniservermac);
		@fields2 = split(/:/,$output);
		$miniserverip   =  @fields2[0];
		$miniserverport = @fields2[1];
	}

	logger(4, "Miniserver-IP $miniserverip:$miniserverport");
	
	
##############################
# Some RRD file processing 
##############################

# our $rrdtool = '/usr/bin/rrdtool';

$rrdfile = "$installfolder/data/plugins/$psubfolder/databases/$db_nr.rrd";
if (! -e $rrdfile) {
	logger(1, "RRD-File $rrdfile does not exist - Terminating");
	exit(7);
}

# Check if rrdcached daemon is running
my $rrdcached = ''; # RRDCache Daemon Sock
if (-S "/var/run/rrdcached.sock") {
		$rrdcached = "--daemon=/var/run/rrdcached.sock";
		logger(4, "RRDCached is running and will be used.");
} else {
		logger(2, "RRDCached seems not to be running. Direct write will be used and may degrade import performance.");
}

# Get last update time 	
our $lastupdate_ep = RRDs::last($rrdcached, $rrdfile);
my $ERR=RRDs::error;
if ($ERR) {
	logger(1, "Error processing rrds::last: $ERR");
}
logger(4, "RRD last update epoch RAW: $lastupdate_ep");

# If timestamp is earlier then 0 of Loxone-time, set it to Loxone-time 0 == 1230768000 Epoch
if ($lastupdate_ep < 1230768000) {
	$lastupdate_ep = 1230768000;
}

# Try some time calculation for warming up
$lastupdate_str = strftime '%d.%m.%Y %H:%M:%S', localtime $lastupdate_ep;
logger(4, "RRD last update epoch processed: EPOCH $lastupdate_ep - Human Readable $lastupdate_str");

my $lastupdate_dt = DateTime->from_epoch( epoch => $lastupdate_ep ); 

my $lastupdate_month = $lastupdate_dt->month;
my $lastupdate_year = $lastupdate_dt->year;

my $now_dt = DateTime->now; 



logger(4, "RRD last update month year: $lastupdate_month/$lastupdate_year");

# Looping through month and year

# Year Loop
for (my $year=$lastupdate_year; $year <= $now_dt->year; $year++) {
	# Month loop
	foreach my $month (1...12) {
		# Example URL http://192.168.0.77/stats/00ac8517-0961-11e1-99b9f25d750310ed.201207.xml
		$statsurl = sprintf("http://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverport/stats/$loxuid.%04d%02d.xml", $year, $month);
		logger(4, " Year $year Month $month Stats-URL $statsurl ");
		
		# Fetching data with UserAgent
		my $ua = LWP::UserAgent->new();
		$ua->timeout(10);
		my $response = $ua->get($statsurl);
		if (! $response->is_success) {
			logger(2, "Downloading of XML failed - possibly non-existing month (continuing with next month): $response->status_line");
			next;
		}
		my $parser = XML::LibXML->new();
		eval {
			my $stats = XML::LibXML->load_xml(
				string => $response->decoded_content
				);
		};
		if ($@) {
			logger(2, "Could not read XML (continuing with next month): $@");
			next;
		} else {
			logger(4, "Seems that XML could be loaded");
		}
		# In $stats we should have our XML now
		logger(4, "First node? " . $stats->nodeName);
		
		
		
		# We have to break out of the loop if we have reached the current year/month
		if ($year == $now_dt->year && $month == $now_dt->month) {
			last;
		}
	# End of month loop
	}

# End of year loop

}


























	
#####################################################
# Logging
#####################################################

# Log Levels
# 0 Nothing is logged
# 1 Errors only
# 2 Including warnings
# 3 Including infos
# 4 Full debug
# 5 Send everything to STDERR

	sub openlogfile
	{
		if ( $loglevel > 0 ) {
			open $lf, ">>", $logfilepath
				or do {
					# If logfile cannot be created, change loglevel to 5 (STDERR)
					print STDERR "ERROR: Stats4Lox Import - Could not create logfile $logfilepath";
					$loglevel = 5;
				}
		}
		@loglevels = ("NOLOG", "ERROR", "WARNING", "INFO", "DEBUG");
	}

	sub logger 
	{
		my ($level, $message) = @_;
		
		if ( $loglevel == 5 ) {
			($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = CORE::localtime(time);
			my $now_string = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
			print STDERR "$now_string Stats4Lox import.cgi $loglevels[$level]: $message\r\n";
		} elsif ( $level <= $loglevel && $loglevel <= 4) {
			($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = CORE::localtime(time);
			my $now_string = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
			print $lf "$now_string $loglevels[$level]: $message\r\n";
		}
	}
	