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
use Config::Simple;
use File::HomeDir;
use Cwd 'abs_path';
#use warnings;
#use strict;
#no strict "refs"; # we need it for template system

##########################################################################
# Variables
##########################################################################

our $cfg;
our $phrase;
our $namef;
our $value;
our %query;
our $lang;
our $template_title;
our $help;
our @help;
our $helptext;
our $helplink;
our $installfolder;
our $languagefile;
our $version;
our $error;
our $output;
our $message;
our $do;
our $nexturl;
our @data;
our @fields;
our $i;
our $home = File::HomeDir->my_home;
our $ptablerows;
our $db;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.7";

# Figure out in which subfolder we are installed
our $psubfolder = abs_path($0);
$psubfolder =~ s/(.*)\/(.*)\/(.*)$/$2/g;

$cfg             = new Config::Simple("$home/config/system/general.cfg");
$installfolder   = $cfg->param("BASE.INSTALLFOLDER");
$lang            = $cfg->param("BASE.LANG");

#########################################################################
# Parameter
#########################################################################

# Everything from URL
foreach (split(/&/,$ENV{'QUERY_STRING'})){
  ($namef,$value) = split(/=/,$_,2);
  $namef =~ tr/+/ /;
  $namef =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $value =~ tr/+/ /;
  $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
  $query{$namef} = $value;
}

# And this one we really want to use
$do           = $query{'do'};
$db           = $query{'db'};

# Filter
quotemeta($query{'lang'});
quotemeta($do);
quotemeta($db);

$saveformdata          =~ tr/0-1//cd;
$saveformdata          = substr($saveformdata,0,1);
$query{'lang'}         =~ tr/a-z//cd;
$query{'lang'}         =  substr($query{'lang'},0,2);

##########################################################################
# Language Settings
##########################################################################

# Override settings with URL param
if ($query{'lang'}) {
  $lang = $query{'lang'};
}

# Standard is german
if ($lang eq "") {
  $lang = "de";
}

# If there's no language phrases file for choosed language, use german as default
if (!-e "$installfolder/templates/plugins/$lang/language.dat") {
  $lang = "de";
}

# Read translations / phrases
$languagefile = "$installfolder/templates/plugins/$psubfolder/$lang/language.dat";
$phrase = new Config::Simple($languagefile);

##########################################################################
# Main program
##########################################################################

#########################################################################
# What should we do
#########################################################################

# Menu
if (!$do || $do eq "form") {
  &form;
}

# Pause grepping data
elsif ($do eq "pause") {
  &pause;
}

# Start grepping data
elsif ($do eq "play") {
  &play;
}

else {
  &form;
}

exit;

#####################################################
# Form / Menu
#####################################################

sub form {

print "Content-Type: text/html\n\n";

$template_title = $phrase->param("TXT0000") . ": " . $phrase->param("TXT0001");
$help = "plugin";

# Create table rows for each Plugin entry
$ptablerows = "";
$i = 1;
open(F,"<$installfolder/config/plugins/$psubfolder/databases.dat");
  @data = <F>;
  foreach (@data){
    s/[\n\r]//g;
    # Comments
    if ($_ =~ /^\s*#.*/) {
      next;
    }
    @fields = split(/\|/);
    $dbname = @fields[0];
    $status = @fields[7];
    $ptablerows = $ptablerows . "<tr><th style='vertical-align:middle'>$i</th><td style='vertical-align:middle'>@fields[2]</td><td style='vertical-align:middle'>@fields[3]</td><td style='text-align:center; vertical-align:middle'>@fields[4]</td>";
    $ptablerows = $ptablerows . "<td style='text-align:left; vertical-align:middle'>";
    if ($status eq "0") {
      $ptablerows = $ptablerows . "<img src='/plugins/$psubfolder/images/icons/statusred.png' alt='" . $phrase->param("TXT0016") . "' title='" . $phrase->param("TXT0017") . "'></td>";
    }
    if ($status eq "1") {
      $ptablerows = $ptablerows . "<img src='/plugins/$psubfolder/images/icons/statusyellow.png' alt='" . $phrase->param("TXT0018") . "' title='" . $phrase->param("TXT0019") . "'></td>";
    }
    else {
      $ptablerows = $ptablerows . "<img src='/plugins/$psubfolder/images/icons/statusgreen.png' alt='" . $phrase->param("TXT0020") . "' title='" . $phrase->param("TXT0021") . "'></td>";
    }
    $ptablerows = $ptablerows . "<td><a href='./index.cgi?do=pause&db=$dbname'><img src='/plugins/$psubfolder/images/icons/pause.png' alt='" . $phrase->param("TXT0018") . "'></a>";
    $ptablerows = $ptablerows . "&nbsp;<a href='./index.cgi?do=play&db=$dbname'><img src='/plugins/$psubfolder/images/icons/play.png' alt='" . $phrase->param("TXT0022") . "'></a>";
    $ptablerows = $ptablerows . "&nbsp;<a href='./index.cgi?do=info&db=$dbname'><img src='/plugins/$psubfolder/images/icons/info.png' alt='" . $phrase->param("TXT0023") . "'></a>";
    $ptablerows = $ptablerows . "&nbsp;<a href='./index.cgi?do=import&db=$dbname'><img src='/plugins/$psubfolder/images/icons/import.png' alt='" . $phrase->param("TXT0024") . "'></a>";
    $ptablerows = $ptablerows . "&nbsp;<a href='./index.cgi?do=export&db=$dbname'><img src='/plugins/$psubfolder/images/icons/export.png' alt='" . $phrase->param("TXT0025") . "'></a>";
    $ptablerows = $ptablerows . "&nbsp;<a href='./index.cgi?do=config&db=$dbname'><img src='/plugins/$psubfolder/images/icons/config.png' alt='" . $phrase->param("TXT0026") . "'></a>";
    $ptablerows = $ptablerows . "&nbsp;<a href='./index.cgi?do=delete&db=$dbname'><img src='/plugins/$psubfolder/images/icons/trash.png' alt='" . $phrase->param("TXT0027") . "'></a></td></tr>";
    $i++;
  }
close (F);

# Print Template
&header;
open(F,"$installfolder/templates/plugins/$psubfolder/$lang/mainmenu.html") || die "Missing template plugins/$psubfolder/$lang/mainmenu.html.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);
&footer;

exit;

}

#####################################################
# Pause grepping data
#####################################################

sub pause {

if (!$db) {
	$db = "all";
}

# Update database
open(F,"+<$installfolder/config/plugins/$psubfolder/databases.dat") or die "Could not open databases.dat: $!";
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
    @fields = split(/\|/);
    if (@fields[0] eq $db || $db eq "all") {
      print F "@fields[0]|@fields[1]|@fields[2]|@fields[3]|@fields[4]|@fields[5]|@fields[6]|1\n";
    } else {
      print F "$_\n";
    }
  }
close (F);

&form;

exit;

}

#####################################################
# Start grepping data
#####################################################

sub play {

if (!$db) {
	$db = "all";
}

# Update database
open(F,"+<$installfolder/config/plugins/$psubfolder/databases.dat") or die "Could not open databases.dat: $!";
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
    @fields = split(/\|/);
    if (@fields[0] eq $db || $db eq "all") {
      print F "@fields[0]|@fields[1]|@fields[2]|@fields[3]|@fields[4]|@fields[5]|@fields[6]|2\n";
    } else {
      print F "$_\n";
    }
  }
close (F);

&form;

exit;

}

#####################################################
# 
# Subroutines
#
#####################################################

#####################################################
# Error
#####################################################

sub error {

$template_title = $phrase->param("TXT0000") . " - " . $phrase->param("TXT0043");
$help = "plugin";

print "Content-Type: text/html\n\n";

&header;
open(F,"$installfolder/templates/system/$lang/error.html") || die "Missing template system/$lang/error.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
close(F);
&footer;

exit;

}

#####################################################
# Header
#####################################################

sub header {

  # create help page
  $helplink = "http://www.loxwiki.eu:80/x/o4CO";
  open(F,"$installfolder/templates/system/$lang/help/$help.html") || die "Missing template system/$lang/help/$help.html";
    @help = <F>;
    foreach (@help){
      s/[\n\r]/ /g;
      $helptext = $helptext . $_;
    }
  close(F);

  open(F,"$installfolder/templates/system/$lang/header.html") || die "Missing template system/$lang/header.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
  close(F);

}

#####################################################
# Footer
#####################################################

sub footer {

  open(F,"$installfolder/templates/system/$lang/footer.html") || die "Missing template system/$lang/footer.html";
    while (<F>) {
      $_ =~ s/<!--\$(.*?)-->/${$1}/g;
      print $_;
    }
  close(F);

}
