#!/usr/bin/perl

use LWP::UserAgent;
use XML::Simple;
use Encode;

use LoxBerry::IO;
use Data::Dumper;
# use Encode qw(decode encode);


my ($value, $code, $data) = LoxBerry::IO::mshttp_call(1, "/dev/sps/io/Außentemperatursensor");

print "Value: $value\n";

