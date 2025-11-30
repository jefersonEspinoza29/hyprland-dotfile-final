#!/usr/bin/env bash

STEP=5          # cuánto sube/baja cada vez
HIDE_AFTER=1.0  # segundos visible
TIMER_FILE="/tmp/brightness_osd_timer.pid"

DIR="$1"

# Cambiar brillo con brillo
case "$DIR" in
  up)
    brillo -A "$STEP"
    ;;
  down)
    brillo -U "$STEP"
    ;;
  *)
    echo "Uso: $0 up|down"
    exit 1
    ;;
esac

# Leer brillo actual (entero)
current=$(brillo -G 2>/dev/null)
current=${current%.*}

# Actualizar Eww
eww update brightness-level="$current"
eww open brightness-osd

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
  eww close brightness-osd
) &

echo $! > "$TIMER_FILE"
