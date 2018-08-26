#!/usr/bin/perl

use LoxBerry::System;
require "$lbpbindir/libs/Stats4Lox.pm";

my %dbs = Stats4Lox::get_databases_by_id();
#print "TEST: " . $dbs{'0005'}{'Description'} . "\n";

# $Stats4Lox::JSON::DEBUG = 1;

my $jsonparser = Stats4Lox::JSON->new();
unlink $CFG::MAIN_CONFIGFOLDER . "/databases.json";
my $config = $jsonparser->open(filename => $CFG::MAIN_CONFIGFOLDER . "/statistics.json", writeonclose => 1);

my @db_array;
my %Sink;

foreach my $key (sort keys %dbs) {
	#print "DB $dbs{$key}{Description}\n";
	my %obj = %{$dbs{$key}}; 
	my %Stat;
	my %Sink;
	my %Source;
	my $jsonnewobj = Stats4Lox::JSON->new();
	my $newobj = $jsonnewobj->open(filename => $CFG::MAIN_CONFIGFOLDER . "/statcfg_" . $obj{dbidstr} . ".json", writeonclose => 1);
	
	# Managing field 0: DB-Name / Statistic ID
	$Stat{'statid'} = $obj{dbidstr}+0;
	$Stat{'statidOld'} = $obj{dbidstr};
	$Stat{'statCfgFile'} = $obj{dbidstr} . ".json";
	
	$Sink{'RRD'}{'filename'} = $obj{dbidstr} . ".rrd";
	$newobj->{'statid'} = $obj{dbidstr}+0;
	
	# Managing field 1: Step
	$Stat{'fetchStep'} = $obj{Step};
	$Sink{'RRD'}{'step'} = $obj{Step};
	
	# Managing field 2: Description
	$newobj->{'name'} = $obj{Description};
	$newobj->{'description'} = "";
	
	# Managing field 3: Loxone-Name to fetch
	$Stat{'Source'} = 'Loxone';
	$Source{'Loxone'}{'fetchSource'} = $obj{Loxonename};
	
	# Managing field 4: Miniserver
	$Source{'Loxone'}{'msno'} = $obj{Miniserver};

	# Managing field 5: Min
	$newobj{'Source'}{'Loxone'}{'minValue'} = $obj{Min};
	$Sink{'RRD'}{'minValue'} = $obj{Min};
	
	# Managing field 6: Max
	$newobj{'Source'}{'Loxone'}{'minValue'} = $obj{Max};
	$Sink{'RRD'}{'maxValue'} = $obj{Max};
	
	# Managing field 7: Place
	$Source{'Loxone'}{'place'} = $obj{Place};

	# Managing field 8: Category
	$Source{'Loxone'}{'category'} = $obj{Category};
	
	# Managing field 9: UID
	$Source{'Loxone'}{'uid'} = $obj{UID};
	
	# Managing field 10: Unit
	$Source{'Loxone'}{'unit'} = $obj{Unit};
	
	# Managing field 11: Block
	$Source{'Loxone'}{'blockType'} = $obj{Block};
	
	
	$newobj->{Sink} = \%Sink;
	$newobj->{Source} = \%Source;
	
	# Status from file xxxx.status
	my $dbstatus = Stats4Lox::read_file($CFG::MAIN_RRDFOLDER . "/" . $obj{dbidstr} . ".status");
	$Stat{'fetchStatus'} = "paused" if ($dbstatus eq "1");
	$Stat{'fetchStatus'} = "error" if ($dbstatus eq "0");
	$Stat{'fetchStatus'} = "running" if (! $Stat{'fetchStatus'});
	
	
	push @db_array, \%Stat;
	$jsonnewobj->write();
	$jsonnewobj->dump($newobj, "Details");
}

$config->{Stat} = \@db_array;






$jsonparser->dump($config, "Database");
