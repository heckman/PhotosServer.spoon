#!/bin/sh
(

if ! cd "$(git rev-parse --show-toplevel)/advanced-installation"
then
	echo Could not change directory to advanced-installation.
	exit 1
fi

if \
sudo cp -i ca.heckman.photos-server /etc/pf.anchors/ &&
sudo cp -i ca.heckman.photos-server.plist /Library/LaunchDaemons/
then
	sudo launchctl unload /Library/LaunchDaemons/ca.heckman.photos-server.plist >/dev/null 2>&1
	sudo launchctl load -w /Library/LaunchDaemons/ca.heckman.photos-server.plist >/dev/null 2>&1
	echo Requests to 127.0.0.3:80 should be redirected to 127.0.0.1:6330
	exit 0
else
	echo Redirection installation failed or aborted.
	exit 1
fi

)
