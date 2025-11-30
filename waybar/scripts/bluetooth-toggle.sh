#!/usr/bin/env bash

# Si la ventana de Blueman ya está abierta, la cerramos
if pgrep -x blueman-manager >/dev/null; then
    pkill -x blueman-manager
    exit 0
fi

# Si no está abierta, la lanzamos
blueman-manager & disown
