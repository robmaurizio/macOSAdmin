#!/bin/bash

# # # DESCRIPTION # # #
# This script will perform the initial Computer Onboarding statndard workflow customized for the specified Client. 


# # # REQUIREMENTS # # #
# 1. Platform: macOS. 
# 2. Computer completed enrollment in Jamf Pro. 
# 3. Valid script variable/parameter No. 1 'COMPANY_NAME'. 
# 3. Valid script variable parameter No. 2 'COMPANY_CODE'. 

####################################################################################################
#
# Pre-flight Checks
#
####################################################################################################

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Confirm script is running as root
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root; exiting."
    exit 1
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Ensure computer does not go to sleep while running this script (thanks, @grahampugh!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

echo "Caffeinating this script (PID: $$)"
caffeinate -dimsu -w $$ &

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate Setup Assistant has completed
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

while pgrep -q -x "Setup Assistant"; do
    echo "Setup Assistant is running; pausing..."
    sleep 2
done

echo "Setup Assistant is no longer running; proceeding …"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Confirm Dock is running / user is at Desktop
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

until pgrep -q -x "Finder" && pgrep -q -x "Dock"; do
    echo "Dock is NOT running; pausing..."
    sleep 1
done

echo "Dock is running; proceeding …"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Validate logged-in user
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )

if [[ -z "${loggedInUser}" || "${loggedInUser}" == "loginwindow" ]]; then
    echo "No user logged-in; exiting."
    exit 1
else
    loggedInUserID=$(id -u "${loggedInUser}")
fi


# # # CHECK JAMF # # #

echo "\nCheck jamf binary..."
if [ -f "/usr/local/bin/jamf" ]; then
	echo "...Result: Jamf binary exists. Continue."
else
	echo "...Result: Jamf binary does not exist. Cannot continue. Exit with error"
	exit 1
fi

###  CHECK SWIFTDIALOG ###
echo "\nCheck swiftDialog..."
if [ -f "/usr/local/bin/dialog" ]; then
	echo "...Result: swiftDialog binary exists. Continue."
else
    jamf policy -event Install-swiftDialog -verbose
fi

# # # PARAMETERS # # #
echo "\nScript parameters..."

# Name of the script
SCRIPT_NAME=$0
echo "SCRIPT_NAME: $SCRIPT_NAME"

MOUNT_POINT_TARGET_DRIVE=$1
echo "MOUNT_POINT_TARGET_DRIVE=$MOUNT_POINT_TARGET_DRIVE"

COMPUTER_NAME=$2
echo "COMPUTER_NAME=$COMPUTER_NAME"

CURRENT_USER_SHORTNAME=$3
echo "CURRENT_USER_SHORTNAME=CURRENT_USER_SHORTNAME"

COMPANY_NAME=$4
echo "Company name: $COMPANY_NAME"

COMPANY_CODE=$5
echo "COMPANY_CODE=$COMPANY_CODE"


# # # DISPLAY BASIC INFO # # #
echo "\nDisplay basic computer info:..."

## Timestamp using format: 'YYYYMMDD-HHMMSS' (e.g. '20190208-083739')
DATE_FORMAT=$(date "+%Y%m%d-%H%M%S") 
echo "Timestamp: $DATE_FORMAT"

## Computer hostname (e.g. 'PNT-LPT09.local') 
HOSTNAME=$(hostname)
echo "Hostname: $HOSTNAME"

SERIAL=$(system_profiler SPHardwareDataType | grep Serial | awk '{print $4}')
echo "Computer Serial Number: $SERIAL"

## System Software Overview (e.g. macOS version, computer name, etc.)
SYSTEM_PROFILE=$(system_profiler SPSoftwareDataType) 
echo "System Profile:..."
echo "$SYSTEM_PROFILE"

## Version of macOS
MACOS_VER=$(sw_vers)
echo "macOS version: $MACOS_VER"

## Values: "Journaled HFS+", "APFS"
FILE_SYSTEM=$(diskutil info / | awk -F': ' '/File System/{print $NF}' | xargs)
echo "File system: $FILE_SYSTEM"

ENCRYPT_CHECK=`fdesetup status`
echo "FileVault status: $ENCRYPT_CHECK"
FILEVAULT2_EXPECTED_STATUS="FileVault is On."
FILEVAULT2_STATUS_CHECK=$(echo "${ENCRYPT_CHECK}" | grep "${FILEVAULT2_EXPECTED_STATUS}")
echo "FileVault encryption status: $FILEVAULT2_STATUS_CHECK"
echo "Check FileVault2 status is completed..."
if [ "${FILEVAULT2_STATUS_CHECK}" == "${FILEVAULT2_EXPECTED_STATUS}" ]; then
	echo "FileVault2 is enabled." 
else 
	echo "FileVault2 is NOT enabled."
fi


# Display Onboarding Progress Using SwiftDialog
dialogBinary="/usr/local/bin/dialog"
dialog_command_file="/var/tmp/dialog.log"

####################################################################################################
# Functions
####################################################################################################

function finalize(){
  killProcess "caffeinate"
  echo "overlayicon: SF=checkmark.circle.fill,palette=green,white,none,bgcolor=none" >> "$dialog_command_file"
  echo "progresstext: Complete" >> "$dialog_command_file"
  echo "progress: complete" >> "$dialog_command_file"
  echo "message: Success!\n\nYour computer is set up and ready to use! Please click Finish to return to the Desktop." >> "$dialog_command_file"
  echo "button1text: Finish" >> "$dialog_command_file"
  echo "button1: enable" >> "$dialog_command_file"
  rm "$dialog_command_file"
  wait
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for / install swiftDialog (Thanks big bunches, @acodega!)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# # # COMPUTER ONBOARDING WORKFLOW # # #
echo "\nPerform Computer Onboarding standard workflow..."

#echo "\nInstall swiftDialog..."
#jamf policy -event Install-swiftDialog
#sleep 1

dialogRUN="$dialogBinary -s --title \"Computer Setup\" \
--message \"Welcome!\n\nYour computer will need about 30-40 minutes to get ready. Please connect to power and do NOT close the lid or shut down.\" \
--icon \"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FinderIcon.icns\" \
--progress 15 \
--progresstext ""Initializing configuration…"" \
--button1text \"Please Wait\" \
--button1disabled \
--titlefont 'shadow=true, size=16' \
--messagefont 'size=13' \
--position 'center' \
--blurscreen \
--ontop \
--quitkey k \
--commandfile "$dialog_command_file" "

#Run swiftDialog
echo $dialogRUN
eval $dialogRUN &
sleep 1

# Install Rosetta
echo "progress: 1" >> "$dialog_command_file"
echo "progresstext: Installing required frameworks..." >> "$dialog_command_file"
echo "\nInstall Rosetta 2:..."
jamf policy -event Install-Rosetta2 -verbose

# Rename Computer
echo "progress: 2" >> "$dialog_command_file"
echo "progresstext: Naming computer..." >> "$dialog_command_file"
echo "\nCall Jamf Policy via custom trigger to set the computer name:..."
jamf policy -event Set-ComputerName -verbose
sleep 1

# Run Recon
echo "progress: 3" >> "$dialog_command_file"
echo "progresstext: Gathering info..." >> "$dialog_command_file"
echo "\nCall Jamf Recon..."
/usr/local/bin/jamf recon

# Install Google Chrome
echo "\Install Google Chrome..."
echo "progress: 4" >> "$dialog_command_file"
echo "progresstext: Installing Google Chrome browser..." >> "$dialog_command_file"
jamf policy -event Install-GoogleChrome -verbose

# Install Remote Assistance Software
echo "progress: 5" >> "$dialog_command_file"
echo "progresstext: Insalling remote assistance..." >> "$dialog_command_file"
#echo "\nCall Jamf Policy via custom trigger to install ConnectWise Control (ScreenConnect)..."
jamf policy -event Install-ConnectWiseControl -verbose
sleep 1

# Install Watchman
echo "progress: 6" >> "$dialog_command_file"
echo "progresstext: Registering with fleet health..." >> "$dialog_command_file"
echo "\nCall Jamf Policy via custom trigger to install and register the Watchman Agent..."
jamf policy -event Install-Watchman -verbose
sleep 3

# Create Admin Accounts
echo "progress: 7" >> "$dialog_command_file"
echo "progresstext: Creating administrator accounts..." >> "$dialog_command_file"
echo "\nCall Jamf Policy via custom trigger to deploy the client admin user..."
jamf policy -event Create-resmanageAccount -verbose
sleep 1    

# Create Admin Accounts
echo "progress: 8" >> "$dialog_command_file"
echo "progresstext: Creating administrator accounts..." >> "$dialog_command_file"
echo "\nCall Jamf Policy via custom trigger to deploy the internal admin user..."
jamf policy -event Create-pointadminAccount -verbose
sleep 1

# Install Crowdstrike
echo "progress: 9" >> "$dialog_command_file"
echo "progresstext: Installing anti-malware software..." >> "$dialog_command_file"
echo "\nCall Jamf Policy via custom trigger to install and register the CrowdStrike Falcon Sensor/Agent..."
jamf policy -event Install-SentinelOne -verbose
sleep 1

# Install Acronis
echo "progress: 10" >> "$dialog_command_file"
echo "progresstext: Installing backup software..." >> "$dialog_command_file"
echo "\nCall Jamf Policy via custom trigger to install and register the Acronis Cyber Protect Agent..."
jamf policy -event Install-AcronisCyberProtect -verbose
sleep 1

# Install Managed Software
echo "progress: 11" >> "$dialog_command_file"
echo "progresstext: Installing Orchard framework..." >> "$dialog_command_file"
echo "\nCall Jamf Policy via custom trigger to install and register Orchard Update..."
jamf policy -event Install-OrchardUpdate -verbose
sleep 3

# Insalling Managed Software
echo "progress: 12" >> "$dialog_command_file"
echo "progresstext: Starting services..." >> "$dialog_command_file"
echo "\nCall Jamf Policy via custom trigger to install managed applications..."
jamf policy -event Install-ManagedSoftware -verbose
sleep 3

# Create ticket for new device
echo "progress: 13" >> "$dialog_command_file"
echo "progresstext: Rubber stamping our work..." >> "$dialog_command_file"
echo "\nCreate CW Manage Ticket for new Computer Onboarding..."
jamf policy -event Create-CwManage-Ticket-Onboarding -verbose

# Run policy
echo "progress: 14" >> "$dialog_command_file"
echo "progresstext: Finishing up..." >> "$dialog_command_file"
echo "\nCall Final check for policies applicable to the machine..."
/usr/local/bin/jamf policy -verbose
sleep 30

# Remind user we're still working
echo "progress: 15" >> "$dialog_command_file"
echo "progresstext: Just another few moments..." >> "$dialog_command_file"
sleep 25

# Close off processing and enable the "Done" button on the dialog box
echo "Exit script with success."
finalize
exit 0