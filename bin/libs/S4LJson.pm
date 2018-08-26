#!/usr/bin/perl
use JSON;
use File::Copy;
use warnings;
use strict;


package Stats4Lox::JSON;

our $DEBUG = 0;

if ($DEBUG) {
	print STDERR "Stats4Lox::JSON: Developer warning - DEBUG mode is enabled in module file\n" if ($DEBUG);
}

sub new 
{
	print STDERR "Stats4Lox::JSON->new: Called\n" if ($DEBUG);

	my $class = shift;
	my $self = {};
	bless $self, $class;
	return $self;
}

sub open
{
	print STDERR "Stats4Lox::JSON->open: Called\n" if ($DEBUG);
	
	my $self = shift;
	
	if (@_ % 2) {
		print STDERR "Stats4Lox::JSON->open: ERROR Illegal parameter list has odd number of values\n" if ($DEBUG);
		Carp::croak "Illegal parameter list has odd number of values\n" . join("\n", @_) . "\n";
	}
	
	my %params = @_;
	
	$self->{filename} = $params{filename};
	$self->{writeonclose} = $params{writeonclose};

	print STDERR "Stats4Lox::JSON->open: filename is $self->{filename}\n" if ($DEBUG);
	print STDERR "Stats4Lox::JSON->open: writeonclose is ", $self->{writeonclose} ? "ENABLED" : "DISABLED", "\n" if ($DEBUG);
	
	if (! -e $self->{filename}) {
		print STDERR "Stats4Lox::JSON->open: WARNING $self->{filename} does not exist - write will create it\n" if ($DEBUG);
		my $objref = undef;
		$self->{createfile} = 1;
		$self->{jsoncontent} = "";
		$self->{jsonobj} = JSON::from_json('{}');
		return $self->{jsonobj};
	}
	
	print STDERR "Stats4Lox::JSON->open: Reading file $self->{filename}\n" if ($DEBUG);
	CORE::open my $fh, '<', $self->{filename} or do { 
		print STDERR "Stats4Lox::JSON->open: ERROR Can't open $self->{filename} -> returning undef : $!\n" if ($DEBUG);
		return undef; 
	};
	
	local $/;
	$self->{jsoncontent} = <$fh>;
	close $fh;

	print STDERR "Stats4Lox::JSON->open: Check if file has content\n" if ($DEBUG);

	# Check for content
	if (!$self->{jsoncontent}) {
		print STDERR "Stats4Lox::JSON->open: ERROR file seems to be empty -> Returning undef\n" if ($DEBUG);
		return undef;
	}
	
	print STDERR "Stats4Lox::JSON->open: Convert to json and return json object\n" if ($DEBUG);
	eval {
		$self->{jsonobj} = JSON::from_json($self->{jsoncontent});
	};
	if ($@) {
		print STDERR "Stats4Lox::JSON->open: ERROR parsing JSON file - Returning undef $@\n" if ($DEBUG);
		return undef;
	};
	return $self->{jsonobj};
	
}
	
sub write
{
	print STDERR "Stats4Lox::JSON->write: Called\n" if ($DEBUG);
	my $self = shift;
	
	print STDERR "No jsonobj\n" if (!$self->{jsonobj});
	
	my $jsoncontent_new;
	eval {
		$jsoncontent_new = JSON->new->pretty->canonical(1)->encode($self->{jsonobj});
		}; 
	if ($@) {
		print STDERR "Stats4Lox::JSON->write: JSON Encoder sent an error\n$@" if ($DEBUG);
		return;
	}
		
	# Compare if json was changed
	if ($jsoncontent_new eq $self->{jsoncontent}) {
		print STDERR "Stats4Lox::JSON->write: JSON are equal - nothing to do\n" if ($DEBUG);
		return;
	}
	
	print STDERR "Stats4Lox::JSON->write: JSON has changed - write to $self->{filename}\n" if ($DEBUG);
	
	CORE::open(my $fh, '>', $self->{filename} . ".tmp");
	print $fh $jsoncontent_new;
	close($fh);
	rename $self->{filename}, $self->{filename} . ".bkp";
	rename $self->{filename} . ".tmp", $self->{filename};
	$self->{jsoncontent} = $jsoncontent_new;
	
}

sub DESTROY
{
	my $self = shift;
	print STDERR "Stats4Lox::JSON->DESTROY: Called\n" if ($DEBUG);
	
	if (! defined $self->{jsonobj} or ! defined $self->{filename}) {
		print STDERR "Stats4Lox::JSON->DESTROY: Object seems not to be correctly initialized - doing nothing\n" if ($DEBUG);
		return;
	}	
	if ($self->{writeonclose}) {
		print STDERR "Stats4Lox::JSON->DESTROY: writeonclose is enabled, calling write\n" if ($DEBUG);
		$self->write();
	} else {
		print STDERR "Stats4Lox::JSON->DESTROY: Do nothing\n" if ($DEBUG);
	}
}

#####################################################
# Finally 1; ########################################
#####################################################
1;
