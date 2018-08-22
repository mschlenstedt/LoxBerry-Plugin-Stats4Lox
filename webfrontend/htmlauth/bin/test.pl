#!/usr/bin/perl

use POSIX;
use Time::Piece;

print "Local Time Zone: " . strftime("%Z", localtime()), "\n";

my $curtime = Time::Piece->localtime;
print "Piece Current Time : $curtime\n";

my $testtime = Time::Piece->strptime("2017-01-08 19:23:05", "%Y-%m-%d %T");
print "Time: 2017-01-08 19:23:05 Piece Test Time : $testtime\n";


print "my pid: $$\n";
