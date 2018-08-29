#!/usr/bin/perl

package Stats4Lox::Source::Loxone;

# Data fetcher for Loxone Miniserver using HTTP REST webservice
#
# The statscfg datastructure contains all information about this statistic. It also
# contains information about the datasource (like here, Loxone). It is a hashref 
# containing hashes. 
# See https://www.loxwiki.eu/x/bwI_Ag


sub fetch {
	
	my $self = shift;
	
	# Incoming parameters - they may be extended in the future
	my %params = @_;
	$statid = $params{statid};		# This is the ID of the current statistic
	$statscfg = $params{statcfg};	# This is the statistic configuration as a hashref
	
	# The return hash needs to be filled with your value and timestamp
	my %returnhash;

	print STDERR "StatId $statid ===========================\n";
	#print STDERR "Source: " . $statscfg->{Source}->{Loxone}->{msno} . "\n";
	#print "StatsCfg loaded (in): " . $statscfg->{Source}->{Loxone}->{fetchSource} . "\n";
		
	 
	 # We need the Miniserver number from the $statcfg

	my $msno = $statscfg->{Source}->{Loxone}->{msno};
	my $fetchSource = $statscfg->{Source}->{Loxone}->{fetchSource};
	#print STDERR "MSNR $msno $fetchSource\n";
	return undef if (! $msno);
	return undef if (! $fetchSource);
	#print STDERR "Require LoxBerry::IO\n";
	require LoxBerry::IO;
	require Time::HiRes;
	require URI::Escape;
	$fetchSource = URI::Escape::uri_escape($fetchSource);
	#print STDERR "Now sending data to $fetchSource\n";
	Time::HiRes::usleep(300000);
	my ($value, $statuscode, $respobj) = LoxBerry::IO::mshttp_call($msno, "/dev/sps/io/$fetchSource/all");
	if ($statuscode ne "200") {
		return undef;
	}
	
	# Filter units
	$value =~ s/^([\d\.]+).*/$1/g;
		
	# Fill the return hash
	# {value} needs to be your fetched value
	# {timestamp} needs to be the time of the value in epoch
	$returnhash{value} = "$value";
	$returnhash{timestamp} = time;
		
	return %returnhash;
}










#####################################################
# Finally 1; ########################################
#####################################################
1;
