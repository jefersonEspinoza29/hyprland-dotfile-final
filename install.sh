#!/usr/bin/env bash
set -e

############################################
# VARIABLES
############################################
USER_NAME="${SUDO_USER:-$USER}"
HOME_DIR="/home/${USER_NAME}"
REPO_DIR="$(pwd)"
CONFIG_DIR="${HOME_DIR}/.config"
BACKUP_DIR="${HOME_DIR}/.config_backup_$(date +%Y%m%d_%H%M%S)"

############################################
# FUNCIONES
############################################
info() { echo -e "\e[1;34m[INFO]\e[0m $1"; }
warn() { echo -e "\e[1;33m[WARN]\e[0m $1"; }

############################################
# VALIDACIONES
############################################
if [[ "$EUID" -eq 0 ]]; then
  echo "No ejecutes este script como root. Usa un usuario normal."; exit 1
fi

############################################
# ACTUALIZAR SISTEMA
############################################
info "Actualizando sistema"
sudo pacman -Syyu --noconfirm

############################################
# INSTALAR YAY
############################################
info "Instalando yay"
sudo pacman -S --needed --noconfirm git base-devel
if ! command -v yay &>/dev/null; then
  cd /tmp
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
fi
cd "${REPO_DIR}"

############################################
# PAQUETES BASE
############################################
info "Instalando paquetes base"
sudo pacman -S --noconfirm hyprland sddm kitty playerctl jq gnome-calendar blueman plymouth go-md2man dolphin gsimplecal networkmanager brightnessctl pavucontrol network-manager-applet firefox code noto-fonts noto-fonts-emoji noto-fonts-extra ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols otf-font-awesome

############################################
# DRIVERS INTEL
############################################
info "Instalando drivers Intel"
sudo pacman -S --noconfirm \
  mesa lib32-mesa \
  vulkan-intel lib32-vulkan-intel vulkan-icd-loader lib32-vulkan-icd-loader intel-media-driver libva-utils mesa-demos vulkan-tools intel-gpu-tools

sudo pacman -Rns --noconfirm xf86-video-intel || true

############################################
# NVIDIA
############################################
info "Instalando NVIDIA"
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils nvidia-settings nvidia-prime

############################################
# BLACKLIST NOUVEAU
############################################
info "Desactivando nouveau"
sudo tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null <<EOF
blacklist nouveau
options nouveau modeset=0
EOF

############################################
# MKINITCPIO
############################################
info "Configurando mkinitcpio"
sudo sed -i 's/^MODULES=.*/MODULES=(nvidia_drm)/' /etc/mkinitcpio.conf
sudo sed -i 's/^HOOKS=.*/HOOKS=(base udev plymouth autodetect modconf block filesystems keyboard fsck)/' /etc/mkinitcpio.conf

############################################
# PLYMOUTH
############################################
info "Instalando tema Plymouth"
yay -S --noconfirm plymouth-theme-unrap-git
sudo plymouth-set-default-theme -R unrap

############################################
# SYSTEMD-BOOT
############################################
info "Configurando systemd-boot"
BOOT_ENTRY=$(ls /boot/loader/entries/*.conf | head -n1)

sudo sed -i 's/$/ quiet splash rd.blacklist=nouveau modprobe.blacklist=nouveau nvidia_drm.modeset=1/' "$BOOT_ENTRY"

sudo tee /boot/loader/loader.conf >/dev/null <<EOF
default arch
timeout 0
EOF

sudo mkinitcpio -P

############################################
# DOTFILES
############################################
info "Copiando dotfiles"
mkdir -p "$BACKUP_DIR"

for dir in eww gsimplecal hypr kitty matugen rofi sources waybar wlogout; do
  if [[ -d "${CONFIG_DIR}/${dir}" ]]; then
    mv "${CONFIG_DIR}/${dir}" "$BACKUP_DIR"
  fi
  cp -r "${REPO_DIR}/${dir}" "$CONFIG_DIR"
done

############################################
# PERMISOS
############################################
info "Aplicando permisos"
chmod +x "${CONFIG_DIR}/eww/scripts/brightness_osd.sh" 2>/dev/null || true
chmod +x "${CONFIG_DIR}/eww/scripts/volume_osd.sh" 2>/dev/null || true
chmod +x "${CONFIG_DIR}/hypr/scripts/wallpaper.sh" 2>/dev/null || true
chmod +x "${CONFIG_DIR}/waybar/scripts/"*.sh 2>/dev/null || true

############################################
# WALLPAPERS
############################################
info "Instalando wallpapers"
mkdir -p "${HOME_DIR}/imagenes/wallpapers"
cp -r "${CONFIG_DIR}/sources/wallpapers"/* "${HOME_DIR}/imagenes/wallpapers" || true

############################################
# AUR APPS
############################################
info "Instalando apps AUR"
yay -S --noconfirm matugen rofi waybar wlogout eww hyprshot swww auto-cpufreq

sudo systemctl enable --now auto-cpufreq || sudo systemctl enable --now auto-cpufreq.service

############################################
# BRILLO
############################################
info "Instalando brillo"
BRILLO_BUILD_DIR="$(mktemp -d)"
(
  cd "$BRILLO_BUILD_DIR"
  git clone https://gitlab.com/cameronnemo/brillo.git
  cd brillo
  make
  sudo make install
  sudo make install GROUP=video || true
  sudo make install.setgid GROUP=video || true
)
rm -rf "$BRILLO_BUILD_DIR"

############################################
# FINAL
############################################
info "Instalación completada. Reinicia el sistema."
