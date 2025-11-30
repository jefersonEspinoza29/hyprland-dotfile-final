#!/usr/bin/env bash

if pgrep -x "gnome-calendar" >/dev/null 2>&1; then
  # Ya está abierto → lo cerramos
  pkill -x "gnome-calendar"
else
  # No está abierto → lo abrimos
  gnome-calendar &
fi
