use LoxBerry::System;
require "$lbpbindir/libs/Stats4Lox.pm";
use strict;

package Stats4Lox::Migration;

my $ConfigVersion = $Stats4Lox::ConfigVersion;

sub data_migration 
{
	## Migrate to V1
	if($Stats4Lox::pcfg->param("Main.ConfigVersion") < 1) {
		migration_v1();
	}
	
	# Migrate to V2
	if($Stats4Lox::pcfg->param("Main.ConfigVersion") < 2 ) {
		migration_v2();
	}
}


#### Migration V1

sub migration_v1
{
	require File::Copy;
	mkdir "$LoxBerry::System::lbpdatadir/s4ldata";
	File::Copy::move("$LoxBerry::System::lbpconfigdir/databases.dat", "$LoxBerry::System::lbpdatadir/s4ldata/");
	File::Copy::move("$LoxBerry::System::lbpconfigdir/dbsettings.dat", "$LoxBerry::System::lbpdatadir/s4ldata/");
	File::Copy::move("$LoxBerry::System::lbpconfigdir/id_databases.dat", "$LoxBerry::System::lbpdatadir/s4ldata/");
	$Stats4Lox::pcfg->param("Main.ConfigVersion", 1);
}

#### Migration V2

sub migration_v2
{
	## Database to JSON conversion

	my %dbs = Stats4Lox::Migration::get_databases_by_id_v1();
	# $Stats4Lox::JSON::DEBUG = 1;

	my $jsonparser = Stats4Lox::JSON->new();
	unlink $CFG::MAIN_CONFIGFOLDER . "/databases.json";
	my $config = $jsonparser->open(filename => $CFG::MAIN_CONFIGFOLDER . "/statistics.json", writeonclose => 1);

	my %db_hash;
	
	foreach my $key (sort keys %dbs) {
		#print "DB $dbs{$key}{Description}\n";
		my %obj = %{$dbs{$key}}; 
		my %Stat;
		my %Sink;
		my %Source;
		my $jsonnewobj = Stats4Lox::JSON->new();
		my $statcfgfilename = "statcfg_" . $obj{dbidstr} . ".json";
		my $newobj = $jsonnewobj->open(filename => $CFG::MAIN_CONFIGFOLDER . "/$statcfgfilename", writeonclose => 1);
		
		# Managing field 0: DB-Name / Statistic ID
		my $statid = $obj{dbidstr}+0;
		# $Stat{'statid'} = $statid;
		$Stat{'statidOld'} = $obj{dbidstr};
		$Stat{'statCfgFile'} = "$statcfgfilename";
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
		$Source{'Loxone'}{'minValue'} = $obj{Min};
		$Sink{'RRD'}{'minValue'} = $obj{Min};
		
		# Managing field 6: Max
		$Source{'Loxone'}{'minValue'} = $obj{Max};
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
		
		
		
		# Status from file xxxx.status
		my $dbstatus = Stats4Lox::read_file($CFG::MAIN_RRDFOLDER . "/" . $obj{dbidstr} . ".status");
		$Stat{'fetchStatus'} = "paused" if ($dbstatus eq "1");
		$Stat{'activated'} = 0 if ($dbstatus eq "1");
		$Stat{'fetchStatus'} = "error" if ($dbstatus eq "0");
		$Stat{'activated'} = 1 if ($dbstatus eq "0");
		$Stat{'fetchStatus'} = "running" if (! $Stat{'fetchStatus'});
		$Stat{'activated'} = 1 if (! $Stat{'activated'});
		
		$newobj->{Sink} = \%Sink;
		$newobj->{Source} = \%Source;
		$config->{Stat}{$statid} = \%Stat;
		
		#push %db_hash, \%Stat;
		$jsonnewobj->write();
		# $jsonnewobj->dump($newobj, "Details");
	}

	
	$jsonparser->write();
	#$jsonparser->dump($config, "Database");
	$Stats4Lox::pcfg->param("Main.ConfigVersion", 2);
}

sub get_databases_by_id_v1
{
	my %entries;
	
	open(F,"<$CFG::MAIN_CONFIGFOLDER/databases.dat");
	my @data = <F>;
	close (F) ;
		
	# Loop over DB
	foreach (@data){
		# my @single_template = @template;
		s/[\n\r]//g;
		# Comments
		if ($_ =~ /^\s*#.*/) {
			next;
		}
		my @fields = split(/\|/);
		my $dbid = lc($fields[0]);
		$entries{$dbid}{dbidstr} = sprintf("%04d", $fields[0]);
		$entries{$dbid}{Step} = $fields[1];
		$entries{$dbid}{Description} = $fields[2];
		$entries{$dbid}{Loxonename} = $fields[3];
		$entries{$dbid}{Miniserver} = $fields[4];
		$entries{$dbid}{Min} = $fields[5];
		$entries{$dbid}{Max} = $fields[6];
		$entries{$dbid}{Place} = $fields[7];
		$entries{$dbid}{Category} = $fields[8];
		$entries{$dbid}{UID} = $fields[9];
		$entries{$dbid}{Unit} = $fields[10];
		$entries{$dbid}{Block} = $fields[11];
	}
	return %entries;
}	 

#### Migration V ?





#####################################################
# Finally 1; ########################################
#####################################################
1;
