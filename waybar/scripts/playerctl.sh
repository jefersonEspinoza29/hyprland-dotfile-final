#!/usr/bin/env bash

# Si no hay ningun reproductor MPRIS, no mostramos nada
if ! playerctl status &>/dev/null; then
  exit 0
fi

status=$(playerctl status 2>/dev/null || echo "")
#artist=$(playerctl metadata artist 2>/dev/null || echo "")
title=$(playerctl metadata title 2>/dev/null || echo "")

# Si no tenemos datos, salir sin mostrar nada
if [ -z "$artist" ] && [ -z "$title" ]; then
  exit 0
fi

full="$artist - $title"

# Limitar longitud
maxlen=40
short="$full"
if [ ${#short} -gt $maxlen ]; then
  short="${short:0:$maxlen}…"
fi

icon=""
[ "$status" = "Paused" ] && icon=""
[ "$status" = "Stopped" ] && icon=""

echo "$icon $short"
