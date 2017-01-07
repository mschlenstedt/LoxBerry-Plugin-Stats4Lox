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

# 
# Tools 
# Online RRD drawer http://rrdwizard.appspot.com/import.php
# Online Epoch converter http://www.epochconverter.com/
# Perl Time::Piece http://search.cpan.org/~esaym/Time-Piece-1.31/Piece.pm




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
use POSIX qw(ceil);
# use DateTime::Format::ISO8601;
use Time::Piece;
use Time::HiRes qw/ time sleep /;


# Logfile
our $logfilepath; 
our $lf;
our @loglevels;
our $loglevel=5;


# Use RAM disk 
# Parameters:
# 'Dirty' - Do all processing in RAM Disk
# 'Fast' - Copy back after every imported year
# 'Save' - Copy back after every imported month
# unset - off
our $use_ram_disk='Fast'; 

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
our $rrdfile = "$installfolder/data/plugins/$psubfolder/databases/$db_nr.rrd";
if (! -e $rrdfile) {
	logger(1, "RRD-File $rrdfile does not exist - Terminating");
	exit(7);
}
logger (3, "Using RRD-File $rrdfile");

# Check if rrdcached daemon is running
our $rrdcached = NULL; # RRDCache Daemon Sock
if (-S "/var/run/rrdcached.sock") {
		$rrdcached = "--daemon=unix:/var/run/rrdcached.sock";
		logger(3, "RRDCached is running - flushing RRD data");
		RRDs::flushcached($rrdcached, $rrdfile);
		my $ERR=RRDs::error;
		if ($ERR) {
			logger(2, "Error processing rrds::flushcached: $ERR");
		}
} else {
		logger(2, "RRDCached seems not to be running.");
}

# Try to use RAM disk for processing
if ($use_ram_disk) {
	logger(3, "RAM-Disk usage enabled with $use_ram_disk. Initializing RAM-Disk copy of database");
	if ((copy($rrdfile, "/run/") && -e "/run/") && (-w "/run/$db_nr.rrd")) {
		logger(3, " --> RAM-Disk copy initialized in /run/");
		our $persistent_rrdfile = $rrdfile;
		$rrdfile = "/run/$db_nr.rrd";
	} else {
		logger(2, " --> Could not initialize RAM-Disk copy - Continuing with direct disk write");
	}
}

# Get last update time 	
our $lastupdate_ep = RRDs::last($rrdfile);
my $ERR=RRDs::error;
if ($ERR) {
	logger(1, "Error processing rrds::last: $ERR");
}
logger(4, "RRD last update epoch RAW: $lastupdate_ep");

# If timestamp is earlier then 0 of Loxone-time, set it to Loxone-time 0 == 1230768000 Epoch
if ($lastupdate_ep < 1230768000) {
	$lastupdate_ep = 1230768000;
}

## Fast DEBUG - Start at a later time
##
# $lastupdate_ep = 1470009600;
##
##


# Try some time calculation for warming up
$lastupdate_str = strftime '%d.%m.%Y %H:%M:%S', localtime $lastupdate_ep;
logger(4, "RRD last update epoch processed: EPOCH $lastupdate_ep - Human Readable $lastupdate_str");

my $lastupdate_dt = DateTime->from_epoch( epoch => $lastupdate_ep ); 

my $lastupdate_month = $lastupdate_dt->month;
my $lastupdate_year = $lastupdate_dt->year;

my $now_dt = DateTime->now; 

# logger(4, "Current Perl process memory: " . get_current_process_memory());


logger(4, "RRD last update month year: $lastupdate_month/$lastupdate_year");

# Looping through month and year

# Year Loop
for (my $year=$lastupdate_year; $year <= $now_dt->year; $year++) {
	# Month loop
	foreach my $month (1...12) {
		# Skip month in resuming year
		if ($year == $lastupdate_year && $month < $lastupdate_month) {
			next;
		}
		
		# Calculate Timing
		my $start_run = time();
			
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
			my $stats = XML::LibXML->load_xml( string => $response->content);
		if ($@) {
			logger(2, "Could not read XML (continuing with next month): $@");
			# undef $stats;
			# undef $parser;
			next;
		} else {
			logger(4, "Seems that XML could be loaded");
		}
		# Copy yearly
		if ($month == 1) {
			copyramdisk('Fast');
		}
		
		
		# In $stats we should have our XML now
		# In case the XML root would be changed
		##my @nodes = $stats->findnodes('/Statistics');
		##my $node = @nodes[0];
		
		my $node = $stats->getDocumentElement;
		
		# $node->{Name} returns the name of the sensor
		# logger(4, "Node " . $node->{Name});
		
		my @dataset = $node->getChildrenByTagName("S");
				
		# Loop data
		# $data is each statistic datapoint
		#
		# Example data from Energy monitor
		# <S T="2016-08-17 23:47:00" V="0.572" V2="0.000"/>
		# <S T="2016-08-17 23:48:00" V="0.572" V2="0.000"/>
		
		# my @data_value_array;
		# my $data_array_nr = 0;
		
		our $data_counter = 0;
		our @data_value_array;
		
		foreach $data (@dataset) {
			# Possibly we have timezone issues - TO BE CHECKED
			our $data_time = Time::Piece->strptime ($data->{T}, "%Y-%m-%d %T");
			
			if ($lastupdate_ep >= $data_time->epoch) {
				next; 
			}
			
			$data_counter++;
			#logger(4, "   --> Datapoint Date/Time $data->{T} Epoch: " . $data_time->epoch . " Value: $data->{V}"); # Many logs
			push (@data_value_array, $data_time->epoch . ':' . $data->{V});
			
			# For every x datapoints update RRD
			if ($data_counter%2000 == 0) {
				rrdupdate();
			}	
		}
		
		# Final update after loop
		if (@data_value_array) {
			rrdupdate();
		}
		
		$lastupdate_ep = $data_time->epoch;

		# Copy monthly
		copyramdisk('Save');
		
		my $end_run = time();
		my $run_time = $end_run - $start_run;
	
		logger (3, "   Month $month/$year has overall $data_counter datapoints updated in " . ceil($run_time) . " seconds.");
		
		# We have to break out of the loop if we have reached the current year/month
		# Issue - if current month/year fails, this code is never reached to quit loop
		if ($year == $now_dt->year && $month == $now_dt->month) {
			last;
		}
	# End of month loop
	}
	
# End of year loop
}

# Copy finally in every case (also if it is possibly not required)
copyramdisk('Save');
copyramdisk('Fast');
copyramdisk('Dirty');
# Delete file from RAM-Disk
if (-e "/run/$db_nr.rrd") {
	unlink "/run/$db_nr.rrd";
}
		

#######################################################
# RRD Update
#######################################################
sub rrdupdate {

	logger (3, "    --> $data_counter Datapoints prepared for RRD update ...");
	# logger (4, $data_value_string);
	RRDs::update($rrdfile, @data_value_array);
	# --skip-past-updates not supported with rrdtool 1.4.8 (first with 1.5.0) - this might get a problem
	my $ERR=RRDs::error;
	if ($ERR) {
		logger(1, "Error processing rrds::update: $ERR");
	}	
	undef @data_value_array;
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
		
		# Heavily reduces performance - only for debugging!
		# $memusage = ceil(get_current_process_memory()/1024) . " KiB";
		
		if ( $loglevel == 5 ) {
			($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = CORE::localtime(time);
			my $now_string = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
			print STDERR "$now_string $memusage Stats4Lox import.cgi $loglevels[$level]: $message\r\n";
		} elsif ( $level <= $loglevel && $loglevel <= 4) {
			($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = CORE::localtime(time);
			my $now_string = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
			print $lf "$now_string $memusage $loglevels[$level]: $message\r\n";
		}
	}

#############################################################
# copyramdisk	
#############################################################

sub copyramdisk 
{
	my ($mode) = @_;
	# from ... source
	# to ... destination
	# mode ... 'Fast', 'Save', 'Dirty'
	
	# If RAM-Disk 'Fast' is used, copy back the file
	if ($use_ram_disk eq $mode && $persistent_rrdfile) {
		if (copy($rrdfile, $persistent_rrdfile)) {
			logger(3, " --> RAM-Disk database copied back (Mode $mode)");
		} else {
			logger(1, " --> Could not copy the RAM-Disk database back to disk!");
		}
	}
}

#############################################################
# Get process memory
# This call heavily reduces performance - only for debugging
#############################################################
sub get_current_process_memory {
	use Proc::ProcessTable;
	CORE::state $pt = Proc::ProcessTable->new;
	my %info = map { $_->pid => $_ } @{$pt->table};
	return $info{$$}->rss;
}
