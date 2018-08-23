#!/usr/bin/perl
use LoxBerry::System;
require "$lbpbindir/libs/Stats4Lox.pm";
use LoxBerry::Web;
use CGI;
use JSON;
use warnings;
use strict;

our $cgi = CGI->new;
$cgi->import_names('R');

my @output;
my %resp;


if ($R::action eq "change") {
	my $success;
	$Stats4Lox::pcfg->param($R::key, $R::value) if ($R::value);
	$Stats4Lox::pcfg->delete("$R::key") if (!$R::value);
	$resp{'success'} = "true";
}

# Grafana: Start/Stop rrdserver on change
if ($R::action eq "change" and $R::key eq "GRAFANA.enablerrdserver" and $R::value eq "false") {
	stop_rrdserver();
}
if ($R::action eq "change" and $R::key eq "GRAFANA.enablerrdserver" and $R::value eq "true") {
	start_rrdserver();
}

if ($R::action eq "start" and $R::key eq "GRAFANA.enablerrdserver") {
	# Starting from daemon
	start_rrdserver();
	$resp{'success'} = "true";
}


# Delete a full block in the config file
if ($R::action eq "delete_block") {
	$Stats4Lox::pcfg->set_block($R::key);
	$resp{'success'} = "true";
}

# Queries all status from grafana.html
if ($R::action eq "query" and $R::key eq "grafana") {
	my @output = qx { pgrep -f grafana-rrd-server };
	my $rc = $?;
	$rc = $rc >> 8 unless ($rc == -1);
	$resp{'running_status'} = $rc == 1 ? "false" : "true";
	$resp{'rrdserverport'} = defined $CFG::GRAFANA_RRDSERVERPORT ? $CFG::GRAFANA_RRDSERVERPORT : undef;
	$resp{'enablerrdserver'} = is_enabled($CFG::GRAFANA_ENABLERRDSERVER) ? "true" : undef;
	$resp{'success'} = "true";
}



#if ($R::action eq "service") {
#	$output = qx { sudo $lbpbindir/elevatedhelper.pl action=service key=$R::key value=$R::value};
	# print $cgi->header(-type => 'application/json;charset=utf-8',
							# -status => "204 No Content");
	# exit;
# }

if (%resp) {
	print $cgi->header(-type => 'application/json;charset=utf-8',
					-status => "200 OK");
	print to_json \%resp;
	exit();
}

### If nothing matches - Send an error 501
print $cgi->header(	-type => 'application/json;charset=utf-8',
					-status => "501 Action not implemented");
print "{status: 'Not implemented'}";

exit;


sub start_rrdserver
{
	my @is_files = glob( $LoxBerry::System::lbsconfigdir . '/is_*.cfg' );
	my $mainarch;
	my $subarch = "";
	my $archused;
	foreach my $is_file (@is_files) {
		my $arch = substr($is_file, rindex($is_file, '/')+4);
		$arch = substr($arch, 0, length($arch)-4);
		#print STDERR "Found arch: $arch\n";
		$mainarch = "x86" if ($arch eq "x86");
		$mainarch = "x64" if ($arch eq "x64");
		$mainarch = "raspberry" if ($arch eq "raspberry");
		$subarch = $arch if ($arch ne "x86" and $arch ne "x64" and $arch ne "raspberry");
	}
	#print STDERR "mainarch: $mainarch subarch: $subarch\n";
	$archused = $mainarch if (-e "$lbpbindir/grafana-rrd-server/$mainarch/grafana-rrd-server");
	$archused = $subarch if (-e "$lbpbindir/grafana-rrd-server/$subarch/grafana-rrd-server");
	#print STDERR "archused: $archused\n";
	
	if (! $archused) {
		$resp{"success"} = "false";
		$resp{"message"} = "No matching architecture found.";
	} else {
			my $params = "-p $CFG::GRAFANA_RRDSERVERPORT -r $CFG::MAIN_RRDFOLDER";
			stop_rrdserver();
			my $fullcommand = "$lbpbindir/grafana-rrd-server/$archused/grafana-rrd-server $params  > /dev/null 2>&1 &";
			print STDERR "Full command: $fullcommand\n";
			system ($fullcommand);
	}
}
sub stop_rrdserver
{
	@output = qx { pkill -f grafana-rrd-server };
}
