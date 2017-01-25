#!/usr/bin/perl
use XML::LibXML;
use LWP::UserAgent;
use Data::Dumper;

my $url = 'http://bw9services:waWAYopini19@192.168.0.77:80/stats/ffe6ebd6-f76b-11e0-9f4f9830180c3036.201207.xml';
my $ua = LWP::UserAgent->new();
my $response = $ua->get($url);
		
my $parser = XML::LibXML->new();
my $dom = XML::LibXML->load_xml( string => $response->content, 
								 no_blanks => 1);

print '$dom is a ' . ref($dom) . "\n";
print '$dom->nodeName is: ' . $dom->nodeName . "\n";

my $root = $dom->documentElement;
my @nodes = $root->childNodes();
my $count = @nodes;

foreach $node (@nodes) {
$next = $node->nextSibling();
print "This: $node->{T} Next: $next->{T} \n";

}

# my $node = $stats->getDocumentElement;
# my %childnodes = $node->childNodes();
# my $count = keys %childnodes;
# print "Keys" . $count . "\n";
# foreach $child (@childnodes) {
	# @attributelist = $node->attributes();

# }