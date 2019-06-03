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

use LoxBerry::System;
use LoxBerry::Storage;
use LoxBerry::Web;
use LoxBerry::JSON;
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use File::Copy;
use warnings;
use strict;
require "$lbpbindir/libs/Stats4Lox.pm";

##########################################################################
# Variables
##########################################################################

# Read Form
my $cgi = CGI->new;
$cgi->import_names('R');

##########################################################################
# Read Settings
##########################################################################

# Version of this script
my $version = "0.4.0.0";

# Config
my $cfgfile = "$lbpconfigdir/stats4lox.json";

# Read json config
my $jsonobj = LoxBerry::JSON->new();
my $cfg = $jsonobj->open(filename => $cfgfile);

# Create Default config
if ( !-e $cfgfile || $cfg->{Main}->{rrdfolder} ) {
	$cfg->{Main}->{Rrdfolder} = "$lbpdatadir/databases";
	$cfg->{Main}->{Configfolder} = "$lbpdatadir/s4ldata";
	$cfg->{Main}->{Configversion} = "2";
	$cfg->{Rrd}->{Rrdcachedaddress} = "/var/run/rrdcached.sock";
	$cfg->{Rrd}->{Rrdcachedenabled} = "1";
	$cfg->{Rrd}->{Rrdcachedinterval} = "3600";
	$jsonobj->write();
}

#########################################################################
# Template
#########################################################################

# Init Template
my $template = HTML::Template->new (
	filename => "$lbptemplatedir/main.html",
	global_vars => 1,
	loop_context_vars => 1,
	die_on_bad_params=> 0,
	#associate => $cfg,
	%LoxBerry::Web::htmltemplate_options,
	debug => 1,
);

# Language
my %L = LoxBerry::System::readlanguage($template, "language.ini");

#########################################################################
# Template
#########################################################################

our %navbar;
my $shownotifies;

# Switch forms
if( $R::form eq "overview" || !$R::form) {
	$navbar{10}{active} = 1;
	$template->param("FORM_OVERVIEW", 1);
	$shownotifies = 1;
	#overview_form();
}
elsif ( $R::form eq "settings" ) {
	$navbar{30}{active} = 1;
	$template->param("FORM_SETTINGS", 1);
	settings_form();
}
elsif ( $R::form eq "about" ) {
	$navbar{90}{active} = 1;
	$template->param("FORM_ABOUT", 1);
	about_form();
}
elsif ( $R::form eq "logfiles" ) {
	$navbar{99}{active} = 1;
	$template->param("FORM_LOGFILES", 1);
	logfiles_form();
}

print_form();

exit;

#########################################################################
# Sub Routines
#########################################################################

#########################################################################
# Print Form
#########################################################################

sub print_form {

	$navbar{10}{Name} = "$L{'GENERAL.LABEL_OVERVIEW'}";
	$navbar{10}{URL} = 'index.cgi?form=overview';
	
	$navbar{20}{Name} = "$L{'GENERAL.LABEL_IMPORTWIZARD'}";
	$navbar{20}{URL} = 'importwizard.cgi';
	
	$navbar{30}{Name} = "$L{'GENERAL.LABEL_SETTINGS'}";
	$navbar{30}{URL} = 'index.cgi?form=settings';
	
	$navbar{90}{Name} = "$L{'GENERAL.LABEL_ABOUT'}";
	$navbar{90}{URL} = 'index.cgi?form=about';
	
	$navbar{99}{Name} = "$L{'GENERAL.LABEL_LOGFILES'}";
	$navbar{99}{URL} = 'index.cgi?form=logfiles';
	
	
	my $plugintitle = $L{'GENERAL.LABEL_PLUGINTITLE'} . " v" . LoxBerry::System::pluginversion();
	my $helplink = "https://www.loxwiki.eu/x/voK4";
	my $helptemplate = "help.html";
	
	LoxBerry::Web::lbheader($plugintitle, $helplink, $helptemplate);
	if ($navbar{10}{active} eq 1) {
		print LoxBerry::Log::get_notifications_html($lbpplugindir);
	}
	print $template->output();
	LoxBerry::Web::lbfooter();

}

#########################################################################
# Form: Logfiles
#########################################################################

sub logfiles_form {

	$template->param( "LOGLIST_HTML", LoxBerry::Web::loglist_html() );
	return();

}

#########################################################################
# Form: About
#########################################################################

sub about_form {

	return();

}

sub settings_form {

	# Save
	if ( $R::saveformdata ) {
		$cfg->{Main}->{Rrdfolder} = "$R::Main_Rrdfolder";
		$cfg->{Main}->{Configfolder} = "$R::Main_Configfolder";
		$cfg->{Rrd}->{Rrdcachedenabled} = "$R::Rrd_Rrdcachedenabled";
		$cfg->{Rrd}->{Rrdcachedaddress} = "$R::Rrd_Rrdcachedaddress";
		$cfg->{Rrd}->{Rrdcachedintervall} = "$R::Rrd_Rrdcachedintervall";
		$jsonobj->write();
		$template->param('HINTSAVED', $L{'SETTINGS.HINT_SAVED'});
	}

	# Push json config to template
	my $cfgfilecontent = LoxBerry::System::read_file($cfgfile);
	$cfgfilecontent =~ s/[\r\n]//g;
	$template->param('JSONCONFIG', $cfgfilecontent);

	# Config Folder
	my $configfolder_html = LoxBerry::Storage::get_storage_html(
		formid => 'Main_Configfolder',
		currentpath => $cfg->{Main}->{Configfolder},
		custom_folder => 1,
		readwriteonly => 1,
		type_all => 1,
		data_mini => 1
	);
	$template->param('CONFIGFOLDER_SELECT', $configfolder_html);

	# Database Folder
	my $rrdfolder_html = LoxBerry::Storage::get_storage_html(
		formid => 'Main_Rrdfolder',
		currentpath => $cfg->{Main}->{Rrdfolder},
		custom_folder => 1,
		readwriteonly => 1,
		type_all => 1,
		data_mini => 1
	);
	$template->param('RRDFOLDER_SELECT', $rrdfolder_html);

	return();

}
