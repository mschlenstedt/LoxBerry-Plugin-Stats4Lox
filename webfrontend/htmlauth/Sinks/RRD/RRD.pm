#!/usr/bin/perl

package Stats4Lox::Sinks::RRD;

sub InterfaceDescription 
{ return "Data sink for Stats4Lox integrated RRD database"; }

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

		# Simple input is easy - send the value to the fixed name 'value'

		$value = _rrd_prepare_write('value', $value);
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
		
		# Loop through the data output of the fetch 
		# RRD needs that the values are sent in the order of the datasources
		# RRDinfo does not respond in a sorted order, but every DS has an counting .index property 
		# We loop through the output, check if output matches a DS, and set an array @dsindexes[DS-Index] = value
		# This is very performant, as we really only process the fetched data, and not the RRDinfo hash for matches
		
		foreach my $output(keys %outputs) {
			# %outputs = all outputs, $outputs{$output} = the value,  $output is the ds-name
			print STDERR $output . " " . $outputs{$output} . "\n";
			print STDERR %$rrdinfo{"ds[$output].index"} . "\n";
			# If the RRD has 
			if(defined %$rrdinfo{"ds[$output].index"}) {
				print "index found: " . %$rrdinfo{"ds[$output].index"} . "\n";
				my $dsindex = %$rrdinfo{"ds[$output].index"};
				print "dsindex: $dsindex Output $outputs{$output}\n";
				my $value = _rrd_prepare_write($output, $outputs{$output});
				$dsindexes[$dsindex] = $value;
				print "dsindexes[dsindex] $dsindexes[$dsindex]\n";
			}
		}
		print STDERR "Loop array\n";
		# As we have created the numbered array before in the sequence of the DS's, we generate the sendstring
		# If an index has no value (e.g. because the fetch did not know the DS), we set U for no value
		foreach my $index (keys @dsindexes) {
			print STDERR $index . " " . $dsindexes[$index] . "\n";
			if ($dsindexes[$index]) {
				$sendstring .= ":$dsindexes[$index]";
			} else {
				$sendstring .= ":U";
			}
		}
	$sendstring = "$timestamp" . $sendstring if($sendstring);
	
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

sub _rrd_prepare_write
{
	my ($ds, $value) = @_;
	
	# Get Datasource type (GAUGE, COUNTER ...)
	my $rrd_dstype = %$rrdinfo{"ds[$ds].type"};
	print STDERR "rrd_prepare_write: ds '$ds' value '$value', dstype $rrd_dstype\n";
	# print STDERR Data::Dumper::Dumper(%$rrdinfo);
	
	if (! $rrd_dstype) {
	 return undef;
	}
	
	# With these DS types only INTEGERs are allowed
	if ($rrd_dstype eq 'COUNTER' || $rrd_dstype eq 'DERIVE' || $rrd_dstype eq 'ABSOLUTE') { 
		$value = ceil($value);
	}
	
	return $value;

}

## Init of the statcfg template
sub initstatcfg
{
	my %returnhash;
	my $self = shift;
	# Incoming parameters - they may be extended in the future
	my %params = @_;
	$statid = $params{statid};		# This is the ID of the current statistic
	$statcfg = $params{statcfg};	# This is the statistic configuration as a hashref
	
	
	$returnhash{statcfg} = $statcfg;
	$returnhash{html} = Stats4Lox::read_file("$LoxBerry::System::lbphtmlauthdir/Sinks/RRD/RRD_statcfg.html");
	
	return %returnhash;

}




#####################################################
# Finally 1; ########################################
#####################################################
1;
