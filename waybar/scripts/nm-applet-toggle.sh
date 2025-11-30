#!/usr/bin/env bash

if pgrep -x "nm-applet" >/dev/null 2>&1; then
  killall nm-applet
else
  nm-applet --indicator &
fi
