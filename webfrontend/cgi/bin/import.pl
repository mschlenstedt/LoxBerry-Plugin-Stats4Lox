#!/usr/bin/perl

# import.pl

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
# OK 	Initiale Pfade berechnen
# OK 	Commandline-Parameter lesen
# OK 	Logfile initialisieren
# OK 	Umbenennen des Jobs in .running.PID
# OK 	Job lesen
# OK 	Miniserver-Credentials aus Loxberry-DB lesen
# OBS 	RRD-Pfad aus Statistik-DB auslesen (-->ist nur die Nummer, nicht notwendig)
# OK 	evt. RRD-Steps aus RRD-File lesen 
# OK 	Aus RRD letzten Timestamp lesen (epoch) und in Monat/Jahr umrechnen
# OK 	Loop über Monat/Jahr bis heute
# OK  		Datenfile als XML vom MS holen
# OK  		Loop
# OBS  			Ergänzen des XML um Zeit in Epoch (-> nicht erforderlich)
#    			evt. INSERT für relationale DB erstellen
# OK			Abhängig vom Statstype
# OK			-> Werte interpolieren und ins XML-Objekt schreiben
# OK   			Loop 
# OK     			Commandline mit Datensätzen erstellen
# OK 				Datensätze schreiben
# OK 	Job aufräumen
#     	evt. Polling starten

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
use File::Basename;
use File::HomeDir;
use File::Copy;
use File::Path qw(make_path);
use Cwd 'abs_path';
use DateTime;
use RRDs;
use POSIX qw(strftime);
use POSIX qw(ceil);
use POSIX qw(tzset);
# use DateTime::Format::ISO8601;
use Time::Piece;
use Time::HiRes qw/ time sleep /;
 

# Logfile
our $logfilepath; 
our $lf;
our @loglevels;

our	%StatTypes = ( 	1, "Jede Änderung (max. ein Wert pro Minute)",
					2, "Mittelwert pro Minute",
					3, "Mittelwert pro 5 Minuten",
					4, "Mittelwert pro 10 Minuten",
					5, "Mittelwert pro 30 Minuten",
					6, "Mittelwert pro Stunde",
					7, "Digital/Jede Änderung");
					
our	%StatSteps = ( 	1, 60,
					2, 60,
					3, 300,
					4, 600,
					5, 1800,
					6, 3600,
					7, 60);
					
# Use loglevel with care! DEBUG=4 really fills up logfile. Use ERRORS=1 or WARNINGS=2, or disable with 0.
# To log everything to STDERR, use $loglevel=5.
our $loglevel=4;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.1.4";

# Figure out in which subfolder we are installed
# Does not work (returns 'bin')
# our $psubfolder = abs_path($0);
# $psubfolder =~ s/(.*)\/(.*)\/bin\/(.*)$/$2/g;
$psubfolder = 'stats4lox';

# my $home = File::HomeDir->my_home;
$home = '/opt/loxberry';
# Issues with running from command line


print STDERR "Home: $home Pluginsubfolder $psubfolder\n";
my $job_basepath = "$home/data/plugins/$psubfolder/import";

my $cfg             = new Config::Simple("$home/config/system/general.cfg");
my $lang            = $cfg->param("BASE.LANG");
my $installfolder   = $cfg->param("BASE.INSTALLFOLDER");
my $miniservers     = $cfg->param("BASE.MINISERVERS");
my $clouddns        = $cfg->param("BASE.CLOUDDNS");
my $timezone		= $cfg->param("TIMESERVER.ZONE");

if ($timezone) {
	$ENV{TZ} = $timezone;
	tzset();
}

#
# Commandline options
#

my $jobname = '';

GetOptions ('loglevel=s' => \$loglevel,
            'job=s' => \$jobname,
			'file=s' => \$jobfile
            );

if 	($jobfile) {
	my($filename, $dirs, $suffix) = fileparse($jobfile);
	($jobname) = (split /\./, $filename)[0];
	# print STDERR "Jobile: $jobfile Jobname: $jobname \n";

	# move ("$jobfile", "$job_basepath/$jobname.job");
}		
			
			
			
#
# Initialize logfile
#
			
$logfilepath = "$home/log/plugins/$psubfolder/import_$jobname.log";
openlogfile();
logger(4, "Logfile $logfilepath opened");

####################################
# Rename jobfile to .running.$$
####################################

# Check if the job file exists and is writeable
if ((! -w "$job_basepath/$jobname.job") && (! $jobfile)) {
	logger(1, "Job $jobname does not exist or not writeable in $job_basepath - Terminating");
	exit(1);
}

# Rename the job file
if ((! $jobfile) && (! move("$job_basepath/$jobname.job", "$job_basepath/$jobname.running.$$"))) {
	logger(1, "Job $job_basepath/$jobname.job could not be renamed to .running.$$ - Terminating");
	exit(2);
}
if (($jobfile) && (! move("$jobfile", "$job_basepath/$jobname.running.$$"))) {
	logger(1, "Jobfile $jobfile could not be renamed to .running.$$ - Terminating");
	exit(2);
}



if (! -s "$job_basepath/$jobname.running.$$") {
	logger(1, "Job $jobname is empty $job_basepath - Terminating");
	exit(1);
}

###################################
# Read job file
###################################

our $job = new Config::Simple("$job_basepath/$jobname.running.$$");
# our $job = new Config::Simple("$job_basepath/$jobname.job");

my $loxonename = $job->param("loxonename");
my $loxuid = $job->param("loxuid");
our $statstype = $job->param("statstype");
my $description = $job->param("description");
my $settings = $job->param("settings");
my $minval = $job->param("minval");
my $maxval = $job->param("maxval");
my $place = $job->param("place");
my $category = $job->param("category");
my $ms_nr = $job->param("ms_nr");
my $db_nr = sprintf("%04d", $job->param("db_nr"));
my $import_epoch = $job->param("import_epoch");
my $job_useramdisk = $job->param("useramdisk");
my $job_loglevel = $job->param("loglevel");
my $importtype = $job->param("importtype");

$job->param("Last status",	"Running");
$job->write();

# Use RAM disk 
# Parameters:
# 'Dirty' - Do all processing in RAM Disk
# 'Fast' - Copy back after every imported year
# 'Save' - Copy back after every imported month
# unset - off
our $use_ram_disk = 'Save'; 
our $ramdiskpath = '/dev/shm/stats4loximport';

# Check the important values for further processing
logger(3, "JOB $jobname for statistic $loxonename ($place/$category) on Miniserver $ms_nr, statistic db is $db_nr");
logger(3, "JOB Statistic Type is $statstype ($StatTypes{$statstype})");
logger(3, "== Full job path currently is $job_basepath/$jobname.running.$$ ==");

if ($ms_nr < 1) 		{ logger(1, "Miniserver not defined - Terminating"); exit(3);}
if ($db_nr < 1) 		{ logger(1, "RRD DB number not defined - Terminating"); exit(4);}
if (! $loxuid)			{ logger(1, "Loxone UID not defined - Terminating"); exit(5);}
if ($statstype < 1)		{ logger(1, "Loxone Statistic type not defined - Terminating"); exit(6);}
if ($statstype > 7)		{ logger(2, "This Loxone statistic has an UNSUPPORTED statistic type. Continuing ... but I've told you!"); }
if ($job_useramdisk)	{ $use_ram_disk = $job_useramdisk; }
if ($job_loglevel)		{ $loglevel = $job_loglevel; }

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
		$miniserverip   =  $fields2[0];
		$miniserverport = $fields2[1];
	}

	logger(4, "Miniserver-IP $miniserverip:$miniserverport");
	
	
##############################
# Some RRD file processing 
##############################

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
	logger(3, "RAM-Disk usage enabled with mode '$use_ram_disk'. Initializing RAM-Disk copy of database");
	make_path($ramdiskpath);
	if ((copy($rrdfile, "$ramdiskpath/") && -e "$ramdiskpath/") && (-w "$ramdiskpath/$db_nr.rrd")) {
		logger(3, " --> RAM-Disk copy initialized in $ramdiskpath");
		our $persistent_rrdfile = $rrdfile;
		$rrdfile = "$ramdiskpath/$db_nr.rrd";
	} else {
		logger(2, " --> Could not initialize RAM-Disk copy on $ramdiskpath - Continuing with direct disk write");
	}
}

# Get RRD infos
my $rrdinfo = RRDs::info ($rrdfile);
my $ERR=RRDs::error;
if ($ERR) {
	logger(1, "Error processing RRDs::info: $ERR");
	logger(1, "Assuming lastupdate=never and stepsize=300. There might come up more troubles later...");

	our $lastupdate_ep = 0;
	our $rrd_step = 300;
} else {
	our $lastupdate_ep = $$rrdinfo{'last_update'};
	our $rrd_step = $$rrdinfo{'step'};
}
logger(4, "RRD lastupdate (epoch): $lastupdate_ep , Stepsize $rrd_step seconds.");

# If timestamp is earlier then 0 of Loxone-time, set it to Loxone-time 0 == 1230768000 Epoch
if ($lastupdate_ep < 1230768000) {
	$lastupdate_ep = 1230768000;
}

## Fast DEBUG - Start at a later time
##
# $lastupdate_ep = 1470009600;
##
##

my $lastupdate = Time::Piece->new();
$lastupdate = $lastupdate->strptime($lastupdate_ep, '%s');

my $lastupdate_month = $lastupdate->mon;
my $lastupdate_year = $lastupdate->year;

my $now = Time::Piece->localtime; 

# logger(4, "Current Perl process memory: " . get_current_process_memory());

logger(4, "RRD last update epoch processed: EPOCH $lastupdate_ep - Human Readable $lastupdate");
logger(4, "RRD last update month year: $lastupdate_month/$lastupdate_year");

# Looping through month and year

# Year Loop
for (my $year=$lastupdate_year; $year <= $now->year; $year++) {
	# Month loop
	foreach my $month (1...12) {
		# Skip month in resuming year
		if ($year == $lastupdate_year && $month < $lastupdate_month) {
			next;
		}
		
		# Calculate Timing
		my $start_run = time();
			
		# Example URL http://192.168.0.77/stats/00ac8517-0961-11e1-99b9f25d750310ed.201207.xml
		
		# URI-Encode of UTF-8 strings
		# http://lwp.interglacial.com/ch05_02.htm
		# Possibly required for auth processing against Loxone
		# use URI::Escape qw( uri_escape_utf8 );
		# $esc = uri_escape_utf8( some string value )
	
		$statsurl = sprintf("http://$miniserveradmin:$miniserverpass\@$miniserverip:$miniserverport/stats/$loxuid.%04d%02d.xml", $year, $month);
		my $statsurl_log = sprintf("http://$miniserveradmin:*****\@$miniserverip:$miniserverport/stats/$loxuid.%04d%02d.xml", $year, $month);
		logger(4, "== DOWNLOAD == $month/$year with URL $statsurl_log ");
		
		# Fetching data with UserAgent
		my $ua = LWP::UserAgent->new();
		$ua->timeout(10);
		my $response = $ua->get($statsurl);
		if (! $response->is_success) {
			logger(2, "Downloading of XML failed - possibly non-existing month (continuing with next month): $response->status_line");
			next;
		}
		
		my $parser = XML::LibXML->new();
		our $stats = XML::LibXML->load_xml( string => $response->content, 
											   no_blanks => 1);
		if ($@) {
			logger(2, "Could not read XML (continuing with next month): $@");
			# undef $stats;
			# undef $parser;
			next;
		} else {
			logger(3, "=============== $month/$year === STARTED XML processing ===============================");
		}
		# Copy yearly
		if ($month == 1) {
			copyramdisk('Fast');
		}
		
		# In $stats we should have our XML now
		# In case the XML root would be changed
		##my @nodes = $stats->findnodes('/Statistics');
		##my $node = @nodes[0];
		
		our $root = $stats->getDocumentElement;
		
		# $root->{Name} returns the name of the sensor
		# logger(4, "Node " . $node->{Name});
		
		our @dataset = $root->getChildrenByTagName("S");
				
		##################
		# Interpolation
		##################
		# Decide if we need to interpolate or not. This is depending on the step sizes and Loxone statistic type
		# 1, "Jede Änderung (max. ein Wert pro Minute)",
		# 2, "Mittelwert pro Minute",
		# 3, "Mittelwert pro 5 Minuten",
		# 4, "Mittelwert pro 10 Minuten",
		# 5, "Mittelwert pro 30 Minuten",
		# 6, "Mittelwert pro Stunde",
		# 7, "Digital/Jede Änderung");
		
		# Conditions 
		# 1 and 7 need to be filled up in rrd_step interval anyhow
		# For 7, additionally the last node has to be duplicated at epoch-1
		# 2 to 6 need to be filled up if rrd_step < steptype
		
		if ($statstype == 1 || $statstype == 7 || $rrd_step < $StatSteps{$statstype}) {
			logger(3, "   Interpolation started to fill up missing values - Raw data: " . keys @dataset);
			my $interpolation_count = 0;
			
			# Interpolate from last node of last working month to first current node, using the last node of the last month
			if ($last_node_from_last_month) {
				$interpolation_count+= interpolate($last_node_from_last_month, $root->firstChild, $last_node_from_last_month->{V});
				logger (4, "    Last month data: " . $last_node_from_last_month->{T} . " Value: " . $last_node_from_last_month->{V});
			}
			
			# Interpolate between values and at the end of the month
			foreach $data (@dataset) {
				my $nextnode = $data->nextSibling();
				$interpolation_count+= interpolate($data, $nextnode, $data->{V});
			}
						
			@dataset = $root->getChildrenByTagName("S");
		
			logger(3, "   Interpolation finished - Added data: $interpolation_count, Data count now " . keys @dataset);
			
					
		# End of interpolation
		}
		
		# Save the latest node of this month for possible interpolation in the next month
		our $last_node_from_last_month = $root->lastChild;
		
		# Loop data
		# $data is each statistic datapoint
		#
		# Example data from Energy monitor
		# <S T="2016-08-17 23:47:00" V="0.572" V2="0.000"/>
		# <S T="2016-08-17 23:48:00" V="0.572" V2="0.000"/>
		
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
	
		logger (3, "   $data_counter datapoints updated in " . ceil($run_time) . " seconds.");
		logger (3, "=============== $month/$year === FINISHED =============================================");
		# We have to break out of the loop if we have reached the current year/month
		# Issue - if current month/year fails, this code possibly is never reached to quit loop
		if ($year >= $now->year && $month >= $now->mon) {
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

$job->param("Last status",	"Finished Import!");
$job->write();

# If job requests to immediately start live polling
if ($importtype eq 'import_start') {
	logger(3, "=== Start live polling requested ===");
	if (open(F,">$installfolder/data/plugins/$psubfolder/databases/$db_nr.status")) {
		flock(F, 2);
		print F "2";
		close F;
        logger(4, "   Statistic status set to 2 (0=stopped, 1=paused, 2=running, 3=?");
		$job->param("Last status",	"Finished Import and started polling!");
		$job->write();

	} else {
		logger(2, "   Start of live polling could not be initiated. Please try manually.");
		$job->param("Last status",	"Finished Import! But could not start polling.");
		$job->write();
	}
}

# Rename the job file
if (! move("$job_basepath/$jobname.running.$$", "$job_basepath/$jobname.finished")) {
	logger(2, "Job $job_basepath/$jobname.running.$$ could not be renamed to .finished.");
}
logger(3, "=== Job finished. ===");

# Cleaning up RAM-Disk in every case
END 
{
	# Delete file from RAM-Disk
	if (-e "$ramdiskpath/$db_nr.rrd") {
		unlink "$ramdiskpath/$db_nr.rrd";
	}
}		

#######################################################
# RRD Update
#######################################################
sub rrdupdate 
{

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
# Interpolation 
# Used globals: 
# 	$stats (DOM-Object)
#	$root (Root element of DOM)
#	$rrd_step (Step size of RRD)
#	$statstype
# 	$interpolation_count
# Parameters:
# 1. current node
# 2. next node
# 3. value
# If 'current node' is undefined, filling up before first node of root
# If 'next node' is undefined, filling up after last node of root
#####################################################
sub interpolate
{
	my ($currentnode, $nextnode, $value) = @_;
	
	my $counter=0;
	my $node_time;
	my $next_time;
	
	#logger (4, "    Current --> $currentnode");
	#logger (4, "    Next    --> $nextnode");
	
	
	if ((! $currentnode) && (! $nextnode)) {
		return 0;
	}
	
	if ($currentnode && $nextnode) {
		$node_time = Time::Piece->strptime ($currentnode->{T}, "%Y-%m-%d %T");
		$next_time = Time::Piece->strptime ($nextnode->{T}, "%Y-%m-%d %T");
	} elsif (! $currentnode) {
		$next_time = Time::Piece->strptime ($nextnode->{T}, "%Y-%m-%d %T");
		$node_time = Time::Piece->strptime ($next_time->year . "-" . $next_time->mon, "%Y-%m");
		# logger(4, "    XXX Currentnode not set --> start time $node_time next time $next_time");
	} else {
		$node_time = Time::Piece->strptime ($currentnode->{T}, "%Y-%m-%d %T");
		$next_time = Time::Piece->strptime ($node_time->year . "-" . $node_time->mon, "%Y-%m");
		$next_time = $next_time->add_months(1) - 1;
		# logger(4, "    XXX Nextnode not set --> start time $node_time next time $next_time");
		
	}
	
	#logger (4, "    Calculated start: " . $node_time);
	#logger (4, "    Calculated end:   " . $next_time);
	
	# my $currenttime = localtime;
	if ($next_time > Time::Piece->localtime) {
		$next_time = Time::Piece->localtime;
	}
	
	for (my $stepper = ($node_time+$rrd_step); $stepper < ($next_time); $stepper+=$rrd_step) {
		# logger(4, "Intepolation value: " . $stepper->strftime("%Y-%m-%d %T"));
		my $insertnode = $stats->createElement('S');
		$insertnode->{T} = $stepper->strftime("%Y-%m-%d %T");
		$insertnode->{V} = $value;
		if ($nextnode) {
			$root->insertBefore( $insertnode, $nextnode );
			# logger(4, "    $insertnode InsertBEFORE $nextnode");
		} else {
			$root->insertAfter( $insertnode, undef );
			# logger(4, "    $insertnode InsertAFTER (at the end)");
		}
		$counter++;
	}
	# Finally, if statstype is 7, add the last value at nextnode-time -1
	if ($statstype == 7 && $currentnode && $nextnode) {
		my $insertnode = $stats->createElement('S');
		my $lastbeforechange = $next_time-1;
		$insertnode->{T} = $lastbeforechange->strftime("%Y-%m-%d %T");
		$insertnode->{V} = $value;
		$root->insertBefore( $insertnode, $nextnode);
		$counter++;
	}
	
	return $counter;
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
		print STDERR "$now_string $memusage Stats4Lox import.pl $loglevels[$level]: $message\r\n";
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
