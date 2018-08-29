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
	my $statid = $params{statid};		# The ID of the current statistic
	my $statcfg = $params{statcfg};	# The statistic configuration as a hashref
	my $timestamp = $params{timestamp};# Epoch time of the record
	my $value = $params{value};		# Value
	my %outputs = %{$params{outputs}};
	
	#print STDERR "Outputhash: " . Data::Dumper::Dumper(%outputs) . "\n";
	#print main::LOGDEB("Sink RRD: Incoming values: Timestamp $timestamp / Value $value");

	# Get RRD infos
	$rrdfile = $CFG::MAIN_RRDFOLDER . "/" . $statcfg->{Sink}->{RRD}->{filename};
	our $rrdinfo = RRDs::info ($rrdfile);
	#print STDERR Data::Dumper::Dumper ($rrdinfo);
	my $ERR=RRDs::error;
	if ($ERR) {
		main::LOGERR("Could not evaluate RRD counter type.");
		return;
	}
	
	my $sendstring;
	
	if (!%outputs) {
		main::LOGINF "Handling of simple input";
		$value = rrd_prepare_write('value', $value);
		print STDERR "Simple sending: prepared value: $value\n";
		if ($value) {
			$sendstring = "$timestamp:$value";
		} else {
			return;
		}
	}
	else {
		main::LOGINF "Handling of multiple datasources";
		my @dsindexes;
		foreach my $output(keys %outputs) {
			print STDERR $output . " " . $outputs{$output} . "\n";
			print STDERR %$rrdinfo{"ds[$output].index"} . "\n";
			if(defined %$rrdinfo{"ds[$output].index"}) {
				print "index found: " . %$rrdinfo{"ds[$output].index"} . "\n";
				my $dsindex = %$rrdinfo{"ds[$output].index"};
				print "dsindex: $dsindex Output $outputs{$output}\n";
				$dsindexes[$dsindex] = $outputs{$output};
				print "dsindexes[dsindex] $dsindexes[$dsindex]\n";
			}
		}
		print STDERR "Loop array\n";
		foreach my $index (keys @dsindexes) {
			print STDERR $index . " " . $dsindexes[$index] . "\n";
			if ($dsindexes[$index]) {
				$sendstring .= ":$dsindexes[$index]";
			} else {
				$sendstring .= ":U";
			}
		}
	$sendstring = "$timestamp" . $sendstring if($sendstring);
	
	
	# # Handling of multiple inputs
		
		# # We need to send the data in the order of the DS's, and the rrdinfo hash IS NOT ordered
		# # So we're looping the rrdinfo, looking for the ds[xxxx].index = ?
		# my @dsindexes;
		# foreach my $key (keys %$rrdinfo){
			# my $dsindex = $key;
			# if ( $dsindex =~ m/ds\[.*\].index\s*=\s*/i) {
				# $dsindex = $key;
				# $dsindex =~ s/ds\[.*\].index\s*=\s*//i;
				# print STDERR "Key $dsindex found from $key\n";
				# ($dsindexes[$dsindex]) = $key =~ /ds\[(.*)\]/;
				# print STDERR "Key $dsindex found in $key, extracted $dsindexes[$dsindex]\n";
			# }
		# }
		# # Now we have an ordered array of the ds - every ds should exist in the output
		# foreach my $ds (@dsindexes) {
			# print STDERR "$ds is $dsindexes[$ds]\n";
			# my $value = rrd_prepare_write($ds, $outputs{$ds});
			# $sendstring .= "$value:" if ($value);
			# $sendstring .= "U:" if (!$value);
		# }
		
		# $sendstring = substr("$timestamp:$sendstring", 0, -1) if $sendstring;
	}
	
	print STDERR "Current sendstring is: $sendstring\n";
	
	if (!$sendstring) {
		return undef;
	}
	
	# Sending value
	if (-S "$main::RRDCACHED_ADDRESS") {
		$output = qx(/usr/bin/rrdtool update -d $main::RRDCACHED_ADDRESS $rrdfile $sendstring);
	} else {
		main::LOGWARN("RRDCaching Daemon (rrdcached) seems not to run. Writing values directly to disc.");
		$output = qx(/usr/bin/rrdtool update $rrdfile $sendstring);
	}
	if ($? eq 0) {
		main::LOGOK("Value for Statistic ID $statid ($statcfg->{name}) is: $value");
		return 1;
	}
}


sub rrd_prepare_write
{
	my ($ds, $value) = @_;
	
	
	# Get Datasource type (GAUGE, COUNTER ...)
	my $rrd_dstype = %$rrdinfo{"ds[$ds].type"};
	print STDERR "rrd_prepare_write: ds '$ds' value '$value', dstype $rrd_dstype\n";
	# print STDERR Data::Dumper::Dumper(%$rrdinfo);
	
	if (! $rrd_dstype) {
	 return undef;
		# # if the default datasource is not found, let's do fuzzy search
		# foreach my $key (sort keys %$rrdinfo){
			# if (index($key, ".type") != -1) {
				# $rrd_dstype = $$hash{$key}; 
				# last;
			# }
		# }
	}
	
	# With these DS types only INTEGERs are allowed
	if ($rrd_dstype eq 'COUNTER' || $rrd_dstype eq 'DERIVE' || $rrd_dstype eq 'ABSOLUTE') { 
		$value = ceil($value);
	}
	
	return $value;
	




}




#####################################################
# Finally 1; ########################################
#####################################################
1;
