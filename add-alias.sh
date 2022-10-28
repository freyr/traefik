#!/bin/bash

cp "com.runlevel1.lo0.172.16.123.1.plist" "/Library/LaunchDaemons/"
chmod 0644 "/Library/LaunchDaemons/com.runlevel1.lo0.172.16.123.1.plist"
chown root:wheel "/Library/LaunchDaemons/com.runlevel1.lo0.172.16.123.1.plist"
launchctl load "/Library/LaunchDaemons/com.runlevel1.lo0.172.16.123.1.plist"
