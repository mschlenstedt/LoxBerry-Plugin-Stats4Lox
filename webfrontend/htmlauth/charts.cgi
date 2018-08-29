#!/usr/bin/perl

use LoxBerry::Web;
use LoxBerry::Log;
require "$lbpbindir/libs/Stats4Lox.pm";

my $template = HTML::Template->new(
    filename => "$lbptemplatedir/charts.html",
    global_vars => 1,
    loop_context_vars => 1,
    die_on_bad_params => 0,
#    associate => %pcfg,
);

LoxBerry::Web::lbheader("Stat4Lox Charts", undef, undef);

print $template->output();

LoxBerry::Web::lbfooter();



