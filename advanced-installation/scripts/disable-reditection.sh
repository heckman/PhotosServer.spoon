#!/bin/sh
(
	\
if ! cd "$(git rev-parse --show-toplevel)/advanced-installation"
then
	echo Could not change directory to advanced-installation.
	exit 1
fi

sudo launchctl unload -w /Library/LaunchDaemons/ca.heckman.photos-server.plist > /dev/null 2>&1

if {
	! test -f /Library/LaunchDaemons/ca.heckman.photos-server.plist ||
	sudo rm -i /Library/LaunchDaemons/ca.heckman.photos-server.plist
} && {
	! test -f /etc/pf.anchors/ca.heckman.photos-server ||
	sudo rm -i /etc/pf.anchors/ca.heckman.photos-server
}
then
	if sudo pfctl -F all -f /etc/pf.conf > /dev/null 2>&1
	then
		echo Packet filter rules have been reset.
		exit 0
	else
		echo Failed to reset packet filter rules.
		exit 1
	fi
else
	echo Failed or aborted.
	exit 1
fi

)
