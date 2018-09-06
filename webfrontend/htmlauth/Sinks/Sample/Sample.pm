#!/usr/bin/perl

package Stats4Lox::Sink::Sample;

# 	For this plugin, keep in mind:
# 		- You are in a Perl module -> every function and variable from another package must be fully qualified (e.g. $LoxBerry::System::lbpplugindir)
#		- As we are not in the main namespace, LoxBerry::Log messages needs to be called main::LOGINF("My text");
#		- You should name your own sub's with a leading underscore (_mysub) to avoid conflicts, if we enhance the plugin interface
#		- If your handler crashes for any reason, it is catched by our calling routine, and the error message is written to the statcfg_<statid>.json
#		- Don't call 'exit' ;-)

# value is the sending method
sub value {

	my $self = shift;
	
	# Incoming parameters - they may be extended in the future
	my %params = @_;
	my $statid = $params{statid};		# The ID of the current statistic
	my $statcfg = $params{statcfg};		# The statistic configuration as a hashref
	my $timestamp = $params{timestamp};	# Epoch time of the record
	my $value = $params{value};			# Value
	my %outputs = %{$params{outputs}};	# Multiple values

	
	# This is for your debugging
	# use Data::Dumper;
	# print STDERR Data::Dumper::Dumper(%outputs);
	
	
	
	
	
	
	
	
	
	
	
	
	
	# return undef; if you've failed
	# return "ok"; if you've won!
	
	
}


#####################################################
# Finally 1; ########################################
#####################################################
1;
