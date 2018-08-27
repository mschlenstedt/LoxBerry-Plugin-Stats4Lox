#!/usr/bin/perl
package Stats4Lox::Sink::RRD;
#
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
	$statid = $params{statid};		# The ID of the current statistic
	$statcfg = $params{statcfg};	# The statistic configuration as a hashref
	$timestamp = $params{timestamp};# Epoch time of the record
	$value = $params{value};		# Value

 	LOGDEB "This is fetch module 'RRD'";
	LOGDEB "Incoming values: Timestamp $timestamp / Value $value";

	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	


}










#####################################################
# Finally 1; ########################################
#####################################################
1;
