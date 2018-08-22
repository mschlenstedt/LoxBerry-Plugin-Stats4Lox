use LoxBerry::System;
use strict;

package Stats4Lox;

my %dbsettings;
my $installfolder = $LoxBerry::System::lbhomedir;
my $psubfolder = $LoxBerry::System::lbpplugindir;

## Routines to run on every inclusion
#####################################

our $pcfgfile = "$LoxBerry::System::lbpconfigdir/stats4lox.cfg";
our $pcfg;

if (! -e $pcfgfile) {
		$pcfg = new Config::Simple(syntax=>'ini');
		$pcfg->param("Main.ConfigVersion", "1");
		$pcfg->write($pcfgfile);
	}
$pcfg = new Config::Simple($pcfgfile);
$pcfg->autosave(1);

# RRD Database folder
our $rrdfolder;
if ($pcfg->param('Main.rrdfolder') and ! -e $pcfg->param('Main.rrdfolder')) {
	# Configured but does not exists
	undef $rrdfolder;
}
if (! $pcfg->param('Main.rrdfolder')) {
	# Not configured
	$rrdfolder = "$LoxBerry::System::lbpdatadir/databases";
	$pcfg->param('Main.rrdfolder', $rrdfolder);
}

# Finally import to CFG namespace
$pcfg->import_names('CFG');
# Access config variables by $CFG::Main_rrdfolder

######################################
## Functions to run on demand





use base 'Exporter';
#our @EXPORT = (
#
#);

############################
# Get database template
############################
sub get_dbsettings
{
	if (! %dbsettings) {
		open(F,"<$installfolder/config/plugins/$psubfolder/dbsettings.dat");
        my @data = <F>;
        foreach (@data) {
            s/[\n\r]//g;
            # Comments
            if ($_ =~ /^\s*#.*/) {
                next;
            }
            my @fields = split(/\|/);
            if ($fields[0]) { 
				$dbsettings{$fields[0]}{Name} = $fields[1];
			}
		}
		close (F);
	}

	return %dbsettings;
}

#####################################################
# Create hash of DBs by loxonename
#####################################################
#
# Usage: 
# 	require "$lbpbindir/libs/Stats4Lox.pm";
# 	my %dbs = Stats4Lox::get_databases_by_name();
# 	my $loxonename = "puffertemp";
#	my $description = %dbs{$loxonename}{Description};

sub get_databases_by_name 
{
	my %entries;
	
	open(F,"<$installfolder/config/plugins/$psubfolder/databases.dat");
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
		my $loxonename = lc($fields[3]);
		$entries{$loxonename}{dbid} = $fields[0];
		$entries{$loxonename}{dbidstr} = sprintf("%04d", $fields[0]);
		$entries{$loxonename}{Step} = $fields[1];
		$entries{$loxonename}{Description} = $fields[2];
		$entries{$loxonename}{Miniserver} = $fields[4];
		$entries{$loxonename}{Min} = $fields[5];
		$entries{$loxonename}{Max} = $fields[6];
		$entries{$loxonename}{Place} = $fields[7];
		$entries{$loxonename}{Category} = $fields[8];
		$entries{$loxonename}{UID} = $fields[9];
		$entries{$loxonename}{Unit} = $fields[10];
		$entries{$loxonename}{Block} = $fields[11];
	}
	return %entries;
}	 

#####################################################
# Create hash of DBs by dbid
#####################################################
# Usage: 
# 	my %dbs = Stats4Lox::get_databases_by_id();
# 	my $statid = 2;
#	my $description = %dbs{$statid}{Description};

sub get_databases_by_id 
{
	my %entries;
	
	open(F,"<$installfolder/config/plugins/$psubfolder/databases.dat");
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




#####################################################
# Finally 1; ########################################
#####################################################
1;
