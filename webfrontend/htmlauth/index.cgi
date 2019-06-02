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
$version = "0.4.0.0";

# Config
my $cfgfile = "$lbpconfigdir/stats4lox.json";

# Read json config
my $jsonobj = LoxBerry::JSON->new();
my $cfg = $jsonobj->open(filename => $cfgfile);

#########################################################################
# Template
#########################################################################

# Init Template
$template = HTML::Template->new (
        filename => "$lbptemplatedir/overview.html",
        global_vars => 1,
        loop_context_vars => 1,
        die_on_bad_params=> 0,
        #associate => $cfg,
        %LoxBerry::Web::htmltemplate_options,
        # debug => 1,
        );

# Language
my %SL = LoxBerry::System::readlanguage($template, "language.ini");

#########################################################################
# Navbar
#########################################################################

our %navbar;
$navbar{10}{Name} = "$L{'GENERAL.LABEL_OVERVIEW'}";
$navbar{10}{URL} = 'index.cgi?form=1';

$navbar{90}{Name} = "$L{'SETTINGS.LABEL_LOG'}";
# $navbar{99}{URL} = LoxBerry::Web::loglist_url();
$navbar{90}{URL} = 'index.cgi?form=90';
# $navbar{99}{target} = '_blank';

exit;

