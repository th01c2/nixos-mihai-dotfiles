#!/usr/bin/env bash

# Find any running polybar processes and stop them
# This works even without 'killall'
pkill -9 polybar

# If you don't even have pkill, use this line instead:
# ps aux | grep -i polybar | grep -v grep | awk '{print $2}' | xargs -r kill -9

# Wait a tiny bit for the ports/memory to clear
sleep 1

# Start your bar (using whatever name is in your config.ini)
polybar mybar &
