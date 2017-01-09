#!/usr/bin/perl

# scheduler.pl

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


#use strict;
#use warnings;

##########################################################################
# Modules
##########################################################################

use File::HomeDir;
use File::Basename;
use File::Copy;
use Data::Dumper qw(Dumper);


# our $psubfolder = abs_path($0);
# $psubfolder =~ s/(.*)\/(.*)\/bin\/(.*)$/$2/g;
my $psubfolder = 'stats4lox';

# my $home = File::HomeDir->my_home;
my $home = '/opt/loxberry';

my $job_basepath = "$home/data/plugins/$psubfolder/import";

my $max_concurrent_jobs = 1;


# First check running jobs
my @runninglist = <"$job_basepath/*.running.*">;
foreach $job (@runninglist) {
	my($filename, $dirs, $suffix) = fileparse($job);
	# print "RUNNINGLIST: $job\n";
	my($jobname, $jobpid) = (split /\./, $filename)[0, 2];
	#-- check if process 1525 is running
	$running = kill 0, $jobpid;
	if (! $running) {
		# This process is dead
		move ("$job", "$job_basepath/$jobname.failed");
	}
}

# Finally we get alls really running jobs
my @runninglist = <"$job_basepath/*.running.*">;
my $numrunningjobs = scalar @runninglist;

my @joblist = <"$job_basepath/*.job">;
foreach $job (@joblist) {
	if ( $numrunningjobs < $max_concurrent_jobs ) {
		my($filename, $dirs, $suffix) = fileparse($job);
		my($jobname, $fileext) = (split /\./, $filename)[0, 1];
		print "Stats4Lox Import: Starting job $jobname\n";
		$numrunningjobs++;
		system("/usr/bin/perl $home/webfrontend/cgi/plugins/$psubfolder/bin/import.pl --job=$jobname 2>&1 &");
	}
}
