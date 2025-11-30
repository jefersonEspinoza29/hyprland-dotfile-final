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

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(eval echo "~${TARGET_USER}")"
CONFIG_DIR="${TARGET_HOME}/.config"
REPO_DIR="$(pwd)"

echo "[+] Usuario destino: ${TARGET_USER}"
echo "[+] Home destino:   ${TARGET_HOME}"
echo "[+] Repo actual:    ${REPO_DIR}"
echo

# -----------------------------------------------------------------------------
# 1. Instalar git (si hace falta) y base-devel (para yay/brillo)
# -----------------------------------------------------------------------------
echo "[+] Instalando dependencias base (git, base-devel)..."
sudo pacman -S --needed git base-devel

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
chmod +x "${CONFIG_DIR}/eww/scripts/brightness_osd.sh"       2>/dev/null || true
chmod +x "${CONFIG_DIR}/eww/scripts/volume_osd.sh"           2>/dev/null || true
chmod +x "${CONFIG_DIR}/hypr/scripts/wallpaper.sh"           2>/dev/null || true
chmod +x "${CONFIG_DIR}/waybar/scripts/bluetooth-toggle.sh"  2>/dev/null || true
chmod +x "${CONFIG_DIR}/waybar/scripts/bluetooth-tray-toggle.sh" 2>/dev/null || true
chmod +x "${CONFIG_DIR}/waybar/scripts/gnome-calendar-toggle.sh" 2>/dev/null || true
chmod +x "${CONFIG_DIR}/waybar/scripts/nm-applet-toggle.sh"  2>/dev/null || true
chmod +x "${CONFIG_DIR}/waybar/scripts/playerctl.sh"         2>/dev/null || true

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
# -----------------------------------------------------------------------------
echo "[+] Instalando paquetes principales con pacman..."

sudo pacman -S --needed sddm hyprland kitty playerctl jq gsimplecal blueman gnome-calendar plymouth \
  brightnessctl firefox pavucontrol networkmanager mesa mesa-utils \
  intel-media-driver vulkan-intel libva-intel-driver \
  nvidia nvidia-utils nvidia-settings nvidia-prime vulkan-icd-loader \
  lib32-mesa lib32-nvidia-utils lib32-vulkan-intel lib32-vulkan-icd-loader

echo "[+] Habilitando SDDM y NetworkManager..."
sudo systemctl enable --now sddm
sudo systemctl enable --now NetworkManager

# -----------------------------------------------------------------------------
# 6. Paquetes AUR (yay)
# -----------------------------------------------------------------------------
echo "[+] Instalando paquetes AUR con yay..."
yay -S --needed swww eww matugen rofi waybar wlogout hyprshot plymouth-theme-Unrap-git auto-cpufreq

echo "[+] Habilitando auto-cpufreq..."
sudo systemctl enable --now auto-cpufreq.service

# -----------------------------------------------------------------------------
# 7. Configurar Plymouth: HOOKS de mkinitcpio
# -----------------------------------------------------------------------------
echo "[+] Configurando mkinitcpio para plymouth..."

if [ -f /etc/mkinitcpio.conf ]; then
  sudo cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak.$(date +%s)

  # Insertar 'plymouth' en HOOKS si no está presente
  sudo sed -i 's/^HOOKS=(\(.*\))/HOOKS=(\1)/' /etc/mkinitcpio.conf

  if ! grep -q "plymouth" /etc/mkinitcpio.conf; then
    # Intentar poner plymouth después de udev si existe
    sudo sed -i 's/HOOKS=(base udev /HOOKS=(base udev plymouth /' /etc/mkinitcpio.conf || true
    sudo sed -i 's/HOOKS=(udev /HOOKS=(udev plymouth /' /etc/mkinitcpio.conf || true
  fi

  echo "[+] Regenerando initramfs..."
  sudo mkinitcpio -P
else
  echo "[!] /etc/mkinitcpio.conf no encontrado, se omite configuración de plymouth."
fi

# -----------------------------------------------------------------------------
# 8. Configurar entradas de systemd-boot (quiet splash + blacklist NVIDIA)
# -----------------------------------------------------------------------------
echo "[+] Ajustando /boot/loader/entries (quiet splash + blacklist NVIDIA)..."

if [ -d /boot/loader/entries ]; then
  for entry in /boot/loader/entries/*.conf; do
    [ -f "$entry" ] || continue
    echo "  [+] Editando ${entry}"
    sudo sed -i '/^options /{
      /modprobe.blacklist=nvidia/! s/$/ quiet splash modprobe.blacklist=nvidia,nvidia_drm,nvidia_uvm,nvidia_modeset/
    }' "$entry"
  done
else
  echo "[!] Directorio /boot/loader/entries no encontrado, se omite este paso."
fi

# -----------------------------------------------------------------------------
# 9. Configurar tema de Plymouth y ShowDelay
# -----------------------------------------------------------------------------
echo "[+] Aplicando tema Plymouth 'unrap'..."
sudo plymouth-set-default-theme -R unrap

echo "[+] Ajustando /etc/plymouth/plymouthd.conf..."
if [ -f /etc/plymouth/plymouthd.conf ]; then
  sudo cp /etc/plymouth/plymouthd.conf /etc/plymouth/plymouthd.conf.bak.$(date +%s)
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
  sudo cp /boot/loader/loader.conf /boot/loader/loader.conf.bak.$(date +%s)
  if grep -q "^timeout" /boot/loader/loader.conf; then
    sudo sed -i 's/^timeout .*/timeout 0/' /boot/loader/loader.conf
  else
    echo "timeout 0" | sudo tee -a /boot/loader/loader.conf >/dev/null
  fi
else
  echo "[!] /boot/loader/loader.conf no encontrado, se omite este paso."
fi

# -----------------------------------------------------------------------------
# 11. Instalar brillo (control de brillo)
# -----------------------------------------------------------------------------
echo "[+] Instalando brillo (control de brillo por terminal)..."
cd "${TARGET_HOME}"
if [ ! -d "${TARGET_HOME}/brillo" ]; then
  git clone https://gitlab.com/cameronnemo/brillo.git
fi
cd brillo
make
sudo make install
sudo make install GROUP=video || true
sudo make install.setgid GROUP=video || true
cd "${REPO_DIR}"

# -----------------------------------------------------------------------------
# 12. Limpiar configs de Xorg de NVIDIA que rompen híbridas
# -----------------------------------------------------------------------------
echo "[+] Limpiando xorg.conf de NVIDIA (si existen)..."
sudo mv /etc/X11/xorg.conf /etc/X11/xorg.conf.bak 2>/dev/null || true
sudo mv /etc/X11/xorg.conf.nvidia-xconfig-original /etc/X11/xorg.conf.nvidia-xconfig-original.bak 2>/dev/null || true

# -----------------------------------------------------------------------------
# FIN
# -----------------------------------------------------------------------------
echo
echo "==============================================================="
echo "  Instalación completada."
echo "  - Dotfiles copiados a ${CONFIG_DIR}"
echo "  - Paquetes instalados (Hyprland, SDDM, etc.)"
echo "  - Plymouth configurado con tema 'unrap'"
echo "  - NVIDIA en modo offload con prime-run (blacklist en arranque)"
echo "==============================================================="
echo "Reinicia el sistema para aplicar todos los cambios."
