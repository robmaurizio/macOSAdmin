#!/bin/zsh

# Command parameters
application_label="dropbox"
notify="success"
debug="0"

if [[ -z $application_label ]]; then
    echo "Error: Application label not provided."
    exit 1
fi
if [[ -z $notify ]]; then
    notify="false"
fi
if [[ -z $debug ]]; then
    debug="false"
fi

latest_release_url=$(curl -s https://api.github.com/repos/Installomator/Installomator/releases/latest | grep "browser_download_url.*pkg" | cut -d '"' -f 4)

echo $latest_release_url

curl -LJo /private/tmp/Installomator.pkg $latest_release_url

installer -store -pkg /private/tmp/Installomator.pkg -target /

# Install application based on arguments made in the Mosyle policy
/usr/local/Installomator/Installomator.sh "${application_label}" "NOTIFY=${notify}" "DEBUG=${debug}"
sleep 2

# Cleanup
rm -rf /private/tmp/Installomator.pkg
rm -rf /usr/local/Installomator/*

exit 0