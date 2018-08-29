#!/usr/bin/perl
use LoxBerry::System;
require "$lbpbindir/libs/Stats4Lox.pm";
use CGI qw(:standard);
use JSON;
use warnings;
use strict;
use RRDs;

use Data::Dumper;


our $cgi = CGI->new;
$cgi->import_names('R');

my @output;
my %resp;

1 if ($CFG::MAIN_RRDFOLDER);


#if ($R::action eq "rrd_xport") {
	rrd_xport();
#}




exit;


sub rrd_xport
{
	my $rrdfile = $CFG::MAIN_RRDFOLDER . "/" . "0011.rrd";
	print STDERR "$rrdfile\n";
	my @arguments;
	
	
	
	# /usr/bin/rrdtool xport --json --showtime DEF:vname=0011.rrd:value:AVERAGE XPORT:vname:"something"
	# my $output = qx(/usr/bin/rrdtool xport --json --sh-d /var/run/rrdcached.sock $rrdfile N:$value);
	

	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	### rrds::xport
	
	# --json DEF:vname=0001.rrd:value:AVERAGE XPORT:vname
	#xport gives no timestamps
	push @arguments, "--json";
	push @arguments, "DEF:avg=$rrdfile:value:AVERAGE";
	push @arguments, "DEF:max=$rrdfile:value:MINIMUM";
	
	push @arguments, "XPORT:vname";
	
	my ($start,$end,$step,$cols,$names,$data) = RRDs::xport(@arguments);
	print STDERR "RRD-Error: ", RRDs::error, "\n" if (RRDs::error);
	
	$resp{start} = $start+0 if ($start);
	$resp{end} = $end+0 if ($end);
	$resp{step} = $step+0 if ($step);
	
	
	my @dataset;
	for (@$data) {
		my @line;
		@line = ( $start * 1000, @$_[0]);
		$start+=$step;
		push @dataset, \@line;
	}
	$resp{data} = \@dataset;
	
	# print STDERR Dumper(%resp);
	
	print header('application/json');
	print to_json(\%resp);
	
	
	
	
	
	### rrds::fetch
	# push @arguments, $rrdfile;
	# push @arguments, "AVERAGE";
	# my ($start,$step,$names,$data) = RRDs::fetch(@arguments);
	# print "RRD-Error: ", RRDs::error, "\n" if (RRDs::error);
	
	# print "Start:       ", scalar localtime($start), " ($start)\n";
	# print "Step size:   $step seconds\n";
	# print "DS names:    ", join (", ", @$names)."\n";
	# print "Data points: ", $#$data + 1, "\n";
	# print "Data:\n";
	# for my $line (@$data) {
		# print "  ", scalar localtime($start), " ($start) ";
		# $start += $step;
		# for my $val (@$line) {
			# printf "%12.1f ", $val;
		# }
		# print "\n";
	# }
	
	#print Dumper($data);
	
	
	#print $ERR . "\n";


}



	
