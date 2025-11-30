#!/usr/bin/env bash

# Si blueman-applet ya está corriendo, lo cerramos (oculta el icono)
if pgrep -x blueman-applet >/dev/null; then
    pkill -x blueman-applet
    exit 0
fi

# Si no está corriendo, lo arrancamos (muestra el icono en el tray)
blueman-applet & disown
