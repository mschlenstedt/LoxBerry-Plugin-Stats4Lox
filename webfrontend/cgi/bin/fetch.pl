#!/usr/bin/perl

# fetch.pl

# Copyright 2016 Michael Schlenstedt, michael@loxberry.de
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

#use strict;
#use warnings;

##########################################################################
# Modules
##########################################################################

use LWP::UserAgent;
use String::Escape qw( unquotemeta );
use URI::Escape;
use XML::Simple qw(:strict);
use Getopt::Long;
use Config::Simple;
use File::HomeDir;
use Cwd 'abs_path';

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.3";

# Figure out in which subfolder we are installed
our $psubfolder = abs_path($0);
$psubfolder =~ s/(.*)\/(.*)\/bin\/(.*)$/$2/g;

my $home = File::HomeDir->my_home;

my $cfg             = new Config::Simple("$home/config/system/general.cfg");
my $lang            = $cfg->param("BASE.LANG");
my $installfolder   = $cfg->param("BASE.INSTALLFOLDER");
my $miniservers     = $cfg->param("BASE.MINISERVERS");
my $clouddns        = $cfg->param("BASE.CLOUDDNS");

# Commandline options
my $verbose = '';
my $step = '300';
my $help = '';

GetOptions ('verbose' => \$verbose,
            'step=i' => \$step,
            'quiet'   => sub { $verbose = 0 });

# Starting...
my $logmessage = "<INFO> Starting $0 Version $version for Step $step s";
&log;

# Wait 0-5 seconds randomly to let different instances not to start simoultaniously
sleep rand(5);

# Read Statistics/Databases
open(F,"<$installfolder/config/plugins/$psubfolder/databases.dat") or "Cannot open databases.dat: $!";
	@data = <F>;
close (F);

# Parse and grep...
our $db;
our $miniserver;
our $miniserverip;
our $miniserverport;
our $miniserveradmin;
our $miniserverpass;
our $miniserverclouddns;
our $miniservermac;
our $response;
our $urlstatus;
our $urlstatuscode;
our $loxonenameurlenc;
our $rawxml;
our $xml;
our $xmlstatuscode;
our @data;
our @fields;
our @fields1;
our @fields2;
our $status;


foreach (@data){
	s/[\n\r]//g;
	# Comments
	if ($_ =~ /^\s*#.*/) {
		next;
	}
	@fields = split(/\|/);

	# Skip all statistics not in this "Step run"
	if (@fields[1] ne $step) {
		next;
	}

	# Skip paused databases
	open(F,"<$installfolder/data/plugins/$psubfolder/databases/@fields[0].status") || die "Cannot open status file for RRD-database.";
	$status = <F>;
	if ($status eq 1) {
		$logmessage = "<INFO> Skipping Statistic ID @fields[0] (@fields[3]) - Database is paused.";
		&log;
		next;
	}

	# Miniserver data
	$miniserver = @fields[4];
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

	# Fetch data
	$db = @fields[0];
	$logmessage = "<INFO> Fetching Statistic ID @fields[0] (@fields[3]) from Miniserver No. $miniserver ($miniserverip:$miniserverport)";
	&log;

	$loxonenameurlenc = uri_escape( unquotemeta(@fields[3]) );
	$url = "http://$miniserveradmin:$miniserverpass\@$miniserverip\:$miniserverport/dev/sps/io/$loxonenameurlenc/astate";

	$ua = LWP::UserAgent->new;
	$ua->timeout(1);
	local $SIG{ALRM} = sub { die };
	eval {
		alarm(1);
		$response = $ua->get($url);
		$urlstatus = $response->status_line;
		$rawxml = $response->decoded_content();
	};
	alarm(0);

	# Error if we don't get status 200
	$urlstatuscode = substr($urlstatus,0,3);
	if ($urlstatuscode ne "200") {
		$logmessage = "<FAIL> URL Status Statistic ID @fields[0] (@fields[3]): $urlstatuscode"; 
		&error;
		next;
	}

	# Error if status Code in XML is not 200
	$xml = XMLin($rawxml, KeyAttr => { LL => 'value' }, ForceArray => [ 'LL', 'value' ]);
	$xmlstatuscode = $xml->{Code};
	if ($xmlstatuscode ne "200") {
		$logmessage = "<FAIL> XML Status Statistic ID @fields[0] (@fields[3]): $xmlstatuscode"; 
		&error;
		next;
	}

	# Filter units
	$value = $xml->{value};
	$value =~ s/^([\d\.]+).*/$1/g;
	if (-S "/var/run/rrdcached.sock") {
		$output = qx(/usr/bin/rrdtool update -d /var/run/rrdcached.sock $installfolder/data/plugins/$psubfolder/databases/@fields[0].rrd N:$value);
	} else {
		$logmessage = "<WARN> RRDCaching Daemon (rrdcached) seems not to run. Writing values directly to disc."; 
		&log;
		$output = qx(/usr/bin/rrdtool update $installfolder/data/plugins/$psubfolder/databases/@fields[0].rrd N:$value);
	}
	if ($? eq 0) {
		$logmessage = "<OK> Value for Statistic ID @fields[0] (@fields[3]) is: $value"; 
		&log;
	}

	# Reset status if needed (from red to green)
	if ($status eq 0) {
		open(F,">$installfolder/data/plugins/$psubfolder/databases/@fields[0].status") || die "Cannot open status file for RRD-database.";
		flock(F,2);
		print F "2";
		close F;
	}

	# Wait 1 sec. for next grep (to let Miniserver recover himself :-)
	sleep 1;

}

# Exit
exit;

##########################################################################
# Subroutinen
##########################################################################

sub log {

  # Today's date for logfile
  (my $sec,my $min,my $hour,my $mday,my $mon,my $year,my $wday,my $yday,my $isdst) = localtime();
  $year = $year+1900;
  $mon = $mon+1;
  $mon = sprintf("%02d", $mon);
  $mday = sprintf("%02d", $mday);
  $hour = sprintf("%02d", $hour);
  $min = sprintf("%02d", $min);
  $sec = sprintf("%02d", $sec);

  # Logfile
  open(F,">>$installfolder/log/plugins/$psubfolder/stats4lox.log");
    binmode F, ':encoding(UTF-8)';
    print F "$year-$mon-$mday $hour:$min:$sec $logmessage\n";
  close (F);

  if ($verbose || $error) {print "$logmessage\n";}

  return();

}

# Error Message
sub error {
  &log;

  # Update database
  open(F,">$installfolder/data/plugins/$psubfolder/databases/$db.status");
  flock(F, 2);
  print F "0";
  close(F);

  return();

}
