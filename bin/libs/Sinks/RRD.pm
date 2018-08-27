#!/usr/bin/perl

package Stats4Lox::Sink::RRD;

# Data sink for Stats4Lox integrated RRD database
#
# The statscfg datastructure contains all information about this statistic. It also
# contains information about the datasource (like here, Loxone). It is a hashref 
# containing hashes. 
# See https://www.loxwiki.eu/x/bwI_Ag

sub value {
	my $self = shift;
	
	# Incoming parameters - they may be extended in the future
	my %params = @_;
	print STDERR Data::Dumper::Dumper(\%params);
	$statid = $params{statid};		# The ID of the current statistic
	$statcfg = $params{statcfg};	# The statistic configuration as a hashref
	$timestamp = $params{timestamp};# Epoch time of the record
	$value = $params{value};		# Value
	
	main::LOGDEB("Sink RRD: Incoming values: Timestamp $timestamp / Value $value");

	# Get RRD infos
	$rrdfile = $CFG::MAIN_RRDFOLDER . "/" . $statcfg->{Sink}->{RRD}->{filename};
	my $rrdinfo = RRDs::info ($rrdfile);
	my $ERR=RRDs::error;
	if ($ERR) {
		main::LOGERR("Could not evaluate RRD counter type.");
		return;
	}
	
	# Get Datasource type (GAUGE, COUNTER ...)
	my $rrd_dstype = %$rrdinfo{'ds[value].type'};
	if (! $rrd_dstype) {
		# if the default datasource is not found, let's do fuzzy search
		foreach my $key (sort keys %$rrdinfo){
			if (index($key, ".type") != -1) {
				$rrd_dstype = $$hash{$key}; 
				last;
			}
		}
	}
	
	# With these DS types only INTEGERs are allowed
	if ($rrd_dstype eq 'COUNTER' || $rrd_dstype eq 'DERIVE' || $rrd_dstype eq 'ABSOLUTE') { 
		$value = ceil($value);
	}

	# Sending value
	if (-S "/var/run/rrdcached.sock") {
		$output = qx(/usr/bin/rrdtool update -d /var/run/rrdcached.sock $rrdfile N:$value);
	} else {
		main::LOGWARN("RRDCaching Daemon (rrdcached) seems not to run. Writing values directly to disc.");
		$output = qx(/usr/bin/rrdtool update $rrdfile N:$value);
	}
	if ($? eq 0) {
		main::LOGOK("Value for Statistic ID $statid ($statcfg->{name}) is: $value");
		return 1;
	}
}


#####################################################
# Finally 1; ########################################
#####################################################
1;
