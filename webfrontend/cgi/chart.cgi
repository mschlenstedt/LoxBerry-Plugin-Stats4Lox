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
our $home = File::HomeDir->my_home;
our $id;
our $output;

##########################################################################
# Read Settings
##########################################################################

# Version of this script
$version = "0.0.1";

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
$id           = $query{'id'};
$template     = $query{'template'};

# Filter
quotemeta($query{'lang'});
quotemeta($id);
quotemeta($template);

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
if (!-e "$installfolder/templates/plugins/$psubfolder/$lang/language.dat") {
  $lang = "de";
}

# Read translations / phrases
$languagefile = "$installfolder/templates/plugins/$psubfolder/$lang/language.dat";
$phrase = new Config::Simple($languagefile);

##########################################################################
# Chooe Chart Engine
##########################################################################

# Check for Chart Engine
open(F,"<$installfolder/config/plugins/$psubfolder/charts.dat");
@data = <F>;
foreach (@data){
	s/[\n\r]//g;
	# Comments
	if ($_ =~ /^\s*#.*/) {
		next;
	}
	@fields = split(/\|/);
	if (@fields[0] eq $id) {
  		our $chart_completeconfig = $_;
		our $chart_engine = @fields[1];
		last;
	}
}
close (F);

# Jump to Sub fpr choosen chart engine
if ($chart_engine eq "highcharts") {
	&highcharts;
}

exit;

##########################################################################
# HighCharts
##########################################################################

sub highcharts {

@fields = split(/\|/,$chart_completeconfig);
$chart_title = @fields[3];


# Print Template
open(F,"$installfolder/templates/plugins/$psubfolder/$lang/charts/highcharts/standard.html") || die "Missing template plugins/$psubfolder/$lang/charts/highcharts/standard.html";
  while (<F>) {
    $_ =~ s/<!--\$(.*?)-->/${$1}/g;
    print $_;
  }
close(F);

exit;

}

exit;
