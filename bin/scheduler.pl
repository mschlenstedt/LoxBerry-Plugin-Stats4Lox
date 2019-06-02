#!/usr/bin/perl

# Stats4Lox Import Scheduler

# Copyright 2017-2018 Christian Fenzl, christiantf@gmx.at
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

use LoxBerry::System;
require "$lbpbindir/libs/Stats4Lox.pm";
use File::Basename;

my $check = LoxBerry::System::lock(lockfile => 'stats4lox_import');
if($check) {
	print STDERR "Another instance of the Stats4Lox Import Scheduler is running (Lock by $check).\n";
	print STDERR "Terminating.\n";
	exit(1);
}

my $job_basepath = "$lbhomedir/data/plugins/$lbpplugindir/import";

if (!$CFG::IMPORT_MAX_CONCURRENT_JOBS) {
	$Stats4Lox::pcfg->param("Import.max_concurrent_jobs", 1);
}

my $max_concurrent_jobs = $CFG::IMPORT_MAX_CONCURRENT_JOBS ? $CFG::IMPORT_MAX_CONCURRENT_JOBS : 2;

my @joblist;

# We loop the routine until all jobs are processed
do {
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

	@joblist = <"$job_basepath/*.job">;
	foreach $job (@joblist) {
		if ( $numrunningjobs < $max_concurrent_jobs ) {
			my($filename, $dirs, $suffix) = fileparse($job);
			my($jobname, $fileext) = (split /\./, $filename)[0, 1];
			print "Stats4Lox Import: Starting job $jobname\n";
			$numrunningjobs++;
			system("/usr/bin/perl $lbhomedir/webfrontend/cgi/plugins/$lbpplugindir/bin/import.pl --job=$jobname &");
		}
	}
	if (scalar @joblist != 0) {
		print "Waiting for next slot (open jobs: " . scalar @joblist . ")\n";
		sleep 30;
	}
} while (scalar @joblist != 0);


# When the scheduling is finished, unlock
END
{
	LoxBerry::System::unlock(lockfile => 'stats4lox_import');
}
