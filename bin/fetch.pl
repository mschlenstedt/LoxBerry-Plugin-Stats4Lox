#!/usr/bin/perl

# fetch.pl

# Copyright 2016-2019 Michael Schlenstedt, michael@loxberry.de
#			Christian Fenzl, christian@loxberry.de
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

use strict;
use warnings;

##########################################################################
# Modules
##########################################################################

use LoxBerry::System;
use LoxBerry::JSON;
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
#use Data::Dumper;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "0.4.0.1";

# Commandline options
my $verbose = '';
my $step = '300';
my $help = '';

GetOptions ('verbose' => \$verbose,
		'step=i' => \$step,
		'quiet'   => sub { $verbose = 0 });

# Config
my $cfgfile = "$lbpconfigdir/stats4lox.json";

# Read json config
my $jsonobj = LoxBerry::JSON->new();
my $cfg = $jsonobj->open(filename => $cfgfile);

##########################################################################
# Init logfile
##########################################################################

our $log = LoxBerry::Log->new (
	name => 'Fetch',
	addtime => 1,
);

if ($verbose) {
	$log->stdout(1);
	$log->loglevel(7);
}

##########################################################################
# Fetch
##########################################################################

LOGSTART "Stats4Lox Fetcher Step $step";
LOGDEB "This is $0 Version $version";

# Starting...
LOGINF "Starting $0 Version $version for Step $step s";

# Wait 0-5 seconds randomly to let different instances not to start simoultaniously
sleep rand(5);

# Read Statistics.json
my $statisticsfile = "$cfg->{Main}->{Configfolder}/statistics.json";
if (!-e "$statisticsfile") {
	LOGERR "$statisticsfile does not exist. Giving up.";
	exit 2;
}
my $statsparser = Stats4Lox::JSON->new();
my $statsobj = $statsparser->open(filename => $statisticsfile, writeonclose => 1);
#$statsparser->dump($statsobj);

# Fetch data from Sources
my @fetcheddata = data_fetching();

# Send data to Sinks
data_sending();

# End
LOGEND();
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
		my $statcfgfilename = $cfg->{Main}->{Configfolder} . "/" . $statsobj->{Stat}->{$key}->{statCfgFile};
		#print "Statcfgfilename: $statcfgfilename\n";
		our $statscfg = $statcfgparser->open(filename => $statcfgfilename, writeonclose => 1);
		
		# Load Source Plugin
		eval {
			require "$lbphtmlauthdir/Sources/$Source/$Source.pm";
		};
		if ($@) {
			#print STDERR " !!! Source Plugin $plugin failed to load: $@\n";
			$statsobj->{Stat}->{$key}->{fetchStatus} = 'error';
			$statsobj->{Stat}->{$key}->{fetchStatusError} = "Plugin failed to load: $@";
			next;
		}
		# Run the fetch command
		my %returnhash;
		eval { 
			%returnhash = "Stats4Lox::Sources::$Source"->fetch( statid => $key, statcfg => $statscfg );
		};
		if ($@) {
			#print STDERR " !!! Source Plugin $plugin could not fetch: $@\n";
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
		my $statcfgfilename = $cfg->{Main}->{Configfolder} . "/" . $statsobj->{Stat}->{$statid}->{statCfgFile};
		my $statscfg = $statcfgparser->open(filename => $statcfgfilename, writeonclose => 1);
	
		
		# LOGDEB Dumper($statscfg);
		
		# We need to loop through the sink plugins
		my %sinks = %{$statscfg->{Sink}};
		LOGDEB "Number of sinks: " . scalar keys %sinks;
		foreach my $Sink (keys %sinks) {
			LOGDEB "Sink $Sink \n";
			
			# Load Sink plugin
			eval {
				require "$lbphtmlauthdir/Sinks/$Sink/$Sink.pm";
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
				$ok = "Stats4Lox::Sinks::$Sink"->value( 
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

