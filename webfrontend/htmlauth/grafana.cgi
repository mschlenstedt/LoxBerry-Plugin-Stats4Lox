#!/usr/bin/perl

use LoxBerry::System;
require "$lbpbindir/libs/Stats4Lox.pm";
use LoxBerry::Web;
use warnings;
use strict;

my $plugintitle = "Statistics 4 Loxone";
my $helplink = "http://www.loxwiki.eu:80/x/o4CO";
my $helptemplate = "help.html";

Stats4Lox::navbar_main(95);
LoxBerry::Web::lbheader($plugintitle, $helplink, $helptemplate);

my $template = HTML::Template->new(
    filename => "$lbptemplatedir/grafana.html",
    global_vars => 1,
    loop_context_vars => 1,
    die_on_bad_params => 0,
);

my %L = LoxBerry::System::readlanguage($template, "stats4lox.ini");

# $template->param('rrdfolder_select', $rrdfolder_html);
# $template->param('configfolder_select', $configfolder_html);

if(LoxBerry::System::plugindata("grafana")) {
	$template->param('grafana_plugin_found', 1);
}


print $template->output();

LoxBerry::Web::lbfooter();
