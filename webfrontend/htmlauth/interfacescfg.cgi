#!/usr/bin/perl

my $fn="statcfg";

use LoxBerry::Web;
use LoxBerry::Log;
require "$lbpbindir/libs/Stats4Lox.pm";
use CGI;

my $ifaces_file = "$configdir/interfaces.json";


my $template = HTML::Template->new(
    filename => "$lbptemplatedir/interfacescfg.html",
    global_vars => 1,
    loop_context_vars => 1,
    die_on_bad_params => 0,
#    associate => %pcfg,
);

our $cgi = CGI->new;
$cgi->import_names('R');


LoxBerry::Web::lbheader("Stat4Lox Interfaces", undef, undef);


if (!$R::interfacename || !$R::interfacetype) {
	interface_list();
} elsif ($R::interfacename && $R::interfacetype) {
	call_interface($R::interfacetype, $R::interfacename);
}





print $template->output();

LoxBerry::Web::lbfooter();




# Read interfaces from disk
sub interface_list
{
	my @Sources;
	my @Sinks;
	
	@Sources = check_interface("Sources", "$lbphtmlauthdir/Sources/");
	@Sinks = check_interface("Sinks", "$lbphtmlauthdir/Sinks/");
	
	$template->param("Sources", \@Sources);
	$template->param("Sinks", \@Sinks);
	$template->param("ifacelist", 1);

}


sub check_interface
{
	my ($interface, $dirToCheck) = @_;
	my @result;
	my $dh;
	opendir my $dh, $dirToCheck;
	my @dirs = grep {-d "$dirToCheck/$_" && ! /^\.{1,2}$/} readdir($dh);
	
	foreach my $dir (keys @dirs) {
		my %dirhash;
		eval {
				require "$lbphtmlauthdir/$interface/$dirs[$dir]/$dirs[$dir].pm";
		};
		if ($@) {
			print STDERR " !!! $interface Plugin $dirs[$dir] failed to load: $@\n";
			
		} else {
			$dirhash{InterfaceName} = $dirs[$dir];
			$dirhash{InterfaceType} = $interface;
			$dirhash{InterfaceDescription} = eval {"Stats4Lox::$interface::$dirs[$dir]"->InterfaceDescription();};
			push @result, \%dirhash;
		}
	}	
	return @result;
}

sub call_interface
{
	my ($interfacetype, $interfacename) = @_;
	
	# Load interfaces.json
	my $ifacesparser = Stats4Lox::JSON->new();
	my $ifacesobj = $ifacesparser->open(filename => $ifaces_file, writeonclose => 1);
		
	my $interfacefile = "$lbphtmlauthdir/$interfacetype/$interfacename/$interfacename.pm";
	eval {
		require $interfacefile;
	};
	if ($@) {
		print STDERR " !!! $interfacetype $interfacename failed to load: $@\n";
		return;
	} 
	
	my %returnhash;
	eval {
		%returnhash = "Stats4Lox::$interfacetype::$interfacename"->initinterface( ifacecfg => $ifacesobj );
	};
	if ($@) {
		print STDERR " !!! $interfacetype Plugin $interfacename could not run initinterface: $@\n";
	}
	if (!$returnhash{html}) {
		$template->param('ifacehtml', "<p>No $interfacetype configuration available.</p>");
	} else {
		$template->param('ifacehtml', $returnhash{html});
	}
	$template->param('ifacename', $interfacename);
	if ($returnhash{ifacecfg}) {
		$ifacesobj = $returnhash{ifacecfg};
		$ifacesparser->write();
	}

}






# # Parameter statid may be directly the filename, or the id)
# if (-e "$configfolder/$statid") {
	# $statcfg_file = $statid;
# } else {
	# # If file not exists, it was presumably a real statid - reading from statistics.json
	# my $statsparser = Stats4Lox::JSON->new();
	# my $statsobj = $statsparser->open(filename => $statisticsfile, readonly => 1);
	# if(! defined $statsobj->{Stat}->{$statid}->{statCfgFile} and ! -e $statsobj->{Stat}->{$statid}->{statCfgFile}) {
		# LOGERR "$fn: Sent statid $statid or file does not exist";
	# } else {
		# $statcfg_file = $statsobj->{Stat}->{$statid}->{statCfgFile};
	# }
	# undef $statsobj;
	# undef $statsparser;
# }

# my $statcfgparser = Stats4Lox::JSON->new();
# my $statcfgobj = $statcfgparser->open(filename => "$configfolder/$statcfg_file");

# LOGDEB "$fn: Stat file that is opened: $statcfg_file";








# # Send statcfg to template
# $template->param("statcfg", to_json($statcfgobj));




# ### Source handling
# sub source_handling
# {

	# # Get Source name
	# my ($Source) = keys %{$statcfgobj->{Source}};
	
	# # Call Sources initstatcfg function
	# eval {
			# require "$lbphtmlauthdir/Sources/$Source/$Source.pm";
	# };
	# if ($@) {
		# print STDERR " !!! Source Plugin $plugin failed to load: $@\n";
	# }
	
	# # Run the initstatcfg command
	# my %returnhash;
	# eval { 
		# %returnhash = "Stats4Lox::Source::$Source"->initstatcfg( statid => $key, statcfg => $statcfgobj );
	# };
	# if ($@) {
		# print STDERR " !!! Source Plugin $plugin could not run initstatcfg: $@\n";
	# }

	# if (!$returnhash{html}) {
	# $template->param('sourcehtml', "<p>No source configuration available.</p>");
	# } else {
	# $template->param('sourcehtml', $returnhash{html});
	# }
	
	# $template->param('sourcename', $Source);
	
	# if ($returnhash{statcfg}) {
		# $statcfgobj = $returnhash{statcfg};
	# }

# }


# ### Sink handling
# sub sink_handling
# {

	# my @sinkhtmls;
	# # We need to loop through the sink plugins
		# my %sinks = %{$statcfgobj->{Sink}};
		# LOGDEB "Number of sinks: " . scalar keys %sinks;
		# foreach my $Sink (keys %sinks) {
			# my %sinkhash;
			# # Call Sources initstatcfg function
			# eval {
					# require "$lbphtmlauthdir/Sinks/$Sink/$Sink.pm";
			# };
			# if ($@) {
				# print STDERR " !!! Sink Plugin $plugin failed to load: $@\n";
				# continue;
			# }
		
			# # Run the initstatcfg command
			# my %returnhash;
			# eval { 
				# %returnhash = "Stats4Lox::Sink::$Sink"->initstatcfg( statid => $key, statcfg => $statcfgobj );
			# };
			# if ($@) {
				# print STDERR " !!! Sink Plugin $Sink could not run initstatcfg: $@\n";
				# continue;
			# }

			# if (!$returnhash{html}) {
				# $sinkhash{html} = "<p>No destination configuration available.</p>";
			# } else {
				# $sinkhash{html} = $returnhash{html};
			# }
			
			# $sinkhash{sinkname} = $Sink;
			
			# if ($returnhash{statcfg}) {
				# $statcfgobj = $returnhash{statcfg};
			# }
			# push @sinkhtmls, \%sinkhash;
		# }
		# $template->param('sinkhtmls', \@sinkhtmls);
# }

