#!/bin/sh

# Bashscript which is executed by bash *AFTER* complete installation is done
# (but *BEFORE* postupdate). Use with caution and remember, that all systems
# may be different! Better to do this in your own Pluginscript if possible.
#
# Exit code must be 0 if executed successfull.
#
# Will be executed as user "loxberry".
#
# We add 5 arguments when executing the script:
# command <TEMPFOLDER> <NAME> <FOLDER> <VERSION> <BASEFOLDER>
#
# For logging, print to STDOUT. You can use the following tags for showing
# different colorized information during plugin installation:
#
# <OK> This was ok!"
# <INFO> This is just for your information."
# <WARNING> This is a warning!"
# <ERROR> This is an error!"
# <FAIL> This is a fail!"

# To use important variables from command line use the following code:
ARGV0=$0 # Zero argument is shell command
ARGV1=$1 # First argument is temp folder during install
ARGV2=$2 # Second argument is Plugin-Name for scipts etc.
ARGV3=$3 # Third argument is Plugin installation folder
ARGV4=$4 # Forth argument is Plugin version
ARGV5=$5 # Fifth argument is Base folder of LoxBerry

/bin/sed -i "s:REPLACEFOLDERNAME:$ARGV3:g" $ARGV5/system/daemons/plugins/$ARGV2
/bin/sed -i "s:REPLACEINSTALLFOLDER:$ARGV5:g" $ARGV5/system/daemons/plugins/$ARGV2

/bin/sed -i "s:REPLACEFOLDERNAME:$ARGV3:g" $ARGV5/system/cron/cron.01min/$ARGV2
/bin/sed -i "s:REPLACEINSTALLFOLDER:$ARGV5:g" $ARGV5/system/cron/cron.01min/$ARGV2
/bin/sed -i "s:REPLACEFOLDERNAME:$ARGV3:g" $ARGV5/system/cron/cron.03min/$ARGV2
/bin/sed -i "s:REPLACEINSTALLFOLDER:$ARGV5:g" $ARGV5/system/cron/cron.03min/$ARGV2
/bin/sed -i "s:REPLACEFOLDERNAME:$ARGV3:g" $ARGV5/system/cron/cron.05min/$ARGV2
/bin/sed -i "s:REPLACEINSTALLFOLDER:$ARGV5:g" $ARGV5/system/cron/cron.05min/$ARGV2
/bin/sed -i "s:REPLACEFOLDERNAME:$ARGV3:g" $ARGV5/system/cron/cron.10min/$ARGV2
/bin/sed -i "s:REPLACEINSTALLFOLDER:$ARGV5:g" $ARGV5/system/cron/cron.10min/$ARGV2
/bin/sed -i "s:REPLACEFOLDERNAME:$ARGV3:g" $ARGV5/system/cron/cron.15min/$ARGV2
/bin/sed -i "s:REPLACEINSTALLFOLDER:$ARGV5:g" $ARGV5/system/cron/cron.15min/$ARGV2
/bin/sed -i "s:REPLACEFOLDERNAME:$ARGV3:g" $ARGV5/system/cron/cron.30min/$ARGV2
/bin/sed -i "s:REPLACEINSTALLFOLDER:$ARGV5:g" $ARGV5/system/cron/cron.30min/$ARGV2
/bin/sed -i "s:REPLACEFOLDERNAME:$ARGV3:g" $ARGV5/system/cron/cron.hourly/$ARGV2
/bin/sed -i "s:REPLACEINSTALLFOLDER:$ARGV5:g" $ARGV5/system/cron/cron.hourly/$ARGV2
/bin/sed -i "s:REPLACEFOLDERNAME:$ARGV3:g" $ARGV5/system/cron/cron.daily/$ARGV2
/bin/sed -i "s:REPLACEINSTALLFOLDER:$ARGV5:g" $ARGV5/system/cron/cron.daily/$ARGV2

echo "<INFO> Reading configuration"
. $LBHOMEDIR/libs/bashlib/iniparser.sh
iniparser $ARGV5/config/plugins/$ARGV3/stats4lox.cfg "Main"

if [ ! -d "$Mainrrdfolder" ]; then
  mkdir "$Mainrrdfolder"
fi

# Link databases to HTML directory to have access from Client JavaScript
ln -s "$Mainrrdfolder" "$ARGV5/webfrontend/html/plugins/$ARGV3/databases"
  
# Exit with Status 0
exit 0
