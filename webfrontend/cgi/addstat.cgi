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
use CGI::Session;
use Getopt::Long;
#use warnings;
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
$version = "0.0.9";

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

# Get command line options - this also sets the variables to it's default value "" or 0!
our $load = 0;
our $save = 0;
our $script = 0;
our $settings = "";
our $sid = "";
our $lang = "de";
our $rracount = 1;
our $loxonename = "";
our $miniserver = 1;
our $description = "";
our $min = "";
our $max = "";
our $dbsettings = "default";
our $step = "300";
our $start = "";
our $dsname = "";
our $heartbeat = "";
our $savedbsettings = 0;
our $savedbsettingsname = "";
our $commandline = 0;
our $place = "";
our $placenew = "";
our $category = "";
our $categorynew = "";
our $uid = "";
our $unit = "";
our $block = "";

# Test for commandline options
GetOptions (	"script" 		=> \$script, # Use this to figure out if we were called from command line
		"save"			=> \$query{'save'},
		"load"			=> \$query{'load'},
		"settings=i"		=> \$query{'settings'},		
		"sid=s"			=> \$query{'sid'},		
		"lang=s"		=> \$query{'lang'},		
		"rracount=i"		=> \$query{'rracount'},		
		"loxonename=s"		=> \$query{'loxonename'},		
		"miniserver=i"		=> \$query{'miniserver'},		
		"description=s"		=> \$query{'description'},		
		"min=s"			=> \$query{'min'},		
		"max=s"			=> \$query{'max'},		
		"dbsettings=s"		=> \$query{'dbsettings'},		
		"step=i"		=> \$query{'step'},		
		"start=s"		=> \$query{'start'},		
		"dsname=s"		=> \$query{'dsname'},		
		"heartbeat=s"		=> \$query{'heartbeat'},		
		"savedbsettings"	=> \$query{'savedbsettings'},		
		"savedbsettingsname=s"	=> \$query{'savedbsettingsname'},
		"place=s"		=> \$query{'place'},
		"category=s"		=> \$query{'category'},
		"uid=s"			=> \$query{'uid'},
		"unit=s"		=> \$query{'unit'},
		"block=s"		=> \$query{'block'},
);

# Check if we were called from command line.
if ( $script ) {
	$query{'script'} = $script;
	our $commandline = 1;
}

# Set parameters coming in - get over post - First group needed if we should read settings from db
if ( !$query{'script'} ) { 
	if ( param('script') ) { 
		$script = quotemeta(param('script')); 
	} 
} else { 
	$script = quotemeta($query{'script'}); 
}
if ( !$query{'save'} ) { 
	if ( param('save') ) { 
		$save = quotemeta(param('save')); 
	} 
} else { 
	$save = quotemeta($query{'save'}); 
}
if ( !$query{'load'} ) { 
	if ( param('load') ) { 
		$load = quotemeta(param('load')); 
	} 
} else { 
	$load = quotemeta($query{'load'}); 
}
if ( !$query{'settings'} ) { 
	if ( param('settings') ) {
		$settings = quotemeta(param('settings'));
	}
} else {
	$settings = quotemeta($query{'settings'});
}
if ( !$query{'sid'} ) { 
	if ( param('sid') ) {
		$sid = quotemeta(param('sid'));
	}
} else {
	$sid = quotemeta($query{'sid'});
}
if ( !$query{'lang'} ) {
	if ( param('lang') ) {
		$lang = quotemeta(param('lang'));
	}
} else {
	$lang = quotemeta($query{'lang'}); 
}
$script =~ tr/0-1//cd;
$script = substr($script,0,1);
$load =~ tr/0-1//cd;
$load = substr($load,0,1);
$save =~ tr/0-1//cd;
$save = substr($save,0,1);

# Init Language
# Clean up lang variable
$lang =~ tr/a-z//cd;
$lang = substr($lang,0,2);

# Create new Session if none exists, else use existing one
if (!$sid) {
  $session = new CGI::Session("driver:File", undef, {Directory=>"$installfolder/webfrontend/sessioncache"});
  $sid = $session->id();
} else {
  $session = new CGI::Session("driver:File", $sid, {Directory=>"$installfolder/webfrontend/sessioncache"});
  $sid = $session->id();
}

# Sessions are valid for 24 hour
$session->expire('+24h');    # expire after 24 hour

# Load settings from database if needed
if ( ($load || $script) && $settings > 1 ) {
	# Read values from dbsettings database
	open(F,"<$installfolder/config/plugins/$psubfolder/dbsettings.dat");
	@data = <F>;
	my $found = 0;
	foreach (@data){
		s/[\n\r]//g;
		# Comments
		if ($_ =~ /^\s*#.*/) {
      			next;
    		}
    		@fields = split(/\|/);
		if (@fields[0] eq $settings) {
			$found = 1;
			$query{'dbsettings'} = "custom";
			$query{'start'} = @fields[2];
			$query{'step'} = @fields[3];
			$query{'dsname'} = @fields[4];
			$query{'heartbeat'} = @fields[5];
			$query{'min'} = @fields[6];
			$query{'max'} = @fields[7];
			$query{'rracount'} = @fields[8];
			$i = 1;
			while ($i <= $query{'rracount'}) {
				my $field = 9 + ( ($i-1) * 4);
				$query{"cf$i"} = @fields[$field];
				$field++;
				$query{"xff$i"} = @fields[$field];
				$field++;
				$query{"step$i"} = @fields[$field];
				$field++;
				$query{"rows$i"} = @fields[$field];
				$i++;
			}
		}
  	}
	close (F);
	# Use default values if we cannot found settings
	if (!found) {
		$query{'dbsettings'} = "default";
		$query{'settings'} = "1";
		$settings = 1;
	}
}

# Set parameters coming in - get over post - Second group
if ( !$query{'rracount'} ) { 
	if ( param('rracount') ) {
		$rracount = quotemeta(param('rracount'));
	} else {
		if ( $session->param('rracount') && !$load ) {
			$rracount = quotemeta($session->param('rracount'));
		}
	}
} else {
	our $rracount = quotemeta($query{'rracount'});
}
if ( !$query{'loxonename'} ) { 
	if ( param('loxonename') ) {
		$loxonename = quotemeta(param('loxonename'));
	} else {
		if ( $session->param('loxonename') && !$load ) {
			$loxonename = $session->param('loxonename');
		}
	}
} else {
	$loxonename = quotemeta($query{'loxonename'});
}
if ( !$query{'miniserver'} ) { 
	if ( param('miniserver') ) {
		$miniserver = quotemeta(param('miniserver'));
	} else {
		if ( $session->param('miniserver') && !$load ) {
			$miniserver = quotemeta($session->param('miniserver'));
		}
	}
} else {
	$miniserver = quotemeta($query{'miniserver'});
}
if ( !$query{'description'} ) { 
	if ( param('description') ) {
		$description = quotemeta(param('description'));
	} else {
		if ( $session->param('description') && !$load ) {
			$description = $session->param('description');
		}
	}
} else {
	$description = quotemeta($query{'description'});
}
if ( !$query{'min'} && $query{'min'} ne 0 ) { 
	if ( param('min') || param('min') eq 0 ) {
		$min = quotemeta(param('min'));
	} else {
		if ( $session->param('min') && !$load ) {
			$min = $session->param('min');
		}
	}
} else {
	$min = quotemeta($query{'min'});
}
if ( !$query{'max'} && $query{'max'} ne 0 ) { 
	if ( param('max') || param('max') eq 0 ) {
		$max = quotemeta(param('max'));
	} else {
		if ( $session->param('max') && !$load ) {
			$max = $session->param('max');
		}
	}
} else {
	$max = quotemeta($query{'max'});
}
if ( !$query{'dbsettings'} ) { 
	if ( param('dbsettings') ) {
		$dbsettings = quotemeta(param('dbsettings'));
	} else {
		if ( $session->param('dbsettings') && !$load ) {
			$dbsettings = quotemeta($session->param('dbsettings'));
		}
	}
} else {
	$dbsettings = quotemeta($query{'dbsettings'});
}
if ($dbsettings eq "custom") {
	our $checkeddbsettings2 = "checked=checked";
} else {
	our $checkeddbsettings1 = "checked=checked";
}
if ( !$query{'step'} ) { 
	if ( param('step') ) {
		$step = quotemeta(param('step'));
	} else {
		if ( $session->param('step') && !$load ) {
			$step = quotemeta($session->param('step'));
		}
	}
} else {
	$step = quotemeta($query{'step'});
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
		$start = quotemeta(param('start'));
	} else {
		if ( $session->param('start') && !$load ) {
			$start = $session->param('start');
		}
	}
} else {
	$start = quotemeta($query{'start'});
}
if ( !$query{'dsname'} ) { 
	if ( param('dsname') ) {
		$dsname = quotemeta(param('dsname'));
	} else {
		if ( $session->param('dsname') && !$load ) {
			$dsname = quotemeta($session->param('dsname'));
		}
	}
} else {
	$dsname = quotemeta($query{'dsname'});
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
		$heartbeat = quotemeta(param('heartbeat'));
	} else {
		if ( $session->param('heartbeat') && !$load ) {
			$heartbeat = $session->param('heartbeat');
		}
	}
} else {
	$heartbeat = quotemeta($query{'heartbeat'});
}
$i = 1;
while ($i <= $rracount) {
	if ( !$query{"cf$i"} ) { 
		if ( param("cf$i") ) {
			${cf.$i} = quotemeta(param("cf$i"));
		} else {
			if ( $session->param("cf$i") && !$load ) {
				${cf.$i} = quotemeta($session->param("cf$i"));
			} else {
				${cf.$i} = "";
			}
		}
	} else {
		${cf.$i} = quotemeta($query{"cf$i"});
	}
	if (${cf.$i} eq "AVERAGE") {
		${selectedcf.$i.1} = "selected=selected";
	} elsif (${cf.$i} eq "MIN") {
		${selectedcf.$i.2} = "selected=selected";
	} elsif (${cf.$i} eq "MAX") {
		${selectedcf.$i.3} = "selected=selected";
	} elsif (${cf.$i} eq "LAST") {
		${selectedcf.$i.4} = "selected=selected";
	} else {
		${selectedcf.$i.1} = "selected=selected";
	}
	if ( !$query{"xff$i"} ) { 
		if ( param("xff$i") ) {
			${xff.$i} = quotemeta(param("xff$i"));
		} else {
			if ( $session->param("xff$i") && !$load ) {
				${xff.$i} = $session->param("xff$i");
			} else {
				${xff.$i} = "";
			}
		}
	} else {
		${xff.$i} = quotemeta($query{"xff$i"});
	}
	if ( !$query{"step$i"} ) { 
		if ( param("step$i") ) {
			${step.$i} = quotemeta(param("step$i"));
		} else {
			if ( $session->param("step$i") && !$load ) {
				${step.$i} = $session->param("step$i");
			} else {
				${step.$i} = "";
			}
		}
	} else {
		${step.$i} = quotemeta($query{"step$i"});
	}
	if ( !$query{"rows$i"} ) { 
		if ( param("rows$i") ) {
			${rows.$i} = quotemeta(param("rows$i"));
		} else {
			if ( $session->param("rows$i") && !$load ) {
				${rows.$i} = $session->param("rows$i");
			} else {
				${rows.$i} = "";
			}
		}
	} else {
		${rows.$i} = quotemeta($query{"rows$i"});
	}
	$i++;
}
if ( !$query{'savedbsettings'} ) {
        if ( param('savedbsettings') ) {
		$savedbsettings = quotemeta(param('savedbsettings'));
        } else {
		if ( $session->param('savedbsettings') && !$load ) {
			$savedbsettings = quotemeta($session->param('savedbsettings'));
		}
        }
} else {
	$savedbsettings = quotemeta($query{'savedbsettings'});
}
if ( $savedbsettings ) {
	$checkedsavedbsettings = "checked=checked";
}
if ( !$query{'savedbsettingsname'} ) {
        if ( param('savedbsettingsname') ) {
		$savedbsettingsname = quotemeta(param('savedbsettingsname'));
        } else {
		if ( $session->param('savedbsettingsname') && !$load ) {
			$savedbsettingsname = $session->param('savedbsettingsname');
		}
        }
} else {
	$savedbsettingsname = quotemeta($query{'savedbsettingsname'});
}
if ( !$query{'place'} ) { 
	if ( param('place') ) {
		$place = quotemeta(param('place'));
	} else {
		if ( $session->param('place') && !$load ) {
			$place = $session->param('place');
		}
	}
} else {
	$place = quotemeta($query{'place'});
}
if ( !$query{'placenew'} ) { 
	if ( param('placenew') ) {
		$placenew = quotemeta(param('placenew'));
	} else {
		if ( $session->param('placenew') && !$load ) {
			$placenew = $session->param('placenew');
		}
	}
} else {
	$placenew = quotemeta($query{'placenew'});
}
if ( !$query{'category'} ) { 
	if ( param('ctegory') ) {
		$category = quotemeta(param('category'));
	} else {
		if ( $session->param('category') && !$load ) {
			$category = $session->param('category');
		}
	}
} else {
	$category = quotemeta($query{'category'});
}
if ( !$query{'categorynew'} ) { 
	if ( param('ctegory') ) {
		$categorynew = quotemeta(param('categorynew'));
	} else {
		if ( $session->param('categorynew') && !$load ) {
			$categorynew = $session->param('categorynew');
		}
	}
} else {
	$categorynew = quotemeta($query{'categorynew'});
}
if ( !$query{'uid'} ) { 
	if ( param('uid') ) {
		$uid = quotemeta(param('uid'));
	} else {
		if ( $session->param('uid') && !$load ) {
			$uid = $session->param('uid');
		}
	}
} else {
	$uid = quotemeta($query{'uid'});
}
if ( !$query{'unit'} ) { 
	if ( param('unit') ) {
		$unit = quotemeta(param('unit'));
	} else {
		if ( $session->param('unit') && !$load ) {
			$unit = $session->param('unit');
		}
	}
} else {
	$unit = quotemeta($query{'unit'});
}
if ( !$query{'block'} ) { 
	if ( param('block') ) {
		$block = quotemeta(param('block'));
	} else {
		if ( $session->param('block') && !$load ) {
			$block = $session->param('block');
		}
	}
} else {
	$block = quotemeta($query{'block'});
}

# Filter
$savedbsettings =~ tr/0-1//cd;
$savedbsettings = substr($savedbsettings,0,1);

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

if ($save || $script) {
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
	
	# Unquote everything for the form
        # Don't know why, but unquotemeta does not work here?!? Use the "Hard way" with  =~ s/\\//g;
	$loxonename =~ s/\\//g;
	$description =~ s/\\//g;
	$miniserver =~ s/\\//g;
	$min =~ s/\\//g;
	$max =~ s/\\//g;
	$dbsettings =~ s/\\//g;
	$settings =~ s/\\//g;
	$step =~ s/\\//g;
	$start =~ s/\\//g;
	$dsname =~ s/\\//g;
	$heartbeat =~ s/\\//g;
	$i = 1;
	while ($i <= $rracount) {
		${cf.$i} =~ s/\\//g;
		${xff.$i} =~ s/\\//g;
		${step.$i} =~ s/\\//g;
		${rows.$i} =~ s/\\//g;
		$i++;
	}

	# Print Template
	&lbheader;
	open(F,"$installfolder/templates/plugins/$psubfolder/$lang/addstat_start.html") || die "Missing template plugins/$psubfolder/$lang/addstat_start.html";
	  while (<F>) 
	  {
	    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
	    print $_;
	  }
	close(F);

	if ($rracount > 1) {
		$i = 2;
		our $cfx;
		our $xffx;
		our $stepx;
		our $rowsx;
		while ($i <= $rracount) {
			$selectedcfx1 = ${selectedcf.$i.1};
			$selectedcfx2 = ${selectedcf.$i.2};
			$selectedcfx3 = ${selectedcf.$i.3};
			$selectedcfx4 = ${selectedcf.$i.4};
			$cfx = ${cf.$i};
			$xffx = ${xff.$i};
			$stepx = ${step.$i};
			$rowsx = ${rows.$i};
			open(F,"$installfolder/templates/plugins/$psubfolder/$lang/addstat_row.html") || die "Missing template plugins/$psubfolder/$lang/addstat_row.html";
	  		while (<F>) 
	  		{
	    			$_ =~ s/<!--\$(.*?)-->/${$1}/g;
	    			print $_;
	  		}
			close(F);
		$i++;
		}

	}

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

	# Take me back here in case of an error
	our $backurl = "./addstat.cgi?sid=$sid";

	# Save CGI session
	$session->save_param($cgi);

	# Check values
	if ( !$loxonename ) {
		$error = $pphrase->param("TXT0003");
		&error;
	}

	if ( !$description ) {
		$description = $loxonename;
	}

	if ($savedbsettings && !$savedbsettingsname) {
		(my $sec,my $min,my $hour,my $mday,my $mon,my $year,my $wday,my $yday,my $isdst) = localtime();
		$year = $year+1900;
		$mon = $mon+1;
		$mon = sprintf("%02d", $mon);
		$mday = sprintf("%02d", $mday);
		$hour = sprintf("%02d", $hour);
		$min = sprintf("%02d", $min);
		$sec = sprintf("%02d", $sec);
		$savedbsettingsname = "Settings from $year$mon$mday-$hour$min$sec";
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

	# Test if Miniserver is reachable - Try 5 times before giving up
	$loxonenameurlenc = uri_escape( unquotemeta($loxonename) );
	$url = "http://$miniserveradmin:$miniserverpass\@$miniserverip\:$miniserverport/dev/sps/io/$loxonenameurlenc/all";

	our $found = 0;
	our $i = 0;

        while (!$found || $i < 5) {
		$ua = LWP::UserAgent->new;
		$ua->timeout(5);
		local $SIG{ALRM} = sub { die };
		eval {
  		alarm(5);
  		our $response = $ua->get($url);
  		our $urlstatus = $response->status_line;
		our $rawxml = $response->decoded_content();
		};
		alarm(0);

		# Error if we don't get status 200
		my $urlstatuscode = substr($urlstatus,0,3);
		if ($urlstatuscode ne "200") {
			$error = $pphrase->param("TXT0013") . "<b> " . $urlstatuscode . "</b><br><br>" . $pphrase->param("TXT0014") . "<br><a href='" . $url . "' target='_blank'>$url</a>";
			$i++;
			next;	
		}

		# Error if status Code in XML is not 200
		our $xml = XMLin($rawxml, KeyAttr => { LL => 'Code' }, ForceArray => [ 'LL', 'Code' ]);
		our $xmlstatuscode = $xml->{Code};
		if ($xmlstatuscode ne "200") {
			$error = $pphrase->param("TXT0015") . "<b> " . $xmlstatuscode . "</b><br><br>" . $pphrase->param("TXT0014") . "<br><a href='" . $url . "' target='_blank'>$url</a>";
			$i++;
			next;	
		} else {
			$found = 1;
			# Filter units
			if ( !$unit ) {
				$unit = $xml->{value};
				$unit =~ s/^([\d\.\ ]+)(.*)/$2/g;
			}
		}
		$i++;
	}

	# If we could not reach the Miniserver
	if ( !$found ) {
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
	open(F,"<$installfolder/config/plugins/$psubfolder/id_databases.dat") or die "Cannot open id_databases.dat: $!";
		our $lastid = <F>;
	close (F);

	$i = 0;
	until ($i == 1) {
		$lastid++;
		our $dbfilename = sprintf("%04d", $lastid);
		if (!-e "$installfolder/data/plugins/$psubfolder/databases/$dbfilename.rrd") {
			$i = 1;
			open(F,">$installfolder/config/plugins/$psubfolder/id_databases.dat") or die "Cannot open id_databases.dat: $!";
				flock(F, 2);
				print F $lastid;
			close (F);
		}
	}

	# For custom RRD creation
	if ($dbsettings eq "custom") {
		our $command = "$installfolder/data/plugins/$psubfolder/databases/$dbfilename.rrd --start $start --step $step DS:value:$dsname:$heartbeat:$min:$max ";
		if ($savedbsettings) {
			our $linesavedbsettings = "$savedbsettingsname|$start|$step|$dsname|$heartbeat|$min|$max|$rracount|";
		}
		$i = 1;
		while ($i <= $rracount) {
			$command = $command . "RRA:${cf.$i}:${xff.$i}:${step.$i}:${rows.$i} ";
			if ($savedbsettings) {
				$linesavedbsettings = $linesavedbsettings . "${cf.$i}|${xff.$i}|${step.$i}|${rows.$i}|";
			}
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
		$error = $pphrase->param("TXT0010") . " " . $pphrase->param("TXT0011") . "<br><br><textarea name='textarea1' id='textarea1' readonly>" . $output . "</textarea><br><br>" . $pphrase->param("TXT0012") . "<br><br><textarea name='textarea2' id='textarea2' readonly>" . "/usr/bin/rrdtool create " . $command . "</textarea>";
		&error;
	}

	# Register new database
	open(F,">>$installfolder/config/plugins/$psubfolder/databases.dat") || die "Cannot open database for RRD-databases.";
		flock(F, 2);
		binmode F, ':encoding(UTF-8)';
		$description = Encode::decode( "UTF-8", unquotemeta($description) );
		$loxonename = Encode::decode( "UTF-8", unquotemeta($loxonename) );
		$place = unquotemeta($place);
		$category = unquotemeta($category);
		$uid = unquotemeta($uid);
		$unit = unquotemeta($unit);
		$block = unquotemeta($block);
		print F "$dbfilename|$step|$description|$loxonename|$miniserver|$min|$max|$place|$category|$uid|$unit|$block\n";
	close(F);

	# Create status file
	open(F,">$installfolder/data/plugins/$psubfolder/databases/$dbfilename.status") || die "Cannot open status file for RRD-database.";
	flock(F, 2);
	print F "1";
	close(F);

	# Create info file
	open(F,">$installfolder/data/plugins/$psubfolder/databases/$dbfilename.info") || die "Cannot open info file for RRD-database.";
	flock(F, 2);
	print F "http://USERNAME:PASSWORD\@$miniserverip:$miniserverport/dev/sps/io/$loxonenameurlenc/astate\n\n";
	print F "/usr/bin/rrdtool create $command 2>&1\n\n";
	$output = qx(/usr/bin/rrdinfo $installfolder/data/plugins/$psubfolder/databases/$dbfilename.rrd 2>&1);
	print F $output;
	close(F);

	# Save DBSettings
	if ($savedbsettings) {
		$i = 0;
		open(F,"+<$installfolder/config/plugins/$psubfolder/dbsettings.dat") || die "Cannot open database for DB-Settings.";
		flock(F, 2);
		binmode F, ':encoding(UTF-8)';
		@data = <F>;
		seek(F,0,0);
		truncate(F,0);
		foreach (@data){
  			s/[\n\r]//g;
  			# Comments
  			if ($_ =~ /^\s*#.*/) {
    				print F "$_\n";
    				next;
  			}
    			print F "$_\n";
			$i++;
  		}
		$i++;
		$linesavedbsettings = Encode::decode( "UTF-8", unquotemeta($linesavedbsettings) );
		print F "$i|$linesavedbsettings\n";
		close (F);
	}

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
		if ( !$commandline ) {
			print "Content-Type: text/plain\n\n"; 
		}
		print "+++OK+++".$pphrase->param("TXT0002")."+++$dbfilename\n";
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
		open(F,"$installfolder/templates/plugins/$psubfolder/$lang/error.html") || die "Missing template templates/plugins/$psubfolder/$lang/error.html";
		while (<F>) 
		{
			$_ =~ s/<!--\$(.*?)-->/${$1}/g;
			print $_;
		}
		close(F);
		&footer;
	} else {
		if ( !$commandline ) {
			print "Content-Type: text/plain\n\n"; 
		}
		print "+++ERROR+++".$error."\n";
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
