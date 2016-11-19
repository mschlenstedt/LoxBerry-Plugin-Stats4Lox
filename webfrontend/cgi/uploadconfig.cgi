#!/usr/bin/perl

use CGI qw/:standard/;
use File::HomeDir;
use Cwd 'abs_path';
use Config::Simple;

our $psubfolder = abs_path($0);
$psubfolder =~ s/(.*)\/(.*)\/(.*)$/$2/g;
my $home = File::HomeDir->my_home;

my  $cfg = new Config::Simple("$home/config/system/general.cfg");
our $installfolder = $cfg->param("BASE.INSTALLFOLDER");

# Uploaded file from form
$uploadfile = param('loxplan');

# Filter Backslashes
$uploadfile =~ s/.*[\/\\](.*)/$1/;

# Path for upload file - clean before upload
$loxconfig_path = "/tmp/loxplan.xml";
if (-e $loxconfig_path && !-l $loxconfig_path) {
  system (rm -f $loxconfig_path);
}

# Write Uploadfile
open UPLOADFILE, ">$loxconfig_path" or die "Cannot open file for writing: $!";
binmode $uploadfile;
while ( <$uploadfile> ) {
  print UPLOADFILE;
}
close UPLOADFILE;

############
# For debugging only
my $output = qx(/usr/bin/file $loxconfig_path);
print "Content-Type: text/plain\n\n";
print "Upload OK.\nOutput from /usr/bin/file is: $output";
exit;
#
############

print redirect(-url=>'/admin/plugins/$psubfolder/import.cgi');
