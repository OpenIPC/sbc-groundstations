#!/bin/sh

while true
do
  /usr/bin/pixelpilot $@
  rc=$?
  if [ $rc = 2 -o $rc = 143 -o $rc = 137 ]
  then
    echo "Pixelpilot exited: $rc, skip restart ...."
    exit 2
  fi
  echo "Pixelpilot exited: $rc, restart ...."
  sleep 1
done