#!/usr/bin/perl
use LoxBerry::System;
require "$lbpbindir/libs/S4LJson.pm";

$Stats4Lox::JSON::DEBUG = 1;
$Stats4Lox::JSON::DUMP = 1;

my $jsonparser = Stats4Lox::JSON->new();
my $config = $jsonparser->open(filename => "/tmp/nofile.json", writeonclose => 0);
if (!$config) {
	print "Error loading file\n";
} else {
	print "File loaded\n";
}

print "Version of the file: $config->{Version}\n";

# Simple values
$config->{Info} = "Write data to JSON";
$config->{Version} = $config->{Version} + 1;

# Creating 	
$config->{MINISERVER_HASH}->{1}->{Name} = "MSOG";
$config->{MINISERVER_HASH}->{2}->{Name} = "MSUG";

my @colors = ( "red", "blue", "green");
$config->{Colors} = \@colors;

my %settings = ( "ip" => "192.168.0.1",
				 "port" => "8000",
				 "protocol" => "tcp"
				);
$config->{Server} = \%settings;
				
$jsonparser->write();

my @result = $jsonparser->find($config->{Colors}, "\$_ eq 'red' or \$_ eq 'green'");
$jsonparser->dump(\@result, "Result of Array search");


my @result = $jsonparser->find($config->{MINISERVER_HASH}, "\$_->{Name} eq 'MSUG'");
$jsonparser->dump(\@result, "Result of Hash search");
