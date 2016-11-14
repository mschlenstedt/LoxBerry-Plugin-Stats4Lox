#!/usr/bin/perl

# Copyright 2016 Michael Schlenstedt, michael@loxberry.de
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


##########################################################################
# Modules
##########################################################################

use CGI::Carp qw(fatalsToBrowser);
use CGI qw/:standard/;
use LWP::UserAgent;
use String::Escape qw( unquotemeta );
use Config::Simple;
use File::HomeDir;
use Cwd 'abs_path';
use URI::Escape;
use XML::Simple qw(:strict);
use warnings;
#use strict;
#no strict "refs"; # we need it for template system
our $namef;
our $value;
our @query;
our @fields;
our @lines;
my $home = File::HomeDir->my_home;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.8";

# Figure out in which subfolder we are installed
our $psubfolder = abs_path($0);
$psubfolder =~ s/(.*)\/(.*)\/(.*)$/$2/g;

my  $cfg             = new Config::Simple("$home/config/system/general.cfg");
our $installfolder   = $cfg->param("BASE.INSTALLFOLDER");
our $lang            = $cfg->param("BASE.LANG");
our $miniservercount = $cfg->param("BASE.MINISERVERS");
our $clouddnsaddress = $cfg->param("BASE.CLOUDDNS");
our $curlbin         = $cfg->param("BINARIES.CURL");
our $grepbin         = $cfg->param("BINARIES.GREP");
our $awkbin          = $cfg->param("BINARIES.AWK");

#########################################################################
# Parameter
#########################################################################

# Everything from URL
foreach (split(/&/,$ENV{'QUERY_STRING'}))
{
  ($namef,$value) = split(/=/,$_,2);
  $namef =~ tr/+/ /;
  $namef =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $value =~ tr/+/ /;
  $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $query{$namef} = $value;
}

# Set parameters coming in - get over post
if ( !$query{'script'} ) { 
	if ( param('script') ) { 
		our $script = quotemeta(param('script')); 
	} else { 
		our $script = 0;
	} 
} else { 
	our $script = quotemeta($query{'script'}); 
}
if ( !$query{'saveformdata'} ) { 
	if ( param('saveformdata') ) { 
		our $saveformdata = quotemeta(param('saveformdata')); 
	} else { 
		our $saveformdata = 0;
	} 
} else { 
	our $saveformdata = quotemeta($query{'saveformdata'}); 
}
if ( !$query{'lang'} ) {
	if ( param('lang') ) {
		$lang = quotemeta(param('lang'));
	} else {
		$lang = "de";
	}
} else {
	$lang = quotemeta($query{'lang'}); 
}
if ( !$query{'do'} ) { 
	if ( param('do') ) {
		our $do = quotemeta(param('do'));
	} else {
		our $do = "form";
	}
} else {
	our $do = quotemeta($query{'do'});
}
if ( !$query{'rracount'} ) { 
	if ( param('rracount') ) {
		our $rracount = quotemeta(param('rracount'));
	} else {
		our $rracount = 1;
	}
} else {
	our $rracount = quotemeta($query{'rracount'});
}
if ( !$query{'loxonename'} ) { 
	if ( param('loxonename') ) {
		our $loxonename = quotemeta(param('loxonename'));
	} else {
		our $loxonename = "";
	}
} else {
	our $loxonename = quotemeta($query{'loxonename'});
}
if ( !$query{'miniserver'} ) { 
	if ( param('miniserver') ) {
		our $miniserver = quotemeta(param('miniserver'));
	} else {
		our $miniserver = 1;
	}
} else {
	our $miniserver = quotemeta($query{'miniserver'});
}
if ( !$query{'description'} ) { 
	if ( param('description') ) {
		our $description = quotemeta(param('description'));
	} else {
		our $description = "";
	}
} else {
	our $description = quotemeta($query{'description'});
}
if ( !$query{'min'} && $query{'min'} ne 0 ) { 
	if ( param('min') || param('min') eq 0 ) {
		our $min = quotemeta(param('min'));
	} else {
		our $min = "";
	}
} else {
	our $min = quotemeta($query{'min'});
}
if ( !$query{'max'} && $query{'max'} ne 0 ) { 
	if ( param('max') || param('max') eq 0 ) {
		our $max = quotemeta(param('max'));
	} else {
		our $max = "";
	}
} else {
	our $max = quotemeta($query{'max'});
}
if ( !$query{'dbsettings'} ) { 
	if ( param('dbsettings') ) {
		our $dbsettings = quotemeta(param('dbsettings'));
	} else {
		our $dbsettings = "default";
	}
} else {
	our $dbsettings = quotemeta($query{'dbsettings'});
}
if ($dbsettings eq "custom") {
	our $checkeddbsettings2 = "checked=checked";
} else {
	our $checkeddbsettings1 = "checked=checked";
}
if ( !$query{'settings'} ) { 
	if ( param('settings') ) {
		our $settings = quotemeta(param('settings'));
	} else {
		our $settings = 1;
	}
} else {
	our $settings = quotemeta($query{'settings'});
}
if ( !$query{'step'} ) { 
	if ( param('step') ) {
		our $step = quotemeta(param('step'));
	} else {
		our $step = "";
	}
} else {
	our $step = quotemeta($query{'step'});
}
if ($step eq "60") {
	our $selectedstep1 = "selected=selected";
} elsif ($step eq "180") {
	our $selectedstep2 = "selected=selected";
} elsif ($step eq "300") {
	our $selectedstep3 = "selected=selected";
} elsif ($step eq "600") {
	our $selectedstep4 = "selected=selected";
} elsif ($step eq "900") {
	our $selectedstep5 = "selected=selected";
} elsif ($step eq "1800") {
	our $selectedstep6 = "selected=selected";
} elsif ($step eq "3600") {
	our $selectedstep7 = "selected=selected";
} elsif ($step eq "86400") {
	our $selectedstep8 = "selected=selected";
} else {
	our $selectedstep3 = "selected=selected";
}
if ( !$query{'start'} ) { 
	if ( param('start') ) {
		our $start = quotemeta(param('start'));
	} else {
		our $start = "";
	}
} else {
	our $start = quotemeta($query{'start'});
}
if ( !$query{'dsname'} ) { 
	if ( param('dsname') ) {
		our $dsname = quotemeta(param('dsname'));
	} else {
		our $dsname = 1;
	}
} else {
	our $dsname = quotemeta($query{'dsname'});
}
if ($dsname eq "GAUGE") {
	our $selecteddsname1 = "selected=selected";
} elsif ($dsname eq "COUNTER") {
	our $selecteddsname2 = "selected=selected";
} elsif ($dsname eq "DCOUNTER") {
	our $selecteddsname3 = "selected=selected";
} elsif ($dsname eq "DERIVE") {
	our $selecteddsname4 = "selected=selected";
} elsif ($dsname eq "DDERIVE") {
	our $selecteddsname5 = "selected=selected";
} elsif ($dsname eq "ABSOLUTE") {
	our $selecteddsname6 = "selected=selected";
} else {
	our $selecteddsname1 = "selected=selected";
}
if ( !$query{'heartbeat'} ) { 
	if ( param('heartbeat') ) {
		our $heartbeat = quotemeta(param('heartbeat'));
	} else {
		our $heartbeat = "";
	}
} else {
	our $heartbeat = quotemeta($query{'heartbeat'});
}
$i = 1;
while ($i <= $rracount) {
	if ( !$query{"cf$i"} ) { 
		if ( param("cf$i") ) {
			${cf.$i} = quotemeta(param("cf$i"));
		} else {
			${cf.$i} = "";
		}
	} else {
		${cf.$i} = quotemeta($query{"cf$i"});
	}
	if ( !$query{"xff$i"} ) { 
		if ( param("xff$i") ) {
			${xff.$i} = quotemeta(param("xff$i"));
		} else {
			${xff.$i} = "";
		}
	} else {
		${xff.$i} = quotemeta($query{"xff$i"});
	}
	if ( !$query{"step$i"} ) { 
		if ( param("step$i") ) {
			${step.$i} = quotemeta(param("step$i"));
		} else {
			${step.$i} = "";
		}
	} else {
		${step.$i} = quotemeta($query{"step$i"});
	}
	if ( !$query{"rows$i"} ) { 
		if ( param("rows$i") ) {
			${rows.$i} = quotemeta(param("rows$i"));
		} else {
			${rows.$i} = "";
		}
	} else {
		${rows.$i} = quotemeta($query{"rows$i"});
	}
	$i++;
}

# Clean up variables
$saveformdata =~ tr/0-1//cd;
$saveformdata = substr($saveformdata,0,1);
$script =~ tr/0-1//cd;
$script = substr($script,0,1);

# Init Language
# Clean up lang variable
$lang =~ tr/a-z//cd;
$lang = substr($lang,0,2);

# If there's no language phrases file for choosed language, use german as default
if (!-e "$installfolder/templates/plugins/$psubfolder/$lang/language.dat") {
	$lang = "de";
}

# Read translations / phrases
our $planguagefile = "$installfolder/templates/plugins/$psubfolder/$lang/language.dat";
our $pphrase = new Config::Simple($planguagefile);

##########################################################################
# Main program
##########################################################################

if ($saveformdata) {
  &save;

} else {
  &form;

}

exit;

#####################################################
# 
# Subroutines
#
#####################################################

#####################################################
# Form-Sub
#####################################################

sub form {

	# Prepare the form
	for ($i=1; $i<=$miniservercount; $i++) {
		$msselectmenu = $msselectmenu . "<option value='$i' ";
		if ($miniserver eq $i) {
			$msselectmenu = $msselectmenu . "selected=seleted ";
		}
		$msselectmenu = $msselectmenu . ">" . $cfg->param("MINISERVER$i.NAME") . "</option>\n";
	}

	open(F,"<$installfolder/config/plugins/$psubfolder/dbsettings.dat");
		@data = <F>;
		foreach (@data){
			s/[\n\r]//g;
			# Comments
			if ($_ =~ /^\s*#.*/) {
      				next;
    			}
    			@fields = split(/\|/);
			$settingsselectmenu = $settingsselectmenu . "<option value='@fields[0]' ";
			if ($settings eq @fields[0]) {
				$settingsselectmenu = $settingsselectmenu . "selected=seleted ";
			}
			$settingsselectmenu = $settingsselectmenu . ">" . @fields[1] . "</option>\n";
  		}
	close (F);

	# Print the template
	print "Content-Type: text/html\n\n";
	
	$template_title = $pphrase->param("TXT0000") . ": " . $pphrase->param("TXT0001");
	
	# Print Template
	&lbheader;
	open(F,"$installfolder/templates/plugins/$psubfolder/$lang/addstat_start.html") || die "Missing template plugins/$psubfolder/$lang/addstat_start.html";
	  while (<F>) 
	  {
	    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
	    print $_;
	  }
	close(F);
	open(F,"$installfolder/templates/plugins/$psubfolder/$lang/addstat_end.html") || die "Missing template plugins/$psubfolder/$lang/addstat_end.html";
	  while (<F>) 
	  {
	    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
	    print $_;
	  }
	close(F);
	&footer;
	exit;

}

#####################################################
# Save-Sub
#####################################################

sub save 
{

	# Check values
	if ( !$loxonename ) {
		$error = $pphrase->param("TXT0003");
		&error;
	}

	if ( !$description ) {
		$description = $loxonename;
	}
	if ( !$miniserver ) {
		$miniserver = "1";
	}

	my $miniserverip        = $cfg->param("MINISERVER$miniserver.IPADDRESS");
	my $miniserverport      = $cfg->param("MINISERVER$miniserver.PORT");
	my $miniserveradmin     = $cfg->param("MINISERVER$miniserver.ADMIN");
	my $miniserverpass      = $cfg->param("MINISERVER$miniserver.PASS");
	my $miniserverclouddns  = $cfg->param("MINISERVER$miniserver.USECLOUDDNS");
	my $miniservermac       = $cfg->param("MINISERVER$miniserver.CLOUDURL");

	# Use Cloud DNS?
	if ($miniserverclouddns) {
		$output = qx($home/bin/showclouddns.pl $miniservermac);
		@fields = split(/:/,$output);
		$miniserverip   =  @fields[0];
		$miniserverport = @fields[1];
	}

	# Test if Miniserver is reachable
	$loxonenameurlenc = uri_escape( unquotemeta($loxonename) );
	$url = "http://$miniserveradmin:$miniserverpass\@$miniserverip\:$miniserverport/dev/sps/io/$loxonenameurlenc/astate";

	$ua = LWP::UserAgent->new;
	$ua->timeout(1);
	local $SIG{ALRM} = sub { die };
	eval {
  	alarm(1);
  	our $response = $ua->get($url);
  	our $urlstatus = $response->status_line;
	our $rawxml = $response->decoded_content();
	};
	alarm(0);

	# Error if we don't get status 200
	my $urlstatuscode = substr($urlstatus,0,3);
	if ($urlstatuscode ne "200") {
			$error = $pphrase->param("TXT0013") . "<b> " . $urlstatuscode . "</b><br><br>" . $pphrase->param("TXT0014") . "<br><a href='" . $url . "' target='_blank'>$url</a>";
			&error;
	}

	# Error if status Code in XML is not 200
	our $xml = XMLin($rawxml, KeyAttr => { LL => 'Code' }, ForceArray => [ 'LL', 'Code' ]);
	our $xmlstatuscode = $xml->{Code};
	if ($xmlstatuscode ne "200") {
			$error = $pphrase->param("TXT0015") . "<b> " . $xmlstatuscode . "</b><br><br>" . $pphrase->param("TXT0014") . "<br><a href='" . $url . "' target='_blank'>$url</a>";
			&error;
	}

	if ( !$min && $min ne 0 ) {
		$min = "U";
	}
	if ( !$max && $max ne 0 ) {
		$max = "U";
	}
	if ($dbsettings eq "custom") {
		if (!$start) {
			$error = $pphrase->param("TXT0004");
			&error;
		}
		if (!$heartbeat) {
			$error = $pphrase->param("TXT0005");
			&error;
		}
		$i = 1;
		while ($i <= $rracount) {
			if (!${cf.$i}) {
				$error = $pphrase->param("TXT0006") . "($i. RRA).";
				&error;
			}
			if (!${xff.$i}) {
				$error = $pphrase->param("TXT0007") . "($i. RRA).";
				&error;
			}
			if (!${step.$i}) {
				$error = $pphrase->param("TXT0008") . "($i. RRA).";
				&error;
			}
			if (!${rows.$i}) {
				$error = $pphrase->param("TXT0009") . "($i. RRA).";
				&error;
			}
		$i++;
		}	
	}

	# Create Database
	open(F,"<$installfolder/config/plugins/$psubfolder/id.dat") or die "Cannot open id.dat: $!";
		our $lastid = <F>;
	close (F);

	$i = 0;
	until ($i == 1) {
		$lastid++;
		our $dbfilename = sprintf("%04d", $lastid);
		if (!-e "$installfolder/data/plugins/$psubfolder/databases/$dbfilename.rrd") {
			$i = 1;
			open(F,">$installfolder/config/plugins/$psubfolder/id.dat") or die "Cannot open id.dat: $!";
				print F $lastid;
			close (F);
		}
	}

	# For custom RRD creation
	if ($dbsettings eq "custom") {
		our $command = "$installfolder/data/plugins/$psubfolder/databases/$dbfilename.rrd --start $start --step $step DS:value:$dsname:$heartbeat:$min:$max ";
		$i = 1;
		while ($i <= $rracount) {
			$command = $command . "RRA:${cf.$i}:${xff.$i}:${step.$i}:${rows.$i} ";
			$i++;
		}

	# Standards - see suggestions from https://www.loxforum.com/forum/german/software-konfiguration-programm-und-visualisierung/61081-loxberry-statistik-plugin-diskussion?p=61470#post61470
	} else {
		our $command = "$installfolder/data/plugins/$psubfolder/databases/$dbfilename.rrd --start 1230768000 --step 300 DS:value:GAUGE:3900:$min:$max ";
		$command = $command . "RRA:AVERAGE:0.08:1:8928 ";
		$command = $command . "RRA:AVERAGE:0.08:3:8832 ";
		$command = $command . "RRA:AVERAGE:0.08:12:8760 ";
		$command = $command . "RRA:AVERAGE:0.08:288:7305 ";
		$command = $command . "RRA:MAX:0.08:1:8928 ";
		$command = $command . "RRA:MAX:0.08:3:8832 ";
		$command = $command . "RRA:MAX:0.08:12:8760 ";
		$command = $command . "RRA:MAX:0.08:288:7305 ";
		$command = $command . "RRA:MIN:0.08:1:8928 ";
		$command = $command . "RRA:MIN:0.08:3:8832 ";
		$command = $command . "RRA:MIN:0.08:12:8760 ";
		$command = $command . "RRA:MIN:0.08:288:7305 ";
	}

	$command = unquotemeta($command);
	$output = qx(/usr/bin/rrdtool create $command 2>&1);
	if ( $? > 0 || !-e "$installfolder/data/plugins/$psubfolder/databases/$dbfilename.rrd" ) {
		$error = $pphrase->param("TXT0010") . " " . $pphrase->param("TXT0011") . "<br><br><pre>" . $output . "</pre><br><br>" . $pphrase->param("TXT0012") . "<br><br><pre>" . "/usr/bin/rrdtool create " . $command . "</pre>";
		&error;
	}

	# Register new database
	open(F,">>$installfolder/config/plugins/$psubfolder/databases.dat") || die "Cannot open database for RRD-databases.";
		binmode F, ':encoding(UTF-8)';
		$description = Encode::decode( "UTF-8", unquotemeta($description) );
		$loxonename = Encode::decode( "UTF-8", unquotemeta($loxonename) );
		print F "$dbfilename|$step|$description|$loxonename|$miniserver|$min|$max|1\n";
	close(F);

	# Create info file
	open(F,">$installfolder/data/plugins/$psubfolder/databases/$dbfilename.info") || die "Cannot open info file for RRD-database.";
	print F "/usr/bin/rrdtool create $command 2>&1\n\n";
	$output = qx(/usr/bin/rrdinfo $installfolder/data/plugins/$psubfolder/databases/$dbfilename.rrd 2>&1);
	print F $output;
	close(F);

	# Print template
	if (!$script) {
		$template_title = $pphrase->param("TXT0000") . " - " . $pphrase->param("TXT0001");
		$message = $pphrase->param("TXT0002");
		$nexturl = "./index.cgi?do=form";

		print "Content-Type: text/html\n\n"; 
		&lbheader;
		open(F,"$installfolder/templates/system/$lang/success.html") || die "Missing template system/$lang/success.html";
		while (<F>) 
		{
			$_ =~ s/<!--\$(.*?)-->/${$1}/g;
			print $_;
		}
		close(F);
		&footer;
	} else {
		print "Content-Type: text/plain\n\n"; 
		print "+++OK+++".$pphrase->param("TXT0002");
	}
	exit;
		
}

#####################################################
# Error-Sub
#####################################################

sub error 
{
	if (!$script) {
		$template_title = $pphrase->param("TXT0000") . " - " . $pphrase->param("TXT0001");
		print "Content-Type: text/html\n\n"; 
		&lbheader;
		open(F,"$installfolder/templates/system/$lang/error.html") || die "Missing template system/$lang/error.html";
		while (<F>) 
		{
			$_ =~ s/<!--\$(.*?)-->/${$1}/g;
			print $_;
		}
		close(F);
		&footer;
	} else {
		print "Content-Type: text/plain\n\n"; 
		print "+++ERROR+++".$error;
	}
	exit;
}

#####################################################
# Page-Header-Sub
#####################################################

	sub lbheader 
	{
	  # Create Help page
	  our $helplink = "http://www.loxwiki.eu:80/x/uYCm";
	  open(F,"$installfolder/templates/plugins/$psubfolder/$lang/help.html") || die "Missing template plugins/$psubfolder/$lang/help.html";
	    my @help = <F>;
 	    our $helptext;
	    foreach (@help)
	    {
	      s/[\n\r]/ /g;
	      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
	      $helptext = $helptext . $_;
	    }
	  close(F);
	  open(F,"$installfolder/templates/system/$lang/header.html") || die "Missing template system/$lang/header.html";
	    while (<F>) 
	    {
	      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
	      print $_;
	    }
	  close(F);
	}

#####################################################
# Footer
#####################################################

	sub footer 
	{
	  open(F,"$installfolder/templates/system/$lang/footer.html") || die "Missing template system/$lang/footer.html";
	    while (<F>) 
	    {
	      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
	      print $_;
	    }
	  close(F);
	}
