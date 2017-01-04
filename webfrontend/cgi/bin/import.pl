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
# Initiale Pfade berechnen
# Commandline-Parameter lesen
# Logfile initialisieren
# Umbenennen des Jobs in .running
# Job lesen
# Miniserver-Credentials aus Loxberry-DB lesen
# RRD-Pfad aus Statistik-DB auslesen
# evt. RRD-Steps aus RRD-File lesen
# Aus RRD letzten Timestamp lesen (epoch) und in Monat/Jahr umrechnen
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
use Getopt::Long;
use Config::Simple;
use File::HomeDir;
use Cwd 'abs_path';


# Logfile
our $logfilepath; 
our $lf;
our @loglevels;
our $loglevel=4;

# Use loglevel with care! DEBUG=4 really fills up logfile. Use ERRORS=1 or WARNINGS=2, or disable with 0.
# To log everything to STDERR, use $loglevel=5.

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.1.2";

# Figure out in which subfolder we are installed
our $psubfolder = abs_path($0);
$psubfolder =~ s/(.*)\/(.*)\/(.*)$/$2/g;

# Commandline options
my $verbose = 4;
my $jobfilepath = '';

GetOptions ('verbose' => \$verbose=4,
            'job=s' => \$jobfilepath,
            'quiet'   => sub { $verbose = 0 });


			
$logfilepath = "$home/log/plugins/$psubfolder/import_pl.log";
openlogfile();
logger(4, "Logfile $logfilepath opened");










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
	