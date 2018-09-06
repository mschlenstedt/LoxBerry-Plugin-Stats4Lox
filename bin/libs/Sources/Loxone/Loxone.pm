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

	print STDERR ">== Fetch StatId $statid ===\n";
	#print STDERR "Source: " . $statscfg->{Source}->{Loxone}->{msno} . "\n";
	#print "StatsCfg loaded (in): " . $statscfg->{Source}->{Loxone}->{fetchSource} . "\n";
		
	 
	# We need the Miniserver number from the $statcfg

	my $msno = $statscfg->{Source}->{Loxone}->{msno};
	my $fetchSource = $statscfg->{Source}->{Loxone}->{fetchSource};
	my %outputs =  %{$statscfg->{Source}->{Loxone}->{outputs}};
	
	#print STDERR "MSNR $msno $fetchSource \n";
	return undef if (! $msno);
	return undef if (! $fetchSource);
	
	#print STDERR "Require LoxBerry::IO\n";
	require LoxBerry::IO;
	require Time::HiRes;
	require URI::Escape;
	$fetchSource_escaped = URI::Escape::uri_escape($fetchSource);
	#print STDERR "Now sending data to $fetchSource\n";
	my ($loxvalue, $statuscode, $respobj) = LoxBerry::IO::mshttp_call($msno, "/dev/sps/io/$fetchSource_escaped/all");
	if ($statuscode ne "200") {
		return undef;
	}
	
	my %values;
	foreach my $output (keys %outputs) {
		$value = $respobj->{output}->{$output}->{value};
		$label = $outputs{$output};
		print STDERR "Output '$output' Label $label value $value\n";
		# Filter units
		$value =~ s/^([-\d\.]+).*/$1/g;
		$values{$label} = $value;
	}
	
	if($respobj->{output}->{AQ}->{value}) {
		$value = $respobj->{output}->{AQ}->{value};
	} else {
		$value = $loxvalue;
	}
	
	if(%values) {
		$returnhash{outputs} = \%values;
	}
	
	$returnhash{timestamp} = time;
	$value =~ s/^([-\d\.]+).*/$1/g;
	
	print STDERR "Value after regex: " . $value . "\n";
	$returnhash{value} = $value;

	print STDERR "returnhash: " . Data::Dumper::Dumper (\%returnhash);

	Time::HiRes::usleep(300*1000);
	print STDERR "<=== Fetch finished\n";
	return %returnhash;
}










#####################################################
# Finally 1; ########################################
#####################################################
1;
