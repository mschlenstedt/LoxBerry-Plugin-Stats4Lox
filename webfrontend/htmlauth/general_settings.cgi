#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::Web;
use LoxBerry::Storage;
require "$lbpbindir/libs/Stats4Lox.pm";
use warnings;
use strict;

my $plugintitle = "Statistics 4 Loxone Version " . LoxBerry::System::pluginversion();
my $helplink = "http://www.loxwiki.eu:80/x/o4CO";
my $helptemplate = "help.html";

Stats4Lox::navbar_main(90);
LoxBerry::Web::lbheader($plugintitle, $helplink, $helptemplate);

my $template = HTML::Template->new(
    filename => "$lbptemplatedir/general_settings.html",
    global_vars => 1,
    loop_context_vars => 1,
    die_on_bad_params => 0,
);

my %L = LoxBerry::System::readlanguage($template, "stats4lox.ini");

my $configfolder_html = LoxBerry::Storage::get_storage_html( 
	formid => 'configfolder', 
	currentpath => $CFG::MAIN_CONFIGFOLDER,
	custom_folder => 1,
	readwriteonly => 1,
	type_all => 1
);
my $rrdfolder_html = LoxBerry::Storage::get_storage_html( 
	formid => 'rrdfolder', 
	currentpath => $Stats4Lox::pcfg->param('Main.rrdfolder'),
	custom_folder => 1,
	readwriteonly => 1,
	type_all => 1
);

$template->param('rrdfolder_select', $rrdfolder_html);
$template->param('configfolder_select', $configfolder_html);




print $template->output();

LoxBerry::Web::lbfooter();
