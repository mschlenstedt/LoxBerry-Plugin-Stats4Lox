#!/usr/bin/perl

# Copyright 2016 Christian Fenzl, christiantf@gmx.at
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

use CGI;
use CGI::Carp qw(fatalsToBrowser);
# use CGI qw/:standard/;
use LWP::UserAgent;
use String::Escape qw( unquotemeta );
use Config::Simple;
use File::HomeDir;
use Cwd 'abs_path';
use URI::Escape;
use XML::Simple qw(:strict);
use warnings;

# Christian Import
use XML::LibXML;
use File::stat;
use File::Basename;
use Time::localtime;
# Debug
use Time::HiRes qw/ time sleep /;

# Set maximum file upload to approx. 7 MB
$CGI::POST_MAX = 1024 * 7000;



#use strict;
#no strict "refs"; # we need it for template system
our $namef;
our $value;
our @query;
our @fields;
our @lines;
my $home = File::HomeDir->my_home;
our %cfg_mslist;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.1.1";

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

# Generate MS table with IP as key
for (my $msnr = 1; $msnr <= $miniservercount; $msnr++) {
	$cfg_mslist{$cfg->param("MINISERVER$msnr.IPADDRESS")} = $msnr;
}

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

# Clean up saveformdata variable
$saveformdata =~ tr/0-1//cd;
$saveformdata = substr($saveformdata,0,1);

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

# Default file for reading and writing LoxPLAN file
our $loxconfig_path = "$installfolder/data/plugins/$psubfolder/upload.loxplan";

##########################################################################
# Main program
##########################################################################

if ($Upload) {
	saveloxplan();
	form();
} elsif ($saveformdata) {
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
	
	# Check if a .LoxPLAN is already available
	
	
	if ( -e $loxconfig_path ) {
		my $loxplan_modified = ctime(stat($loxconfig_path)->mtime);
		readloxplan();
		my $upload_message = "Die aktuell hochgeladene Loxone-Konfiguration ist von $loxplan_modified. Du kannst eine neuere Version hochladen, oder diese verwenden.";
	} else {
		my $upload_message = "Lade deine Loxone Konfiguration hoch. Daraus wird ausgelesen, welche Statistiken du aktuell aktiviert hast.";
	}

	generate_import_table();
	
	
	
	# Print the template
	print "Content-Type: text/html\n\n";
	
	$template_title = $pphrase->param("TXT0000") . ": " . $pphrase->param("TXT0001");
	
	# Print Upload Template
	&lbheader;
	open(F,"$installfolder/templates/plugins/$psubfolder/multi/loxplan_uploadform.html") || die "Missing template plugins/$psubfolder/multi/loxplan_uploadform.html";
	  while (<F>) 
	  {
	    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
	    print $_;
	  }
	close(F);

	open(F,"$installfolder/templates/plugins/$psubfolder/multi/import_selection.html") || die "Missing template plugins/$psubfolder/multi/loxplan_uploadform.html";
	  while (<F>) 
	  {
	    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
	    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
	    print $_;
	  }
	close(F);
	
	
	
	#	open(F,"$installfolder/templates/plugins/$psubfolder/$lang/addstat_end.html") || die "Missing template plugins/$psubfolder/$lang/addstat_end.html";
#	  while (<F>) 
#	  {
#	    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
#	    print $_;
#	  }
#	close(F);
	&footer;
	exit;

}

#####################################################
# Save-Sub
#####################################################

sub save 
{

	# Check values

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

	# Print template
	$template_title = $pphrase->param("TXT0000") . " - " . $pphrase->param("TXT0001");
	$message = $pphrase->param("TXT0002");
	$nexturl = "./import.cgi?do=form";

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
	exit;
		
}

#####################################################
# Save Loxplan file
#####################################################

sub saveloxplan
{
	my $filename = $query->param("loxplan-file");
	
	if ( !$filename ) {
		exit;
	}
	
	my $upload_filehandle = $query->upload("loxplan-file");
	open ( UPLOADFILE, ">$loxconfig_path" ) or die "$!";
	binmode UPLOADFILE;

	while ( <$upload_filehandle> ) {
		print UPLOADFILE;
	}
	close UPLOADFILE;
}

#####################################################
# Generate HTML Import Table
#####################################################

sub generate_import_table 
{

foreach my $statsobj (keys %lox_statsobject) {
	
	our htmlout = '
		  <tr>
			<td class="tg-yw4l">' + $statsobj{Title} + '</td>
			<td class="tg-yw4l">' + $statsobj{Desc} + '</td>
			<td class="tg-yw4l">' + $statsobj{Place} + 'Zentral</td>
			<td class="tg-yw4l">' + $statsobj{Category} + '</td>
			<td class="tg-yw4l">' + $statsobj{StatsType} + '</td>
			<td class="tg-yw4l">' + $statsobj{MinVal} + '</td>
			<td class="tg-yw4l">' + $statsobj{MaxVal} + '</td>
			<td class="tg-yw4l">Import-Dropdown1</td>
			<td class="tg-yw4l">Import-Checkbox1</td>
		  </tr>
		';

	}
}


#####################################################
# Read LoxPLAN XML
#####################################################

sub readloxplan
{

	our @loxconfig_xml;
	our %StatTypes;
	our %lox_miniserver;
	our %lox_category;
	our %lox_room;
	our %lox_statsobject;
	

	%StatTypes = ( 	1, "Jede Änderung (max. ein Wert pro Minute)",
					2, "Mittelwert pro Minute",
					3, "Mittelwert pro 5 Minuten",
					4, "Mittelwert pro 10 Minuten",
					5, "Mittelwert pro 30 Minuten",
					6, "Mittelwert pro Stunde",
					7, "Digital/Jede Änderung");

	my $start_run = time();

	# For performance, it would be possibly better to switch from XML::LibXML to XML::Twig

	# Prepare data from LoxPLAN file
	my $parser = XML::LibXML->new();
	my $lox_xml = $parser->parse_file($loxconfig_path);

	# Read Loxone Miniservers
	foreach my $miniserver ($lox_xml->findnodes('//C[@Type="LoxLIVE"]')) {
		# Use an multidimensional associative hash to save a table of necessary MS data
		# key is the Uid
		$lox_miniserver{$miniserver->{U}}{Title} = $miniserver->{Title};
		$lox_miniserver{$miniserver->{U}}{IP} = $miniserver->{IntAddr};
		$lox_miniserver{$miniserver->{U}}{Serial} = $miniserver->{Serial};
		# In a later stage, we have to query the LoxBerry MS Database by IP to get LoxBerrys MS-ID.
	}

	# Read Loxone categories
	foreach my $category ($lox_xml->findnodes('//C[@Type="Category"]')) {
		# Key is the Uid
		$lox_category{$category->{U}} = $category->{Title};
	}
	# print "Test Perl associative array: ", $lox_category{"0b2c7aea-007c-0002-0d00000000000000"}, "\r\n";

	# Read Loxone rooms
	foreach my $room ($lox_xml->findnodes('//C[@Type="Place"]')) {
		# Key is the Uid
		$lox_room{$room->{U}} = $room->{Title};
	}

	# Get all objects that have statistics enabled
	foreach my $object ($lox_xml->findnodes('//C[@StatsType]')) {
		# Get Miniserver of this object
		# Nodes with statistics may be a child or sub-child of LoxLive type, or alternatively Ref-er to the LoxLive node. 
		# Therefore, we have to distinguish between connected in some parent, or referred by in some parent.	
		my $ms_ref;
		my $parent = $object;
		do {
			$parent = $parent->parentNode;
		} while ((!$parent->{Ref}) && ($parent->{Type} ne "LoxLIVE"));
		if ($parent->{Type} eq "LoxLIVE") {
			$ms_ref = $parent->{U};
		} else {
			$ms_ref = $parent->{Ref};
		}
		# print "Objekt: ", $object->{Title}, " (StatsType = ", $object->{StatsType}, ") | Miniserver: ", $lox_miniserver{$ms_ref}{Title}, "\r\n";
		$lox_statsobject{$object->{U}}{Title} = $object->{Title};
		$lox_statsobject{$object->{U}}{Desc} = $object->{Desc};
		$lox_statsobject{$object->{U}}{StatsType} = $object->{StatsType};
		$lox_statsobject{$object->{U}}{Type} = $object->{Type};
		$lox_statsobject{$object->{U}}{MSName} = $lox_miniserver{$ms_ref}{Title};
		$lox_statsobject{$object->{U}}{MSIP} = $lox_miniserver{$ms_ref}{IP};
		$lox_statsobject{$object->{U}}{MSNr} = $cfg_mslist{$lox_miniserver{$ms_ref}{IP}};
		# Place and Category needs to be checked if set and resolved 
		$lox_statsobject{$object->{U}}{Category} = $object->getChildrenByLocalName("IoData")[0]{Cr};
		$lox_statsobject{$object->{U}}{Place} = $object->getChildrenByLocalName("IoData")[0]{Pr};
		
		if ($object->{Analog} ne "true") {
			$lox_statsobject{$object->{U}}{MinVal} = 0;
			$lox_statsobject{$object->{U}}{MaxVal} = 1;
		} else {
			if ($object->{MinVal}) { 
				$lox_statsobject{$object->{U}}{MinVal} = $object->{MinVal};
			} else {
				$lox_statsobject{$object->{U}}{MinVal} = "U";
			}
			if ($object->{MaxVal}) { 
				$lox_statsobject{$object->{U}}{MaxVal} = $object->{MaxVal};
			} else {
				$lox_statsobject{$object->{U}}{MaxVal} = "U";
			}
		}
	}
	
	my $end_run = time();
	my $run_time = $end_run - $start_run;
	# print "Job took $run_time seconds\n";
}

#####################################################
# Error-Sub
#####################################################

sub error 
{
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
