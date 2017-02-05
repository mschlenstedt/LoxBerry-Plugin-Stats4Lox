use strict;
use File::HomeDir;
use Cwd 'abs_path';
use Carp;

package LoxBerry::Stats4Lox;

my %dbsettings;
my $installfolder = File::HomeDir->my_home;
my $psubfolder = Cwd::abs_path($0);
$psubfolder =~ s/(.*)\/(.*)\/(.*)$/$2/g;

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
# 	Use LoxBerry::Stats4Lox;
# 	my %dbs = LoxBerry::Stats4Lox::get_databases_by_name();
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
# 	Use LoxBerry::Stats4Lox;
# 	my %dbs = LoxBerry::Stats4Lox::get_databases_by_id();
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
# Sort dbsettings.dat by name
#####################################################
#
# Usage: 
# 	Use LoxBerry::Stats4Lox;
# 	my $result = LoxBerry::Stats4Lox::sort_dbsettings();
#	if ($result) { print "OK\n" } else { print "ERROR\n" };

sub sort_dbsettings
{
	# Read
	my @zeilen=();
	my $result = 1;
	my $input_file="$installfolder/config/plugins/$psubfolder/dbsettings.dat";
	open (F, '<', $input_file) or Carp::carp "Could not read dbsettings.dat\n";
	while(<F>)
	{
		 chomp($_ );
		 push @zeilen, [ split /\|/, $_, 2 ];
	}
	close (F);
	# Error?
	if ( $! ) { $result = 0};

	# Sort by name
	@zeilen=sort{$a->[1] cmp $b->[1]}@zeilen;

	# Write sorted dbsettings.dat
	open (F, '+<', $input_file) or Carp::carp "Could not write dbsettings.dat\n";
	flock(F, 2);
	my @data = <F>;
	seek(F,0,0);
	truncate(F,0);
	my $i = 1;
	foreach (@zeilen) {
		# Skip Comments
		if (@{$_}[0] =~ /^\s*#.*/) {
			print F "@{$_}[0]\n";
			next;
		}
		# Skip old enty for "Standardsettings
		if (@{$_}[0] eq "1") {
			next;
		}
		if ($i eq "1") {
			# First dataset is the standard settings
			my $pphrase;
			my $settingsname = "Standard";
			if ( $pphrase->param("TXT0029") ) {
				my $settingsname = $pphrase->param("TXT0029");
			}
			print F "$i|$settingsname\n";
			$i++;
		} 
		# Print dataset
		print F "$i|@{$_}[1]\n";
		$i++;
	}
	close (F);

	# Error?
	if ( $! ) { $result = 0};

	return $result;
}	 


#####################################################
# Finally 1; ########################################
#####################################################
1;
