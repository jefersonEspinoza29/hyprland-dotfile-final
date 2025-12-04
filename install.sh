#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Instalador de entorno Hyprland + SDDM + dotfiles de Jheff
# Ejecutar como USUARIO normal (NO root) dentro del repo proyecto-hyprland-final
# -----------------------------------------------------------------------------

if [ "$EUID" -eq 0 ]; then
  echo "Por favor ejecuta este script como usuario normal, no como root."
  exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
  echo "Este script está pensado para Arch Linux o derivados con pacman."
  exit 1
fi

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(eval echo "~${TARGET_USER}")"
CONFIG_DIR="${TARGET_HOME}/.config"
REPO_DIR="$(pwd)"

echo "[+] Usuario destino: ${TARGET_USER}"
echo "[+] Home destino:   ${TARGET_HOME}"
echo "[+] Repo actual:    ${REPO_DIR}"
echo

# -----------------------------------------------------------------------------
# 1. Instalar git, base-devel y go-md2man (para yay / AUR)
# -----------------------------------------------------------------------------
echo "[+] Instalando dependencias base (git, base-devel, go-md2man)..."
sudo pacman -S --needed --noconfirm git base-devel go-md2man

# -----------------------------------------------------------------------------
# 2. Copiar dotfiles a ~/.config (con backup si ya existen)
# -----------------------------------------------------------------------------
mkdir -p "${CONFIG_DIR}"

copy_config_dir() {
  local name="$1"
  if [ -d "${CONFIG_DIR}/${name}" ]; then
    local backup="${CONFIG_DIR}/${name}.bak.$(date +%s)"
    echo "  [*] Backup de ${name} → ${backup}"
    mv "${CONFIG_DIR}/${name}" "${backup}"
  fi

  if [ -d "${REPO_DIR}/${name}" ]; then
    echo "  [+] Copiando ${name} → ${CONFIG_DIR}/${name}"
    cp -r "${REPO_DIR}/${name}" "${CONFIG_DIR}/"
  else
    echo "  [!] Ojo: en el repo NO existe la carpeta ${name}, se omite."
  fi
}

echo "[+] Copiando configuraciones a ~/.config..."
for d in eww gsimplecal hypr kitty matugen rofi waybar wlogout; do
  copy_config_dir "${d}"
done

# -----------------------------------------------------------------------------
# 3. Permisos de ejecución en scripts de eww / hypr / waybar
# -----------------------------------------------------------------------------
echo "[+] Ajustando permisos de scripts..."
chmod +x "${CONFIG_DIR}/eww/scripts/brightness_osd.sh"            2>/dev/null || true
chmod +x "${CONFIG_DIR}/eww/scripts/volume_osd.sh"                2>/dev/null || true
chmod +x "${CONFIG_DIR}/hypr/scripts/wallpaper.sh"                2>/dev/null || true
chmod +x "${CONFIG_DIR}/waybar/scripts/bluetooth-toggle.sh"       2>/dev/null || true
chmod +x "${CONFIG_DIR}/waybar/scripts/bluetooth-tray-toggle.sh"  2>/dev/null || true
chmod +x "${CONFIG_DIR}/waybar/scripts/gnome-calendar-toggle.sh"  2>/dev/null || true
chmod +x "${CONFIG_DIR}/waybar/scripts/nm-applet-toggle.sh"       2>/dev/null || true
chmod +x "${CONFIG_DIR}/waybar/scripts/playerctl.sh"              2>/dev/null || true

# -----------------------------------------------------------------------------
# 3.5. Wallpapers: crear carpeta ~/imagenes/wallpapers y copiar desde el repo
# -----------------------------------------------------------------------------
echo "[+] Configurando carpeta de wallpapers..."

WALLPAPER_DEST_DIR="${TARGET_HOME}/imagenes/wallpapers"
mkdir -p "${WALLPAPER_DEST_DIR}"

WALLPAPER_SRC_DIR=""

if [ -d "${REPO_DIR}/sources/wallpapers" ]; then
  WALLPAPER_SRC_DIR="${REPO_DIR}/sources/wallpapers"
elif [ -d "${REPO_DIR}/wallpapers" ]; then
  WALLPAPER_SRC_DIR="${REPO_DIR}/wallpapers"
fi

if [ -n "${WALLPAPER_SRC_DIR}" ]; then
  echo "  [+] Copiando wallpapers desde ${WALLPAPER_SRC_DIR} → ${WALLPAPER_DEST_DIR}"
  cp -r "${WALLPAPER_SRC_DIR}/." "${WALLPAPER_DEST_DIR}/"
else
  echo "  [!] No se encontró carpeta de wallpapers en el repo (sources/wallpapers o wallpapers)."
  echo "      El script de wallpaper usará ${WALLPAPER_DEST_DIR}, pero está vacío por ahora."
fi

# -----------------------------------------------------------------------------
# 4. Instalar yay (si no existe)
# -----------------------------------------------------------------------------
if ! command -v yay >/dev/null 2>&1; then
  echo "[+] yay no encontrado, instalando..."
  cd "${TARGET_HOME}"
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd "${REPO_DIR}"
else
  echo "[+] yay ya está instalado."
fi

# -----------------------------------------------------------------------------
# 5. Paquetes principales (pacman)
#    Incluye: Hyprland, SDDM, Firefox, VS Code, Dolphin, drivers Intel+NVIDIA, layer-shell-qt5
# -----------------------------------------------------------------------------
echo "[+] Instalando paquetes principales con pacman..."

sudo pacman -S --needed --noconfirm \
  sddm hyprland kitty dolphin playerctl jq gsimplecal blueman gnome-calendar plymouth \
  brightnessctl pavucontrol networkmanager network-manager-applet \
  firefox code pamixer \
  mesa mesa-utils \
  intel-media-driver vulkan-intel libva-intel-driver \
  nvidia nvidia-utils nvidia-settings nvidia-prime vulkan-icd-loader \
  lib32-mesa lib32-nvidia-utils lib32-vulkan-intel lib32-vulkan-icd-loader \
  layer-shell-qt5 \
  noto-fonts noto-fonts-emoji noto-fonts-extra \
  ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols otf-font-awesome

echo "[+] Habilitando SDDM y NetworkManager..."
sudo systemctl enable --now sddm
sudo systemctl enable --now NetworkManager

echo "[+] Actualizando caché de fuentes..."
sudo fc-cache -fv || true

# -----------------------------------------------------------------------------
# 5.5. Configurar KMS de NVIDIA (nvidia_drm.modeset=1 via modprobe)
# -----------------------------------------------------------------------------
echo "[+] Configurando KMS para NVIDIA (nvidia_drm.modeset=1)..."

sudo mkdir -p /etc/modprobe.d
if [ -f /etc/modprobe.d/nvidia_drm.conf ]; then
  sudo cp /etc/modprobe.d/nvidia_drm.conf "/etc/modprobe.d/nvidia_drm.conf.bak.$(date +%s)"
fi

sudo bash -c 'cat >/etc/modprobe.d/nvidia_drm.conf' <<'EOF'
options nvidia_drm modeset=1
EOF

# -----------------------------------------------------------------------------
# 6. Paquetes AUR (yay) – incluye sddm-astronaut-theme y auto-cpufreq
# -----------------------------------------------------------------------------
echo "[+] Instalando paquetes AUR con yay..."
yay -S --needed --noconfirm \
  swww eww matugen rofi waybar wlogout hyprshot \
  plymouth-theme-Unrap-git auto-cpufreq \
  sddm-astronaut-theme

echo "[+] Habilitando auto-cpufreq..."
sudo systemctl enable --now auto-cpufreq || sudo systemctl enable --now auto-cpufreq.service

# -----------------------------------------------------------------------------
# 6.5. Instalar sddm-hyprland (SDDM Wayland sobre Hyprland)
# -----------------------------------------------------------------------------
echo "[+] Instalando sddm-hyprland (SDDM sobre Hyprland compositor)..."

SDDM_HYPRLAND_BUILD_DIR="$(mktemp -d)"
(
  cd "${SDDM_HYPRLAND_BUILD_DIR}"
  git clone https://github.com/HyDE-Project/sddm-hyprland.git
  cd sddm-hyprland
  sudo make install
)
rm -rf "${SDDM_HYPRLAND_BUILD_DIR}" || true

# -----------------------------------------------------------------------------
# 7. Configurar mkinitcpio para plymouth (HOOKS robusto, sin romper sintaxis)
# -----------------------------------------------------------------------------
echo "[+] Configurando mkinitcpio para plymouth..."

if [ -f /etc/mkinitcpio.conf ]; then
  sudo cp /etc/mkinitcpio.conf "/etc/mkinitcpio.conf.bak.$(date +%s)"

  sudo bash -c '
cfg=/etc/mkinitcpio.conf

# Cargar la línea HOOKS= como array
eval "$(grep -E "^HOOKS=" "$cfg")" || true

# Si no hay HOOKS definidos, no hacemos nada
if [ -z "${HOOKS[*]:-}" ]; then
  echo "[mkinitcpio] No se encontró línea HOOKS=, se omite inserción de plymouth."
  exit 0
fi

# Comprobar si ya existe plymouth
for h in "${HOOKS[@]}"; do
  if [ "$h" = "plymouth" ]; then
    echo "[mkinitcpio] plymouth ya está en HOOKS, no se modifica."
    exit 0
  fi
done

new=()
inserted=0
for h in "${HOOKS[@]}"; do
  new+=("$h")
  if [ "$h" = "udev" ] && [ $inserted -eq 0 ]; then
    new+=("plymouth")
    inserted=1
  fi
done

# Si no había udev, lo agregamos al final
if [ $inserted -eq 0 ]; then
  new+=("plymouth")
fi

line="HOOKS=("
for h in "${new[@]}"; do
  line="$line$h "
done
line="${line% }"
line="$line)"

sed -i "s/^HOOKS=.*/$line/" "$cfg"
'

  echo "[+] Regenerando initramfs (mkinitcpio -P)..."
  sudo mkinitcpio -P
else
  echo "[!] /etc/mkinitcpio.conf no encontrado, se omite configuración de plymouth."
fi

# -----------------------------------------------------------------------------
# 8. Configurar entradas de systemd-boot (quiet splash + nvidia_drm.modeset=1)
# -----------------------------------------------------------------------------
echo "[+] Ajustando /boot/loader/entries (quiet, splash, nvidia_drm.modeset=1)..."

if [ -d /boot/loader/entries ]; then
  for entry in /boot/loader/entries/*.conf; do
    [ -f "$entry" ] || continue
    echo "  [+] Editando ${entry}"

    # Eliminar posibles blacklist antiguos de NVIDIA de ejecuciones previas
    sudo sed -i 's/modprobe.blacklist=nvidia,nvidia_drm,nvidia_uvm,nvidia_modeset//g' "$entry"

    # Asegurar quiet
    sudo sed -i '/^options /{
      / quiet /! s/$/ quiet/
    }' "$entry"

    # Asegurar splash
    sudo sed -i '/^options /{
      / splash /! s/$/ splash/
    }' "$entry"

    # Asegurar nvidia_drm.modeset=1
    sudo sed -i '/^options /{
      /nvidia_drm.modeset=1/! s/$/ nvidia_drm.modeset=1/
    }' "$entry"

    # Compactar espacios múltiples
    sudo sed -i 's/  \+/ /g' "$entry"
  done
else
  echo "[!] Directorio /boot/loader/entries no encontrado, se omite este paso (¿no usas systemd-boot?)."
fi

# -----------------------------------------------------------------------------
# 9. Configurar tema de Plymouth y ShowDelay
# -----------------------------------------------------------------------------
echo "[+] Aplicando tema Plymouth 'unrap'..."
sudo plymouth-set-default-theme -R unrap

echo "[+] Ajustando /etc/plymouth/plymouthd.conf..."
if [ -f /etc/plymouth/plymouthd.conf ]; then
  sudo cp /etc/plymouth/plymouthd.conf "/etc/plymouth/plymouthd.conf.bak.$(date +%s)"
fi

sudo bash -c 'cat >/etc/plymouth/plymouthd.conf' <<'EOF'
[Daemon]
Theme=unrap
ShowDelay=0
# Administrator customizations go in this file
#[Daemon]
#Theme=fade-in
EOF

echo "[+] Regenerando initramfs nuevamente por cambios en plymouth..."
sudo mkinitcpio -P

# -----------------------------------------------------------------------------
# 10. Ajustar timeout del cargador de arranque (systemd-boot)
# -----------------------------------------------------------------------------
echo "[+] Ajustando timeout de systemd-boot..."
if [ -f /boot/loader/loader.conf ]; then
  sudo cp /boot/loader/loader.conf "/boot/loader/loader.conf.bak.$(date +%s)"
  if grep -q "^timeout" /boot/loader/loader.conf; then
    sudo sed -i 's/^timeout .*/timeout 0/' /boot/loader/loader.conf
  else
    echo "timeout 0" | sudo tee -a /boot/loader/loader.conf >/dev/null
  fi
else
  echo "[!] /boot/loader/loader.conf no encontrado, se omite este paso."
fi

# -----------------------------------------------------------------------------
# 11. Instalar brillo (control de brillo) en directorio temporal
# -----------------------------------------------------------------------------
echo "[+] Instalando brillo (control de brillo por terminal)..."
BRILLO_BUILD_DIR="$(mktemp -d)"
(
  cd "${BRILLO_BUILD_DIR}"
  git clone https://gitlab.com/cameronnemo/brillo.git
  cd brillo
  make
  sudo make install
  sudo make install GROUP=video || true
  sudo make install.setgid GROUP=video || true
)
rm -rf "${BRILLO_BUILD_DIR}" || true
cd "${REPO_DIR}"

# -----------------------------------------------------------------------------
# 12. Limpiar configs de Xorg de NVIDIA que rompen híbridas
# -----------------------------------------------------------------------------
echo "[+] Limpiando xorg.conf de NVIDIA (si existen)..."
sudo mv /etc/X11/xorg.conf /etc/X11/xorg.conf.bak 2>/dev/null || true
sudo mv /etc/X11/xorg.conf.nvidia-xconfig-original /etc/X11/xorg.conf.nvidia-xconfig-original.bak 2>/dev/null || true

# -----------------------------------------------------------------------------
# 13. Configurar tema SDDM 'sddm-astronaut-theme' (ya instalado por AUR)
# -----------------------------------------------------------------------------
echo "[+] Configurando SDDM para usar el tema 'sddm-astronaut-theme'..."
sudo bash -c 'cat >/etc/sddm.conf' <<'EOF'
[Theme]
Current=sddm-astronaut-theme

[General]
InputMethod=qtvirtualkeyboard
EOF

echo "[+] Refrescando caché de fuentes (tema SDDM)..."
sudo fc-cache -fv || true

# -----------------------------------------------------------------------------
# FIN
# -----------------------------------------------------------------------------
echo
echo "==============================================================="
echo "  Instalación completada."
echo "  - Dotfiles copiados a ${CONFIG_DIR}"
echo "  - Wallpapers copiados a ${TARGET_HOME}/imagenes/wallpapers"
echo "  - Paquetes instalados (Hyprland, SDDM, Firefox, VS Code, Dolphin, etc.)"
echo "  - NVIDIA con KMS (nvidia_drm.modeset=1) y sin blacklist"
echo "  - auto-cpufreq instalado y habilitado"
echo "  - sddm-hyprland instalado (SDDM sobre Hyprland Wayland)"
echo "  - Plymouth configurado con tema 'unrap'"
echo "  - SDDM usando tema 'sddm-astronaut-theme'"
echo "  - Fuentes para Waybar e iconos instaladas (Nerd Fonts + Font Awesome + Noto)"
echo "  - pamixer instalado para el control de volumen con OSD de Eww"
echo "==============================================================="
echo "Reinicia el sistema para aplicar todos los cambios."
