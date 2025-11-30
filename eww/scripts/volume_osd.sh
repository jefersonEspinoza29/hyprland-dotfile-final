#!/usr/bin/env bash

STEP=5          # pasos de volumen en %
HIDE_AFTER=1.0  # segundos visible
TIMER_FILE="/tmp/volume_osd_timer.pid"

ACTION="$1"

case "$ACTION" in
  up)
    pamixer -i "$STEP"
    ;;
  down)
    pamixer -d "$STEP"
    ;;
  mute)
    pamixer -t
    ;;
  *)
    echo "Uso: $0 up|down|mute"
    exit 1
    ;;
esac

# Obtener volumen actual y estado de mute
vol=$(pamixer --get-volume 2>/dev/null)
muted=$(pamixer --get-mute 2>/dev/null)

if [ "$muted" = "true" ]; then
  level=0
else
  level="$vol"
fi

# Limitar entre 0 y 100 por si acaso
if [ "$level" -lt 0 ]; then level=0; fi
if [ "$level" -gt 100 ]; then level=100; fi

# Actualizar Eww
eww update volume-level="$level"
eww open volume-osd

# Cancelar temporizador anterior
if [ -f "$TIMER_FILE" ]; then
  old_pid=$(cat "$TIMER_FILE")
  if kill -0 "$old_pid" 2>/dev/null; then
    kill "$old_pid" 2>/dev/null
  fi
fi

# Nuevo temporizador
(
  sleep "$HIDE_AFTER"
  eww close volume-osd
) &

echo $! > "$TIMER_FILE"
