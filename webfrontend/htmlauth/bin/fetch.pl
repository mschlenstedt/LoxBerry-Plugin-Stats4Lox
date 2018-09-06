#!/usr/bin/perl

# fetch.pl

# Copyright 2016-2018 Michael Schlenstedt, michael@loxberry.de
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#	 http://www.apache.org/licenses/LICENSE-2.0
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

use LoxBerry::System;
use LoxBerry::Log;
require "$lbpbindir/libs/Stats4Lox.pm";

use LWP::UserAgent;
use String::Escape qw( unquotemeta );
use URI::Escape;
use XML::Simple qw(:strict);
use Getopt::Long;
use Cwd 'abs_path';
use RRDs;
use POSIX qw(ceil);

# For debugging
use Data::Dumper;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.3.1";

# Figure out in which subfolder we are installed

my $cfg			 = new Config::Simple("$lbhomedir/config/system/general.cfg");
my $lang			= LoxBerry::System::lblanguage();
my $miniservers	 = $cfg->param("BASE.MINISERVERS");
my $clouddns		= $cfg->param("BASE.CLOUDDNS");

# Commandline options
my $verbose = '';
my $step = '300';
my $help = '';

GetOptions ('verbose' => \$verbose,
			'step=i' => \$step,
			'quiet'   => sub { $verbose = 0 });
			


##########################################################################
# Init logfile
##########################################################################

# Creates a logging object with the filename $lbplogdir/<timestamp>_$lbpplugindir_daemon.log (e.g. /opt/loxberry/log/plugins/kodi/20180417_104703_kodi_daemon.log)
our $log = LoxBerry::Log->new (
    name => 'Fetch',
	stderr => 1,
	addtime => 1,
	loglevel => 7
);
LOGSTART "Stats4Lox Fetcher Step $step";

			
			
			
			
			# Starting...
my $logmessage = "<INFO> Starting $0 Version $version for Step $step s";
&log;

# Wait 0-5 seconds randomly to let different instances not to start simoultaniously
#sleep rand(5);

# Read Statistics.json
my $statsparser = Stats4Lox::JSON->new();
my $statsobj = $statsparser->open(filename => $statisticsfile, writeonclose => 1);
#$statsparser->dump($statsobj);

my @fetcheddata = data_fetching();

data_sending();

LOGEND();
exit;







open(F,"<$CFG::MAIN_CONFIGFOLDER/databases.dat") or "Cannot open databases.dat: $!";
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
	open(F,"<" . $CFG::MAIN_RRDFOLDER . "/@fields[0].status") || die "Cannot open status file for RRD-database.";
	$status = <F>;
		print "Status: $status\n";
	if ($status eq 1) {
		$logmessage = "<INFO> Skipping Statistic ID @fields[0] (@fields[3]) - Database is paused.";
		&log;
		next;
	}
	close F;

	# Miniserver data
	$miniserver = @fields[4];
	$miniserverip		= $cfg->param("MINISERVER$miniserver.IPADDRESS");
	$miniserverport	  = $cfg->param("MINISERVER$miniserver.PORT");
	$miniserveradmin	 = $cfg->param("MINISERVER$miniserver.ADMIN");
	$miniserverpass	  = $cfg->param("MINISERVER$miniserver.PASS");
	$miniserverclouddns  = $cfg->param("MINISERVER$miniserver.USECLOUDDNS");
	$miniservermac	   = $cfg->param("MINISERVER$miniserver.CLOUDURL");

	# Use Cloud DNS?
	if ($miniserverclouddns) {
		$output = qx($lbhomedir/bin/showclouddns.pl $miniservermac);
		@fields2 = split(/:/,$output);
		$miniserverip   =  @fields2[0];
		$miniserverport = @fields2[1];
	}

	# Fetch data
	$db = @fields[0];
	$logmessage = "<INFO> Fetching Statistic ID @fields[0] (@fields[3]) from Miniserver No. $miniserver ($miniserverip:$miniserverport)";
	&log;

	$loxonenameurlenc = uri_escape( unquotemeta(@fields[3]) );
	$url = "http://$miniserveradmin:$miniserverpass\@$miniserverip\:$miniserverport/dev/sps/io/$loxonenameurlenc/all";

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
	
	# Get RRD infos
	$rrdfile = $CFG::MAIN_RRDFOLDER. "/@fields[0].rrd";
	my $rrdinfo = RRDs::info ($rrdfile);
	my $ERR=RRDs::error;
	if ($ERR) {
		$logmessage = "<FAIL> Could not evaluate RRD counter type.";
		&error;
		next;
	}

	# Get Datasource type (GAUGE, COUNTER ...)
	my $rrd_dstype = %$rrdinfo{'ds[value].type'};
	if (! $rrd_dstype) {
		# if the default datasource is not found, let's do fuzzy search
		foreach my $key (sort keys %$rrdinfo){
			if (index($key, ".type") != -1) {
				$rrd_dstype = $$hash{$key}; 
				last;
			}	
		}
	}
	# With these DS types only INTEGERs are allowed
	if ($rrd_dstype eq 'COUNTER' || $rrd_dstype eq 'DERIVE' || $rrd_dstype eq 'ABSOLUTE') { 
		$value = ceil($value);
	}

	if (-S "/var/run/rrdcached.sock") {
		$output = qx(/usr/bin/rrdtool update -d /var/run/rrdcached.sock $rrdfile N:$value);
	} else {
		$logmessage = "<WARN> RRDCaching Daemon (rrdcached) seems not to run. Writing values directly to disc."; 
		&log;
		$output = qx(/usr/bin/rrdtool update $rrdfile N:$value);
	}
	if ($? eq 0) {
		$logmessage = "<OK> Value for Statistic ID @fields[0] (@fields[3]) is: $value"; 
		&log;
	}

	# Reset status if needed (from red to green)
	if ($status eq 0) {
				print "Status was 0. Updating...\n";
		open(F,">" . $CFG::MAIN_RRDFOLDER . "/@fields[0].status") || die "Cannot open status file for RRD-database.";
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

sub data_fetching 
{
	LOGINF "data_fetching called";
	
	my @dataarray;
	my @nextturn = $statsparser->find($statsobj->{Stat}, "\$_->{fetchStep} eq \"$step\" and \$_->{activated} eq '1'");
	
	foreach my $key (@nextturn) {
		print STDERR "CfgFile: " . $statsobj->{Stat}->{$key}->{statCfgFile} . "\n";
		my $Source = $statsobj->{Stat}->{$key}->{Source};
		
		# Read Datasource data to make it more easy for the Source developer
		my $statcfgparser = Stats4Lox::JSON->new();
		my $statcfgfilename = $configfolder . "/" . $statsobj->{Stat}->{$key}->{statCfgFile};
		#print "Statcfgfilename: $statcfgfilename\n";
		our $statscfg = $statcfgparser->open(filename => $statcfgfilename, writeonclose => 1);
		
		# Load Source Plugin
		eval {
			require "$lbpbindir/libs/Sources/$Source/$Source.pm";
		};
		if ($@) {
			print STDERR " !!! Source Plugin $plugin failed to load: $@\n";
			$statsobj->{Stat}->{$key}->{fetchStatus} = 'error';
			$statsobj->{Stat}->{$key}->{fetchStatusError} = "Plugin failed to load: $@";
			next;
		}
		# Run the fetch command
		my %returnhash;
		eval { 
			%returnhash = "Stats4Lox::Source::$Source"->fetch( statid => $key, statcfg => $statscfg );
		};
		if ($@) {
			print STDERR " !!! Source Plugin $plugin could not fetch: $@\n";
			$statsobj->{Stat}->{$key}->{fetchStatus} = 'error';
			$statsobj->{Stat}->{$key}->{fetchStatusError} = "Plugin failed calling fetch: $@";
			next;
			}
		
		print STDERR "Returned values: Timestamp: $returnhash{timestamp} Value: $returnhash{value}\n";
		print Data::Dumper::Dumper(%returnhash);
		
		# If we got response, flag the data with the statid and push it to the @dataarray
		
		if (defined $returnhash{timestamp} and (defined $returnhash{outputs} or $returnhash{value})) {
			# Set success status
			$statsobj->{Stat}->{$key}->{fetchStatus} = 'running';
			$statsobj->{Stat}->{$key}->{fetchStatusError} = undef;
			# Add statid to return hash for identification
			# We also add the $ctatscfg object to the hash that we don't need to reopen it
			$returnhash{statid} = $key;
			$returnhash{statscfg} = $statscfg;
			push @dataarray, \%returnhash;
		} else {
			$statsobj->{Stat}->{$key}->{fetchStatus} = 'error';
			$statsobj->{Stat}->{$key}->{fetchStatusError} = "No values returned";
		}
		
	}
	
	LOGOK "Data fetching finished. Collected " . scalar @dataarray . " entries.";
	return @dataarray;
}

sub data_sending
{
	print STDERR " >=== data_sending =======================\n";
	LOGINF "data_sending called";
	foreach my $datapack (@fetcheddata) {
		my $statid = $datapack->{statid};
		# LOGDEB "Datapack/Statid:\n" . Dumper($datapack, $statid);
		
		my $statcfgparser = Stats4Lox::JSON->new();
		my $statcfgfilename = $configfolder . "/" . $statsobj->{Stat}->{$statid}->{statCfgFile};
		my $statscfg = $statcfgparser->open(filename => $statcfgfilename, writeonclose => 1);
	
		
		# LOGDEB Dumper($statscfg);
		
		# We need to loop through the sink plugins
		my %sinks = %{$statscfg->{Sink}};
		LOGDEB "Number of sinks: " . scalar keys %sinks;
		foreach my $Sink (keys %sinks) {
			LOGDEB "Sink $Sink \n";
			
			# Load Sink plugin
			eval {
				require "$lbpbindir/libs/Sinks/$Sink/$Sink.pm";
			};
			if ($@) {
					my $errormsg = "data_sending_error StatID $statid ($statscfg->{name}): Sink Plugin $Sink failed to load: $@";
					$statscfg->{Sink}->{$Sink}->{sendStatus} = "error";
					$statscfg->{Sink}->{$Sink}->{sendStatusError} = "$errormsg";
					LOGERR $errormsg;
					next;
			}
			# Run the fetch command
			my $ok;
			eval { 
				$ok = "Stats4Lox::Sink::$Sink"->value( 
						statid => $statid, 
						statcfg => $statscfg, 
						timestamp => $datapack->{timestamp}, 
						value => $datapack->{value},
						outputs => $datapack->{outputs}
				);
			};
			if ($@) {
				my $errormsg = "data_sending_error StatID $statid ($statscfg->{name}): Sink $Sink function 'value' could not be called: $@";
				$statscfg->{Sink}->{$Sink}->{sendStatus} = "error";
				$statscfg->{Sink}->{$Sink}->{sendStatusError} = "$errormsg";
				LOGERR $errormsg;
				next;
			}
			if (!$ok) {
				my $errormsg = "data_sending_error StatID $statid ($statscfg->{name}): Sink $Sink returned that sending was not ok.";
				$statscfg->{Sink}->{$Sink}->{sendStatus} = "error";
				$statscfg->{Sink}->{$Sink}->{sendStatusError} = "$errormsg";
				LOGERR $errormsg;
				next;
			}
			# Everything ok
			$statscfg->{Sink}->{$Sink}->{sendStatus} = "running";
			undef $statscfg->{Sink}->{$Sink}->{sendStatusError};
				
		}
	}
	LOGOK "Data sending finished.";
}
	
	
	
	
	




sub log {

  $log->write(-1, $logmessage);
  # # Today's date for logfile
  # (my $sec,my $min,my $hour,my $mday,my $mon,my $year,my $wday,my $yday,my $isdst) = localtime();
  # $year = $year+1900;
  # $mon = $mon+1;
  # $mon = sprintf("%02d", $mon);
  # $mday = sprintf("%02d", $mday);
  # $hour = sprintf("%02d", $hour);
  # $min = sprintf("%02d", $min);
  # $sec = sprintf("%02d", $sec);

  # # Logfile
  # open(F,">>$installfolder/log/plugins/$lbpplugindir/stats4lox.log");
	# binmode F, ':encoding(UTF-8)';
	# print F "$year-$mon-$mday $hour:$min:$sec $logmessage\n";
  # close (F);

  # if ($verbose || $error) {print "$logmessage\n";}

  # return();

}

# Error Message
sub error {
  &log;

  # Update database
  open(F,">" . $CFG::MAIN_RRDFOLDER . "/$db.status");
  flock(F, 2);
  print F "0";
  close(F);
  return();

}
