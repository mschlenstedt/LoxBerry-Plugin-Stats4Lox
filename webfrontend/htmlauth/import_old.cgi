#!/usr/bin/perl

# Copyright 2016-2017 Christian Fenzl, christiantf@gmx.at
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


##########################################################################
# Modules
##########################################################################

use LoxBerry::System;
require "$lbpbindir/libs/Stats4Lox.pm";
use LoxBerry::Web;
use warnings;
use strict;

# use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use File::Basename;
use File::stat;
use HTML::Entities;
use Time::HiRes qw/ time sleep /;
use XML::LibXML;

## Removed with 0.3.1
# use Config::Simple;
# use Cwd 'abs_path';
# use File::HomeDir;
# use File::Path qw(make_path);
# use HTTP::Request;
# #use HTML::Restrict;
# use LWP::UserAgent;
# use POSIX qw(strftime);
# use Socket;
# use String::Escape qw( unquotemeta );
# use URI::Escape;
# use XML::Simple qw(:strict);

# Christian Import
# use Time::localtime;
# Debug

# Set maximum file upload to approx. 7 MB
# $CGI::POST_MAX = 1024 * 10000;

use strict;
no strict "refs"; # we need it for template system

our $namef;
our $value;
our %query;
our @fields;
our @lines;
my $home = $lbhomedir;
our %cfg_mslist;
our $upload_message;
our $stattable;
our %lox_statsobject;

# Logfile
our $logfilepath; 
our $lf;
our @loglevels;
our $loglevel=4;

# Use loglevel with care! DEBUG=4 really fills up logfile. Use ERRORS=1 or WARNINGS=2, or disable with 0.
# To log everything to STDERR, use $loglevel=5.

our %StatTypes = ( 	1, "Jede Änderung (max. ein Wert pro Minute)",
					2, "Mittelwert pro Minute",
					3, "Mittelwert pro 5 Minuten",
					4, "Mittelwert pro 10 Minuten",
					5, "Mittelwert pro 30 Minuten",
					6, "Mittelwert pro Stunde",
					7, "Digital/Jede Änderung");		

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "0.3.1.2";

# Figure out in which subfolder we are installed
our $psubfolder = $lbpplugindir;

$logfilepath = "$home/log/plugins/$psubfolder/import_cgi.log";
openlogfile();
logger(4, "Logfile $logfilepath opened");

our $job_basepath = "$home/data/plugins/$psubfolder/import";

my  $cfg             = new Config::Simple("$home/config/system/general.cfg");
our $installfolder   = $cfg->param("BASE.INSTALLFOLDER");
our $lang            = $cfg->param("BASE.LANG");
our $miniservercount = $cfg->param("BASE.MINISERVERS");
our $clouddnsaddress = $cfg->param("BASE.CLOUDDNS");
our $curlbin         = $cfg->param("BINARIES.CURL");
our $grepbin         = $cfg->param("BINARIES.GREP");
our $awkbin          = $cfg->param("BINARIES.AWK");
our $timezone		 = $cfg->param("TIMESERVER.ZONE");

# Generate MS table with IP as key
# We need this to have a Loxone-UID -> IP -> Stats-DB matching/key
for (my $msnr = 1; $msnr <= $miniservercount; $msnr++) {
	$cfg_mslist{$cfg->param("MINISERVER$msnr.IPADDRESS")} = $msnr;
}

#########################################################################
# Parameter
#########################################################################

# Everything from URL
our $saveformdata;
foreach (split(/&/,$ENV{'QUERY_STRING'}))
{
  ($namef,$value) = split(/=/,$_,2);
  $namef =~ tr/+/ /;
  $namef =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $value =~ tr/+/ /;
  $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $query{$namef} = $value;
}

# Set parameters coming in - get over post
  if ( !$query{'saveformdata'} ) { 
	if ( param('saveformdata') ) { 
		$saveformdata = quotemeta(param('saveformdata')); 
	} else { 
		$saveformdata = 0;
	} 
  } else { 
	$saveformdata = quotemeta($query{'saveformdata'}); 
}

if ( !$query{'lang'} ) {
	if ( param('lang') ) {
		$lang = quotemeta(param('lang'));
	} else {
		$lang = "de";
	}
} else {
	$lang = quotemeta($query{'lang'}); 
}

# Clean up saveformdata variable
$saveformdata =~ tr/0-1//cd;
$saveformdata = substr($saveformdata,0,1);

# Save if button save was pressed
my $doapply;
if ( param('submitbtn') ) { $doapply = 1; }

# Init Language
# Clean up lang variable
$lang =~ tr/a-z//cd;
$lang = substr($lang,0,2);

# If there's no language phrases file for choosed language, use german as default
if (!-e "$installfolder/templates/plugins/$psubfolder/$lang/language.dat") {
	$lang = "de";
}

# Read translations / phrases
our $planguagefile = "$installfolder/templates/plugins/$psubfolder/$lang/language.dat";
our $pphrase = new Config::Simple($planguagefile);

# Default file for reading and writing LoxPLAN file
our $loxconfig_path = "$installfolder/data/plugins/$psubfolder/upload.loxplan";

##########################################################################
# Main program
##########################################################################

our $post = new CGI;

if ( $post->param('Upload') ) {
	saveloxplan();
	form();
	
} elsif ($doapply) {
  save();
  form();
} else {
  form();
}

exit;

#####################################################
# 
# Subroutines
#
#####################################################

#####################################################
# Form-Sub
#####################################################

sub form {

	my $loxchgtime;
	my $loxjsonchgtime;
	# Prepare the form
	
	# Check if a .LoxPLAN is already available
		
	if ( -e $loxconfig_path ) {
		my $loxchgtime = new Time::Piece(stat($loxconfig_path)->mtime);
		$upload_message = "Die zuletzt hochgeladene Loxone-Konfiguration ist von " . $loxchgtime->dmy(".") . " " . $loxchgtime->hms . ". Du kannst eine neuere Version hochladen, oder die zuletzt hochgeladene verwenden.";
	} else {
		$upload_message = "Lade deine Loxone Konfiguration (.loxone bzw. .LoxPlan Datei) hoch. Daraus wird ausgelesen, welche Statistiken du aktuell aktiviert hast.";
	}
	if ( -e "/tmp/stats4lox_loxplan.json" and stat("/tmp/stats4lox_loxplan.json")->mtime > $loxchgtime) {
		my $jsonparser = Stats4Lox::JSON->new();
		my $loxplanjson = $jsonparser->open(filename => "/tmp/stats4lox_loxplan.json");
		%lox_statsobject = %{$loxplanjson->{stats4lox}};
	}	
	else {
		readloxplan();
	}
	
	our $table_linecount = 0;
	generate_import_table();
		
	
	# Print the template #
	######################
	
	# Print header
	our $helplink = "http://www.loxwiki.eu:80/x/uYCm";
	Stats4Lox::navbar_main(20);
	LoxBerry::Web::lbheader("Statistics 4 Loxone", $helplink, "help.html");
  
		
	
	
	# Print Upload Template #
	#########################
	open(F,"$installfolder/templates/plugins/$psubfolder/multi/loxplan_uploadform.html") || die "Missing template plugins/$psubfolder/multi/loxplan_uploadform.html";
	  while (<F>) 
	  {
	    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
	    print $_;
	  }
	close(F);

	# Print table Template
	
	open(F,"$installfolder/templates/plugins/$psubfolder/multi/import_selection.html") || die "Missing template plugins/$psubfolder/multi/import_selection.html";
	  while (<F>) 
	  {
		$_ =~ s/<!--\$(.*?)-->/${$1}/g;
#	    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
	    print $_;
	  }
	close(F);
	
	
	LoxBerry::Web::lbfooter();
	exit;

}

#####################################################
# Save-Sub
#####################################################

sub save 
{

	my $resp_dbnr;
	#	&footer;

	# On saving form, parse form data and create import jobs in FS
	my $form_linenumbers = param("linenumbers");
		
	if ($form_linenumbers <= 0) { 
		logger(2, "Seems to have empty POST data. (Form Linenumbers: " . $form_linenumbers . ")");
		return; 
	}
	
	# Looping through post formdata lines
	
	# my $addstat_urlbase = "http://localhost/admin/plugins/$psubfolder/addstat.cgi";
	# my $addstat_basecommand = "perl $home/webfrontend/cgi/plugins/$psubfolder/addstat.cgi";
	  my $addstat_basecommand = "./addstat.cgi";
	
	eval { make_path($job_basepath) };
	if ($@) {
		logger(1, "Couldn't create $job_basepath: $@");
	}
		
	logger(4, "Stats import path: $job_basepath");
	
	# Read databases file for names and db id's for uniquness check
	my %databases_by_name = Stats4Lox::get_databases_by_name();
	
	for (my $line = 1; $line <= $form_linenumbers; $line++) {
		logger(4, "Line " . $line . ": UID " . param("loxuid_" . $line));
		my $importtype = param("doimport_$line");
		if (($importtype ne 'import') && ($importtype ne 'import_start' )) {
				next;
		}
		logger(4, "IMPORT Line " . $line . ": UID " . param("loxuid_$line"));

		# Call Michaels addstat.cgi by URL to create RRD archive
		my $loxonename = param("title_$line");
		my $loxuid = param("loxuid_$line");
		my $statstype = param("statstype_$line");
		my $description = param("desc_$line");
		my $settings = param("statdef_$line");
		my $minval = param("minval_$line");
		my $maxval = param("maxval_$line");
		my $place = param("place_$line");
		my $category = param("category_$line");
		my $stat_ms = param("msnr_$line");
		my $unit = param("unit_$line");
		my $loxtype = param("type_$line");
		

		# Check if loxonename already exists in databases list
		if (! defined $databases_by_name{lc($loxonename)}) {
		
			# Call addstat by commandline
			# Example from Michael
			# ./addstat.cgi 
			# --script 
			# --settings 1 
			# --loxonename "Akt Luftfeuchtigkeit" 
			# --miniserver 1 
			# --description "Luftfeuchtigkeit 289c2d05a8-8602-11e3-89cfb70a5529d684" 
			# --min U 
			# --max 100 
			# --place "Wohnzimmer" 
			# --category "Klima" 
			# --uid "289c2d05a8-8602-11e3-89cfb70a5529d684" 
			# --unit "%"
			# --block "Virtual Status" 
		
			my $commandline_options = 
			"--script " .
			"--settings=$settings " .
			"--loxonename=\"$loxonename\" " . 
			"--miniserver=$stat_ms " .
			"--description=\"$description\" " .
			"--min=$minval " .
			"--max=$maxval " .
			"--place=\"$place\" " .
			"--category=\"$category\" " .
			"--uid=$loxuid " .
			"--unit=\"$unit\" " .
			"--block=\"$loxtype\" ";
			
			logger (4, "Statistic is new - calling addstat " . $commandline_options);
			# Call the command
			my $message = `perl $addstat_basecommand $commandline_options`;		
			logger (4, "addstat command reply: " . $message);
			
			# Format addstat response to get useful output
			my @stat_message = split /\+/, $message;
			logger(4, "Resp_Status: $stat_message[3] Resp_Text $stat_message[6] Resp_DBID $stat_message[9]");
			my $resp_status = $stat_message[3];
			my $resp_message = $stat_message[6];
			$resp_dbnr = $stat_message[9];
			if ($resp_status eq "OK" && $resp_dbnr > 0) {
				# Addstat successfully called 
				logger(3, "addstat - RRD successfully created with DB-Nr $resp_dbnr");
			} else {
				# Addstat running but failed - exit this statistic and go further
				logger(2, "addstat not successfully. Returned $resp_status - $resp_message");
				next;
			}

		} else {
			# This is what happens if loxonename is a duplicate
			logger (4, "Database already exists - directly create import job without addstat");
			$resp_dbnr = $databases_by_name{lc($loxonename)}{dbid};
		}
		
		#
		# Creating the job
		# 
		
		if ($resp_dbnr > 0)	{
			# Check if a job is already running
			if (! glob("$job_basepath/$loxuid.running.*" )) {
				# Not running - create job
				my $job = new Config::Simple(syntax=>'ini');
				$job->param("loxonename", 	uri_unescape($loxonename));
				$job->param("loxuid", 		$loxuid);
				$job->param("statstype", 	$statstype);
				$job->param("description", 	uri_unescape($description));
				$job->param("settings",		$settings);
				$job->param("minval",		$minval);
				$job->param("maxval",		$maxval);
				$job->param("place",		uri_unescape($place));
				$job->param("category",		uri_unescape($category));
				$job->param("ms_nr",		$stat_ms);
				$job->param("db_nr",		$resp_dbnr);
				$job->param("import_epoch",	"0");
				$job->param("useramdisk",	"Fast");
				$job->param("loglevel",		"4");
				$job->param("Last status",	"Scheduled");
				$job->param("try",			"1");
				$job->param("maxtries",		"5");
				$job->param("importtype",	$importtype);
				
				
				
				$job->write("$job_basepath/$loxuid.job") or logger (1, "Could not create job file for $loxonename with DB number $resp_dbnr");
				undef $job;
			} else { 
				# Running state - do not create new job
				logger (2, "Job $loxonename ($loxuid) is currently in 'Running' state and will not be created again.");
			}
		}	
			
	
	# End of lines loop
	}
	# For debugging, quit everything (will generate an error 500)
	# exit;
		
}


#####################################################
# Save Loxplan file
#####################################################

sub saveloxplan
{
	# Funktioniert nicht - $upload-filehandle leer...?!
	my $cgi = new CGI();
	my $upload_filehandle = $cgi->upload('loxplan');
	if (! $upload_filehandle ) {
		logger(1, "LoxPLAN Upload - Stream filehandle not created.");
		exit (-1);
	}
	if (! open(UPLOADFILE, ">$loxconfig_path" ) ) {
		logger("ERROR: LoxPLAN Upload - cannot open local file handle.");
		exit (-1);
	}
	# binmode UPLOADFILE;

	while (<$upload_filehandle>) {
		print UPLOADFILE "$_";
	}
	close $upload_filehandle;
	close UPLOADFILE;
	return;

}


 
 
#####################################################
# Generate HTML Import Table
#####################################################

sub generate_import_table 
{
	# Define Row colors for import state
	my %ImportStates = (
		"none" 		=> "white", 
		"failed" 	=> "#ffa0a0",
		"scheduled"	=> "#d3d3d3",
		"running"	=> "#d9ff1e",
		"finished"	=> "#a2f99d"
		);
	
	# Get job status from file system
	
	my @failedlist = <"$job_basepath/*.failed">;
	my @finishedlist = <"$job_basepath/*.finished">;
	my @joblist = <"$job_basepath/*.job">;
	my @runninglist = <"$job_basepath/*.running.*">;
	
	foreach my $job (@failedlist) {
	
		my $jobname = get_jobname_from_filename($job);
		if (exists $lox_statsobject{$jobname}) {
			$lox_statsobject{$jobname}{TableColor} = $ImportStates{'failed'};
		}
	}
	foreach my $job (@finishedlist) {
	
		my $jobname = get_jobname_from_filename($job);
		if (exists $lox_statsobject{$jobname}) {
			$lox_statsobject{$jobname}{TableColor} = $ImportStates{'finished'};
		}
	}
	foreach my $job (@joblist) {
	
		my $jobname = get_jobname_from_filename($job);
		if (exists $lox_statsobject{$jobname}) {
			$lox_statsobject{$jobname}{TableColor} = $ImportStates{'scheduled'};
		}
	}
	foreach my $job (@runninglist) {
	
		my $jobname = get_jobname_from_filename($job);
		if (exists $lox_statsobject{$jobname}) {
			$lox_statsobject{$jobname}{TableColor} = $ImportStates{'running'};
		}
	}
	
	# Read Stat definitions and prepare dropdown string
	# Read dbsettings names
	my %dbsettings = Stats4Lox::get_dbsettings();
	our $statstable;
	our $table_linecount = 0;	
	# Loop the statistic objects
	foreach my $statsobj (sort keys %lox_statsobject) {
	#foreach my $statsobj (sort  {$lox_statsobject{$b}{Title} <=> $lox_statsobject{$a}{Title}}    keys (%lox_statsobject)) {
		$table_linecount = $table_linecount + 1;
		
		my $statdef_dropdown = "<select data-mini=\"true\" name=\"statdef_$table_linecount\">\n";
		my $statdef_nr = 0;
		my $statdef;
		foreach $statdef (sort keys %dbsettings) {
			$statdef_nr++;
		# Preselect Nr. 2 (Energy-Definition) if Loxone-Stat is "Energy", else Nr. 1
		if ((($statdef_nr == 1) && ($lox_statsobject{$statsobj}{Type} ne "Energy")) || 
				(($statdef_nr == 2) && ($lox_statsobject{$statsobj}{Type} eq "Energy"))) {
				$statdef_dropdown .= "<option selected value=\"$statdef_nr\">$dbsettings{$statdef}{Name}</option>\n";
			} else {
				$statdef_dropdown .= "<option value=\"$statdef_nr\">$dbsettings{$statdef}{Name}</option>\n";
			}
		}
		$statdef_dropdown .= "</select>\n";
			
		# logger (4, $statsobj{Title});
		# UNFINISHED 
		# Set Statistic Definitions from Michael
		$statdef = "1";
		
		if (! $lox_statsobject{$statsobj}{TableColor}) {
			$lox_statsobject{$statsobj}{TableColor} = $ImportStates{'none'};
		}
		
		# Tabellenbug! OFFEN! Farbe wird nicht mitsortiert!
		
		$statstable .= '
			  <tr bgcolor="' . $lox_statsobject{$statsobj}{TableColor} . '">
				<td class="tg-yw4l">' . encode_entities($lox_statsobject{$statsobj}{Title}) . '<input type="hidden" name="title_' . $table_linecount . '" value="' . encode_entities($lox_statsobject{$statsobj}{Title}) . '"></td>
				<td class="tg-yw4l">' . encode_entities($lox_statsobject{$statsobj}{Desc}) . '<input type="hidden" name="desc_' . $table_linecount . '" value="' . encode_entities($lox_statsobject{$statsobj}{Desc}) . '"></td>
				<td class="tg-yw4l">' . encode_entities($lox_statsobject{$statsobj}{Place}) . '<input type="hidden" name="place_' . $table_linecount . '" value="' . encode_entities($lox_statsobject{$statsobj}{Place}) . '"></td>
				<td class="tg-yw4l">' . encode_entities($lox_statsobject{$statsobj}{Category}) . '<input type="hidden" name="category_' . $table_linecount . '" value="' . encode_entities($lox_statsobject{$statsobj}{Category}) . '"></td>
				<td align="center" class="tg-yw4l" title="' . $StatTypes{$lox_statsobject{$statsobj}{StatsType}} . '"><div class="tooltip">' . $lox_statsobject{$statsobj}{StatsType} .  '</div><input type="hidden" name="statstype_' . $table_linecount . '" value="' . $lox_statsobject{$statsobj}{StatsType} . '"></td>
				<td align="center" class="tg-yw4l">' . $lox_statsobject{$statsobj}{MinVal} . '<input type="hidden" name="minval_' . $table_linecount . '" value="' . $lox_statsobject{$statsobj}{MinVal} . '"></td>
				<td align="center" class="tg-yw4l">' . $lox_statsobject{$statsobj}{MaxVal} . '<input type="hidden" name="maxval_' . $table_linecount . '" value="' . $lox_statsobject{$statsobj}{MaxVal} . '"></td>
				<td align="center" class="tg-yw4l">' . encode_entities($lox_statsobject{$statsobj}{Unit}) . '<input type="hidden" name="unit_' . $table_linecount . '" value="' . encode_entities($lox_statsobject{$statsobj}{Unit}) . '"></td>
				<td class="tg-yw4l">' . $statdef_dropdown . '</td>
				<td align="center" class="tg-yw4l"> 
					<!--<input data-mini="true" type="checkbox" name="doimport_' . $table_linecount . '" value="import"> -->
					<!-- <select data-mini="true" name="doimport_' . $table_linecount . '">
						<option selected value="">Inaktiv</option>
						<option value="import">Import & Start</option>
						<option value="import_start">Nur Import</option>
					</select> -->
					<label data-mini="true" for="imptype_import' . $table_linecount . '"><input data-mini="true" type="checkbox" id="imptype_import' . $table_linecount . '" name="doimport_' . $table_linecount . '" value="import">Import</label>
					<label data-mini="true" for="imptype_importstart' . $table_linecount . '"><input data-mini="true" type="checkbox" id="imptype_importstart' . $table_linecount . '"name="doimport_' . $table_linecount . '" value="import_start">Import & Start</label>
			
				<input type="hidden" name="msnr_' . $table_linecount . '" value="' . $lox_statsobject{$statsobj}{MSNr} . '">
				<input type="hidden" name="msip_' . $table_linecount . '" value="' . $lox_statsobject{$statsobj}{MSIP} . '">
				<input type="hidden" name="type_' . $table_linecount . '" value="' . $lox_statsobject{$statsobj}{Type} . '">
				<input type="hidden" name="loxuid_' . $table_linecount . '" value="' . $statsobj . '">
				</td>
			  </tr>
			';
	}
}

# Return Job name from filename
sub get_jobname_from_filename
{
	my($jobpath) = @_;
	my($filename, $dirs, $suffix) = fileparse($jobpath);
	return (split /\./, $filename)[0];
}




#####################################################
# Read LoxPLAN XML
#####################################################

# Must be global: %lox_statsobject
# What you get:
# - Key of the hash is UUID
# - Every key contains
	# {Title} Object name (Bezeichnung)
	# {Desc} Object description (Beschreibung). If empty--> Object name (*)
	# {StatsType} Statistics type 1..7
	# {Type} Type name of the Loxone input/output/function
	# {MSName} Name of the Miniserver
	# {MSIP} IP of the Miniserver
	# {MSNr} ID of the Miniserver in LoxBerry General Config
	# {Unit} Unit to display in the Loxone App (stripped from Loxone syntax <v.1>)
	# {Category} Name of the category
	# {Place} Name of the place (room)
	# {MinVal} Defined minimum value or string 'U' for undefined
	# {MaxVal} Defined maximum value or string 'U' for undefined

sub readloxplan
{

	my @loxconfig_xml;
	my %lox_miniserver;
	my %lox_category;
	my %lox_room;
	my $start_run = time();

	# For performance, it would be possibly better to switch from XML::LibXML to XML::Twig

	# Prepare data from LoxPLAN file
	my $parser = XML::LibXML->new();
	our $lox_xml;
	eval { $lox_xml = $parser->parse_file($loxconfig_path);	};
	if ($@) {
		logger(1, "import.cgi: Cannot parse LoxPLAN XML file.");
		#exit(-1);
		return;
	}

	# Read Loxone Miniservers
	foreach my $miniserver ($lox_xml->findnodes('//C[@Type="LoxLIVE"]')) {
		# Use an multidimensional associative hash to save a table of necessary MS data
		# key is the Uid
		$lox_miniserver{$miniserver->{U}}{Title} = $miniserver->{Title};
		$lox_miniserver{$miniserver->{U}}{Serial} = $miniserver->{Serial};
		
		# IP address can hava a port
		my ($msxmlip, $msxmlport) = split(/:/, $miniserver->{IntAddr}, 2);
		if($msxmlip=~/^(\d{1,3}).(\d{1,3}).(\d{1,3}).(\d{1,3})$/ &&(($1<=255 && $2<=255 && $3<=255 &&$4<=255 ))) { 
			# IP seems valid
			logger(4, "Found Miniserver $miniserver->{Title} with IP $msxmlip");
			$lox_miniserver{$miniserver->{U}}{IP} = $msxmlip;
		} elsif ((! defined $msxmlip) || ($msxmlip eq "")) {
			logger(1, "Miniserver $miniserver->{Title}: Internal IP is empty. This field is mandatory. Please update your Config.");
			$lox_miniserver{$miniserver->{U}}{IP} = undef;
		} else { 
			# IP seems not to be an IP - possibly we need a DNS lookup?
			logger(2, "Found Miniserver $miniserver->{Title} possibly configured with hostname. Querying IP of $msxmlip ...");
			my $dnsip = inet_ntoa(inet_aton($msxmlip));
			if ($dnsip) {
				logger(2, " --> Found Miniserver $miniserver->{Title} and DNS lookup got IP $dnsip ...");
				$lox_miniserver{$miniserver->{U}}{IP} = $dnsip;
			} else {
				logger(1, " --> Could not find an IP for Miniserver $miniserver->{Title}. Giving up this MS. Please check the internal Miniserver IPs in your Loxone Config.");
				$lox_miniserver{$miniserver->{U}}{IP} = $msxmlip;
			}
		}
		# In a later stage, we have to query the LoxBerry MS Database by IP to get LoxBerrys MS-ID.
	}

	# Read Loxone categories
	foreach my $category ($lox_xml->findnodes('//C[@Type="Category"]')) {
		# Key is the Uid
		$lox_category{$category->{U}} = $category->{Title};
	}
	# print "Test Perl associative array: ", $lox_category{"0b2c7aea-007c-0002-0d00000000000000"}, "\r\n";

	# Read Loxone rooms
	foreach my $room ($lox_xml->findnodes('//C[@Type="Place"]')) {
		# Key is the Uid
		$lox_room{$room->{U}} = $room->{Title};
	}

	# Get all objects that have statistics enabled
	#my $hr = HTML::Restrict->new();
			
	foreach my $object ($lox_xml->findnodes('//C[@StatsType]')) {
		# Get Miniserver of this object
		# Nodes with statistics may be a child or sub-child of LoxLive type, or alternatively Ref-er to the LoxLive node. 
		# Therefore, we have to distinguish between connected in some parent, or referred by in some parent.	
		my $ms_ref;
		my $parent = $object;
		do {
			$parent = $parent->parentNode;
		} while ((!$parent->{Ref}) && ($parent->{Type} ne "LoxLIVE"));
		if ($parent->{Type} eq "LoxLIVE") {
			$ms_ref = $parent->{U};
		} else {
			$ms_ref = $parent->{Ref};
		}
		logger (4, "Objekt: " . $object->{Title} . " (StatsType = " . $object->{StatsType} . ") | Miniserver: " . $lox_miniserver{$ms_ref}{Title});
		$lox_statsobject{$object->{U}}{Title} = $object->{Title};
		if (defined $object->{Desc}) {
			$lox_statsobject{$object->{U}}{Desc} = $object->{Desc}; }
		else {
			$lox_statsobject{$object->{U}}{Desc} = $object->{Title} . " (*)"; 
		}
		$lox_statsobject{$object->{U}}{StatsType} = $object->{StatsType};
		$lox_statsobject{$object->{U}}{Type} = $object->{Type};
		$lox_statsobject{$object->{U}}{MSName} = $lox_miniserver{$ms_ref}{Title};
		$lox_statsobject{$object->{U}}{MSIP} = $lox_miniserver{$ms_ref}{IP};
		$lox_statsobject{$object->{U}}{MSNr} = $cfg_mslist{$lox_miniserver{$ms_ref}{IP}};
		
		# Unit
		my @display = $object->getElementsByTagName("Display");
		if($display[0]->{Unit}) { 
			$lox_statsobject{$object->{U}}{Unit} = $display[0]->{Unit};
			$lox_statsobject{$object->{U}}{Unit} =~ s|<.+?>||g;
			$lox_statsobject{$object->{U}}{Unit} = trim($lox_statsobject{$object->{U}}{Unit});
			logger (4, "Unit: " . $lox_statsobject{$object->{U}}{Unit});
		} else { 
			logger (4, "Unit: " . $display[0]->{Unit} . " (none detected)");
		}
		
		# Place and Category
		my @iodata = $object->getElementsByTagName("IoData");
		logger (4, "Cat: " . $lox_category{$iodata[0]->{Cr}});
		$lox_statsobject{$object->{U}}{Category} = $lox_category{$iodata[0]->{Cr}};
		$lox_statsobject{$object->{U}}{Place} = $lox_room{$iodata[0]->{Pr}};
		
		# Min/Max values
		if ($object->{Analog} ne "true") {
			$lox_statsobject{$object->{U}}{MinVal} = 0;
			$lox_statsobject{$object->{U}}{MaxVal} = 1;
		} else {
			if ($object->{MinVal}) { 
				$lox_statsobject{$object->{U}}{MinVal} = $object->{MinVal};
			} else {
				$lox_statsobject{$object->{U}}{MinVal} = "U";
			}
			if ($object->{MaxVal}) { 
				$lox_statsobject{$object->{U}}{MaxVal} = $object->{MaxVal};
			} else {
				$lox_statsobject{$object->{U}}{MaxVal} = "U";
			}
		}
		logger(4, "Object Name: " . $lox_statsobject{$object->{U}}{Title});
	}
	
	my $jsonparser = Stats4Lox::JSON->new();
	my $loxplanjson = $jsonparser->open(filename => "/tmp/stats4lox_loxplan.json");
	$loxplanjson->{stats4lox} = \%lox_statsobject;
	$jsonparser->write();
	
	my $end_run = time();
	my $run_time = $end_run - $start_run;
	# print "Job took $run_time seconds\n";
	return;
}

#####################################################
# Error-Sub
#####################################################

sub error 
{
	my $template_title = $pphrase->param("TXT0000") . " - " . $pphrase->param("TXT0001");
	print "Content-Type: text/html\n\n"; 
	&lbheader;
	open(F,"$installfolder/templates/system/$lang/error.html") || die "Missing template system/$lang/error.html";
	while (<F>) 
	{
		$_ =~ s/<!--\$(.*?)-->/${$1}/g;
		print $_;
	}
	close(F);
	&footer;
	exit;
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
			my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = CORE::localtime(time);
			my $now_string = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
			print STDERR "$now_string Stats4Lox import.cgi $loglevels[$level]: $message\r\n";
		} elsif ( $level <= $loglevel && $loglevel <= 4) {
			my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = CORE::localtime(time);
			my $now_string = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
			print $lf "$now_string $loglevels[$level]: $message\r\n";
		}
	}
	
