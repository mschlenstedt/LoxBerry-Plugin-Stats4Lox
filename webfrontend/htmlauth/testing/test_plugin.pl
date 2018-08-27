#!/usr/bin/perl

use LoxBerry::System;
require "$lbpbindir/libs/Stats4Lox.pm";

print "Statistics File: $statisticsfile\n";

my @plugins = ( "RRD", "Sample", "MySQL" );

foreach $plugin (@plugins) {
	print "Plugin: $plugin\n";
	eval {
		require "$lbpbindir/libs/Sinks/$plugin.pm";
	};
	if ($@) {
		print " !!! Plugin $plugin failed to load: $@\n";
	}
	eval { 
		"Stats4Lox::Sink::$plugin"->fetch(12);
	};
	if ($@) {
		print " !!! Plugin $plugin could not fetch: $@\n";
	}
	
}




# require Data::Dumper;
# print Data::Dumper::Dumper(\@plugins);
