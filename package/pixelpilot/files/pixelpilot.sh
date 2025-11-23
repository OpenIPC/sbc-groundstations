#!/bin/sh

while true
do
  test -r /etc/default/pixelpilot && . /etc/default/pixelpilot
  /usr/bin/pixelpilot $PIXELPILOT_ARGS
  rc=$?
  if [ $rc = 2 -o $rc = 143 -o $rc = 137 ]
  then
    echo "Pixelpilot exited: $rc, skip restart ...."
    exit 2
  fi
  echo "Pixelpilot exited: $rc, restart ...."
  sleep 1
done