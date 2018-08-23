#!/usr/bin/perl

use LoxBerry::System;
require "$lbpbindir/libs/Stats4Lox.pm";
use JSON;
use CGI;
use warnings;
use strict;

our $cgi = CGI->new;
$cgi->import_names('R');

my @output;
my %resp;

if ($R::action eq 'startprocess' and $R::key eq 'grafana') {
	
	
	exit(0);
}


if ($R::action eq "query" and $R::key ="grafana") {
	
	my @output = qx { pgrep -f grafana-rrd-server };
	my $rc = $?;
	$rc = $rc >> 8 unless ($rc == -1);
	$res{'running_status'} = $rc == 1 ? "false" : "true";
	$res{'rrdserverport'} = defined $CFG::GRAFANA_RRDSERVERPORT ? $CFG::GRAFANA_RRDSERVERPORT : "null";
	$res{'enablerrdserver_switch'} = is_enabled($CFG::GRAFANA_ENABLERRDSERVER) ? "true" : "false";
	
	
	# my $rrdserver_autostart = qx { systemctl is-enabled kodi };
	# my $rc = $?;
	# $rc = $rc >> 8 unless ($rc == -1);
	# $kodi_autostart = $rc == 0 ? 1 : 0;
	
	# my $kodi_started = qx { systemctl is-active kodi };
	# $rc = $?;
	# $rc = $rc >> 8 unless ($rc == -1);
	# $kodi_started = $rc == 0 ? 1 : 0;
	
	
	print $cgi->header(-type => 'application/json;charset=utf-8',
					-status => "200 OK");
	
	print to_json \%res;
	
	exit;
}

if ($R::action eq "service") {
	if ($R::key eq "kodi" && $R::value eq "stop") {
		qx { systemctl stop kodi };
	} 
	if ($R::key eq "kodi" && $R::value eq "start") {
		qx { systemctl start kodi };
	} 
	if ($R::key eq "kodi" && $R::value eq "restart") {
		qx { systemctl restart kodi };
	} 
	my $rc = $?;
	$rc = $rc >> 8 unless ($rc == -1);
	if ($rc eq "0") {
		print $cgi->header(-type => 'application/json;charset=utf-8',
					-status => "200 OK");
		print "{\"status\":\"OK\", \"error\": 0, \"key\": \"$R::key\", \"value\": \"$R::value\"}";
	} else {
		print $cgi->header(-type => 'application/json;charset=utf-8',
					-status => "500 Error");
		print "{\"status\": \"Error\", \"error\": 1, \"key\": \"$R::key\", \"value\": \"$R::value\"}";
	}
	exit;
}







	print $cgi->header(-type => 'application/json;charset=utf-8',
					-status => "501 Action not implemented");
	print '{"status": "Not implemented", "error":1}';

exit;


sub replace_str_in_file
{
	my ($filename, $findstr, $replacestr) = @_;
	
	my $newfilestr;
	my $foundstr;
	
	return 0 if (! $filename || ! $findstr);
	
	eval {

		open(my $fh, '<', $filename)
		  or warn "Could not open file for reading: '$filename' $!";
		  
		while (my $row = <$fh>) {
			if (begins_with($row, $findstr)) {
				print STDERR "Found string - rewriting it";
				$newfilestr .= "$replacestr\n";
				$foundstr = 1;
			} else {
				$newfilestr .= $row;
			}
		}
		close $fh;
		if (! $foundstr) {
			print STDERR "Adding missing string";
			$newfilestr .= "$replacestr\n";
		}
		
		open($fh, '>', $filename)
			or warn "Could not open file for writing: '$filename' $!";
		print $fh $newfilestr;
		close $fh;
		
	};
	if ($@) {
		print STDERR "Something failed writing the new entry to file $filename.";
		return 0;
	}

	return 1;

}

sub find_str_in_file
{
	my ($filename, $findstr) = @_;
	
	my $newfilestr;
	my $foundstr;
	my $strval;
	
	return undef if (! $filename || ! $findstr);
	
#	eval {

		open(my $fh, '<', $filename)
		  or warn "Could not open file for reading: '$filename' $!";
		  
		while (my $row = <$fh>) {
			if (begins_with($row, $findstr)) {
				print STDERR "Found string - parsing it\n";
				print STDERR "Length of $findstr: " . length($findstr) . "\n";
				chomp $row;
				$strval = substr ($row, length($findstr));
				print STDERR "Row   : $row \n";
				print STDERR "Strval: $strval \n";
				close $fh;
				return($strval);
			} 
			
		}
		close $fh;
		
#	};
	# if ($@) {
		# print STDERR "Something failed reading the the file $filename.";
		# return undef;
	# }

	return undef;

}

sub startrrdserver
{
	my $arch = 'raspberry';
	my $params = 
	
	system ("su - loxberry -c \'$lbpbindir/$arch/grafana-rrd-server\' > /dev/null 2>&1 &");
	
}
sub stoprrdserver
{
	@output = qx { pkill -f grafana-rrd-server };
}
