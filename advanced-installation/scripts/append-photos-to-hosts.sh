#!/bin/sh
(

if ! cd "$(git rev-parse --show-toplevel)/advanced-installation"
then
	echo Could not change directory to advanced-installation.
exit 1
fi

if grep photos.local /etc/hosts
then
	echo 'photos.local is already in /etc/hosts'
	exit 0
else
	if echo '127.0.0.3       photos.local' | sudo tee -a /etc/hosts >/dev/null
	then
		echo 'photos.local has been added to /etc/hosts as 127.0.0.3'
		exit 0
	else
		echo 'failed to add photos.local to /etc/hosts'
		exit 1
	fi
fi

)
