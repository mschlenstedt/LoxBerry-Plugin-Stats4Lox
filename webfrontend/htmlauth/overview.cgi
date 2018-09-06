#!/usr/bin/perl

use LoxBerry::Web;
use LoxBerry::Log;
require "$lbpbindir/libs/Stats4Lox.pm";

my $template = HTML::Template->new(
    filename => "$lbptemplatedir/overview.html",
    global_vars => 1,
    loop_context_vars => 1,
    die_on_bad_params => 0,
#    associate => %pcfg,
);

LoxBerry::Web::lbheader("Stat4Lox Overview", undef, undef);

my $json = Stats4Lox::read_file("$main::statisticsfile");
$json =~ tr/\r\n//d;

$template->param('statsdata', $json) if ($json);





print $template->output();

LoxBerry::Web::lbfooter();



