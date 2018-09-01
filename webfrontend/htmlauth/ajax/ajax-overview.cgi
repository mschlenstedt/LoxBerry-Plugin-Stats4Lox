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




if ($R::action eq "get" and $R::jsonfile) {
	if (! -e "$main::configfolder/$R::jsonfile") {
		error("File not found");
	}
	respond(Stats4Lox::read_file("$main::configfolder/$R::jsonfile"));
}

if ($R::action eq "statcfg" and $R::jsonfile) {
	if (! -e "$main::configfolder/$R::jsonfile") {
		error("File not found");
	}
	respond(Stats4Lox::read_file("$main::configfolder/$R::jsonfile"));
}


error("action not supported");
exit 1;



sub error 
{
	my ($errmsg) = @_;
	
	print $cgi->header(	-type => 'application/json;charset=utf-8',
					-status => "500 Internal server error $errmsg");
	print "{ \"error\": 1, \"status\" : \"$errmsg\" }\n";
	exit 1;
}

sub respond
{
	my ($response) = @_;
	
	print $cgi->header(	-type => 'application/json;charset=utf-8',
					-status => "200 OK");
	print $response;
	exit 0;
}
