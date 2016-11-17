#!/usr/bin/perl

use CGI;
use File::HomeDir;
use Cwd 'abs_path';
use Config::Simple;

our $psubfolder = abs_path($0);
$psubfolder =~ s/(.*)\/(.*)\/(.*)$/$2/g;
my $home = File::HomeDir->my_home;

my  $cfg = new Config::Simple("$home/config/system/general.cfg");
our $installfolder = $cfg->param("BASE.INSTALLFOLDER");


# Funktioniert nicht - $upload-filehandle leer...?!
	my $cgi = new CGI();
	my $upload_filehandle = $cgi->upload('loxplan');
	if (! $upload_filehandle ) {
		print STDERR "ERROR: LoxPLAN Upload - Stream filehandle not created.\n";
		exit (-1);
	}
	if (! open(UPLOADFILE, ">$loxconfig_path" ) ) {
		print STDERR "ERROR: LoxPLAN Upload - cannot open local file handle.\n";
		exit (-1);
	}
	# binmode UPLOADFILE;

	while (<$upload_filehandle>) {
		print UPLOADFILE "$_";
	}
	close $upload_filehandle;
	close UPLOADFILE;
	
print redirect(-url=>'/admin/plugins/$psubfolder/import.cgi');