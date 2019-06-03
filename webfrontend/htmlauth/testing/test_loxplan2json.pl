#!/usr/bin/perl
use LoxBerry::System;
use LoxBerry::Log;
require "$lbpbindir/libs/Loxone/ParseXML.pm";

my $log = LoxBerry::Log->new (
    package => 'Stats4Lox',
	name => 'LoxPlan',
	nofile => 1,
	stderr => 1,
	loglevel => 7
);

LOGSTART "Testing loxplan2json\n";

Loxone::ParseXML::loxplan2json( log => $log , filename => "$lbhomedir/webfrontend/legacy/Haus.LoxPLAN", output => "$lbhomedir/webfrontend/legacy/Haus.json" );

LOGEND;
