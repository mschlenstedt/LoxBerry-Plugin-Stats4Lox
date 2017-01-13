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

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use Config::Simple;
use Cwd 'abs_path';
use File::Basename;
use File::HomeDir;
use File::Path qw(make_path);
use File::stat;
use HTML::Entities;
use HTTP::Request;
use LWP::UserAgent;
use POSIX qw(strftime);
use String::Escape qw( unquotemeta );
use Time::HiRes qw/ time sleep /;
use DateTime;
use URI::Escape;
use warnings;

# Christian Import
# use Time::localtime;
# Debug

# Set maximum file upload to approx. 7 MB
# $CGI::POST_MAX = 1024 * 10000;

#use strict;
#no strict "refs"; # we need it for template system
our $namef;
our $value;
our @query;
our @fields;
our @lines;
my $home = File::HomeDir->my_home;
our %cfg_mslist;
our $upload_message;
our $stattable;
our %lox_statsobject;

# Logfile
our $logfilepath; 
our $lf;
our @loglevels;
our $loglevel=0;

# Use loglevel with care! DEBUG=4 really fills up logfile. Use ERRORS=1 or WARNINGS=2, or disable with 0.
# To log everything to STDERR, use $loglevel=5.


##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.1.1";

# Figure out in which subfolder we are installed
my $part = substr ((abs_path($0)), (length($home)+1));
our ($psubfolder) = (split(/\//, $part))[3];

$logfilepath = "$home/log/plugins/$psubfolder/chart_rrdflot.log";
openlogfile();
logger(4, "Logfile $logfilepath opened");

# our $job_basepath = "$home/data/plugins/$psubfolder/import";

my  $cfg             = new Config::Simple("$home/config/system/general.cfg");
our $installfolder   = $cfg->param("BASE.INSTALLFOLDER");
our $lang            = $cfg->param("BASE.LANG");
our $miniservercount = $cfg->param("BASE.MINISERVERS");
our $clouddnsaddress = $cfg->param("BASE.CLOUDDNS");
our $curlbin         = $cfg->param("BINARIES.CURL");
our $grepbin         = $cfg->param("BINARIES.GREP");
our $awkbin          = $cfg->param("BINARIES.AWK");
our $timezone		 = $cfg->param("TIMESERVER.ZONE");

#########################################################################
# Parameter
#########################################################################

# Everything from URL


foreach (split(/&/,$ENV{'QUERY_STRING'}))
{
  ($namef,$value) = split(/=/,$_,2);
  $namef =~ tr/+/ /;
  $namef =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $value =~ tr/+/ /;
  $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $query{$namef} = $value;
}

# # Set parameters coming in - get over post
  # if ( !$query{'saveformdata'} ) { 
	# if ( param('saveformdata') ) { 
		# our $saveformdata = quotemeta(param('saveformdata')); 
	# } else { 
		# our $saveformdata = 0;
	# } 
  # } else { 
	# our $saveformdata = quotemeta($query{'saveformdata'}); 
# }

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

##########################################################################
# Main program
##########################################################################

# our $post = new CGI;

# if ( $post->param('Upload') ) {
	# saveloxplan();
	# form();
	
# } elsif ($doapply) {
  # save();
  # form();
# } else {
  # form();
# }

form();

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

	# Prepare the form
	
		
	
	# Print the template
	print "Content-Type: text/html\n\n";
	
	$template_title = $pphrase->param("TXT0000") . ": " . $pphrase->param("TXT0001");
	
	# lbheader();
	print rrdflot_alternative_header();
	
	# Print table Template
	
	open(F,"$installfolder/templates/plugins/$psubfolder/multi/rrdflot_head.html") || die "Missing template plugins/$psubfolder/multi/rrdflot_head.html";
	  while (<F>) 
	  {
		$_ =~ s/<!--\$(.*?)-->/${$1}/g;
#	    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
	    print $_;
	  }
	close(F);

	# Print Graph template
	generate_stat_overview();

	
	# print table footer Template
	
	
#	open(F,"$installfolder/templates/plugins/$psubfolder/$lang/addstat_end.html") || die "Missing template plugins/$psubfolder/$lang/addstat_end.html";
#	  while (<F>) 
#	  {
#	    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
#	    print $_;
#	  }
#	close(F);
	# &footer;
	exit;

}

#####################################################
# GenerateStatOverview Template erstellen
#####################################################
sub generate_stat_overview
{
	# Timezone (should better be read from LoxBerry general.cfg)
	our $tz = '+1';
		
	# Read complete template to memory to re-use
	open(F,"$installfolder/templates/plugins/$psubfolder/multi/rrdflot_graph.html") || die "Missing template plugins/$psubfolder/multi/rrdflot.html";
	my @template = <F> ;
	close (F) ;
	
	# Read Stats4Lox databases
	# Re-used from Michael dbinfo.cgi
	open(F,"<$installfolder/config/plugins/$psubfolder/databases.dat");
	my @data = <F>;
	close (F) ;
	
		
	# Loop over DB
	foreach (@data){
		my @single_template = @template;
		s/[\n\r]//g;
		# Comments
		if ($_ =~ /^\s*#.*/) {
			next;
		}
		@fields = split(/\|/);
		
		our $dbnr = $fields[0];
		our $unique_name = $fields[3];
		our $label = $fields[2];
		
		# tz  # timezone +1
		print "<hr /><h3>$unique_name  ----- $label ----- DB $dbnr</h3>";
		
		foreach my $a (@single_template) {
			$a =~ s/<!--\$(.*?)-->/${$1}/g;
	#	    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
			print $a;
		}
	}
}

#####################################################
# Page-Header-Sub
#####################################################

	sub lbheader 
	{
	  # Create Help page
	  our $helplink = "http://www.loxwiki.eu:80/x/uYCm";
	  open(F,"$installfolder/templates/plugins/$psubfolder/$lang/help.html") || die "Missing template plugins/$psubfolder/$lang/help.html";
	    my @help = <F>;
 	    our $helptext;
	    foreach (@help)
	    {
	      s/[\n\r]/ /g;
	      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
	      $helptext = $helptext . $_;
	    }
	  close(F);
	  open(F,"$installfolder/templates/system/$lang/header.html") || die "Missing template system/$lang/header.html";
	    while (<F>) 
	    {
	      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
	      print $_;
	    }
	  close(F);
	}

sub rrdflot_alternative_header 
{
return '<html>
	<head>
		<title>LoxBerry: Statistics4Loxone</title>
		<meta http-equiv="content-type" content="text/html; charset=utf-8">
		<link rel="stylesheet" href="/system/scripts/jquery/themes/main/loxberry.min.css">
		<link rel="stylesheet" href="/system/scripts/jquery/themes/main/jquery.mobile.icons.min.css">
		<link rel="stylesheet" href="/system/scripts/jquery/jquery.mobile.structure-1.4.5.min.css">
		<link rel="stylesheet" href="/system/css/main.css">
		<link rel="shortcut icon" href="/system/images/icons/favicon.ico" />
		<link rel="icon" type="image/png" href="/system/images/favicon-32x32.png" sizes="32x32" />
		<link rel="icon" type="image/png" href="/system/images/favicon-16x16.png" sizes="16x16" />
		<!-- script src="/system/scripts/jquery/jquery-1.8.2.min.js"></script -->
		<!--script src="/system/scripts/jquery/jquery.mobile-1.4.5.min.js"></script -->
		<!-- script src="/system/scripts/form-validator/jquery.form-validator.min.js"></script -->
		<!-- script src="/system/scripts/setup.js"></script -->
		<!-- script>
			// Disable JQUERY ♢OM Caching
			$.mobile.page.prototype.options.domCache = false;
			$(document).on("pagehide", "div[data-role=page]", function(event)
			{
				$(event.target).remove();
			});
			// Disable caching of AJAX responses
			$.ajaxSetup ({ cache: false });
		</script -->
	</head>
	<body>
';

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
