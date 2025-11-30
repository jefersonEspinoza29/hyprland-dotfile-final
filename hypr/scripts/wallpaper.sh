#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/imagenes/wallpapers"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
LAST_FILE="$CACHE_DIR/last_wallpaper_swww"

# Asegura que exista el directorio de caché
mkdir -p "$CACHE_DIR"

# Levanta el daemon si no está corriendo
if ! pgrep -x "swww-daemon" >/dev/null; then
    swww-daemon --namespace wayland-1 &
    # dale un toque de tiempo para iniciar
    sleep 1
fi

# Leer último wallpaper (si existe)
LAST_WALLPAPER=""
if [ -f "$LAST_FILE" ]; then
    LAST_WALLPAPER="$(cat "$LAST_FILE")"
fi

# Elegir un nuevo wallpaper distinto del anterior
while :; do
    WALLPAPER="$(find "$WALLPAPER_DIR" -type f | shuf -n 1)"
    # si solo hay uno, o ya es distinto, salimos
    [ "$WALLPAPER" != "$LAST_WALLPAPER" ] && break
done

# Transición suave con swww
swww img "$WALLPAPER" \
    --namespace wayland-1 \
    --transition-type fade \
    --transition-duration 4 \
    --transition-step 20 \
    --transition-fps 60 \
    --resize crop

# Guardar el último wallpaper usado
echo "$WALLPAPER" > "$LAST_FILE"

# Espera un poco antes de generar la paleta
sleep 2

# Genera los colores con Matugen
matugen image "$WALLPAPER" --mode dark
