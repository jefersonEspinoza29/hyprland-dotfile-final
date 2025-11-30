# proyecto-hyprland-final 🌱🚀

Dotfiles + script de instalación para dejar un entorno **Hyprland** listo en Arch Linux, con:

- **Hyprland** como compositor Wayland.
- **SDDM** como display manager.
- **Waybar**, **eww**, **rofi**, **wlogout**, **kitty**, etc.
- **Plymouth** con tema `unrap`.
- Soporte para GPUs **Intel + NVIDIA híbrida** con `prime-run`.
- Ajustes de brillo, auto-cpufreq, NetworkManager, etc.

> ⚠️ Este repo está pensado para **Arch Linux** con **systemd-boot** y una laptop híbrida Intel + NVIDIA (RTX 3060 en mi caso).  
> Si tu setup es distinto, revisa el script antes de ejecutarlo.

---

## 📁 Contenido del repositorio

Este repo contiene principalmente mis configuraciones en `~/.config`:

- `eww` – widgets (OSD de brillo/volumen, etc.)
- `gsimplecal` – calendario ligero.
- `hypr` – configuración de Hyprland.
- `kitty` – terminal.
- `matugen` – esquema de colores.
- `rofi` – launcher.
- `waybar` – barra superior.
- `wlogout` – pantalla de logout.

Y un script de instalación:

- `install.sh` – configura el entorno gráfico, instala paquetes, copia dotfiles y ajusta el arranque.

---

## 🛠 Requisitos

- **Arch Linux** (o derivado muy cercano).
- Bootloader: **systemd-boot** (usa `/boot/loader/entries`).
- GPU híbrida **Intel + NVIDIA** (usa `nvidia-prime` / `prime-run`).
- Conexión a internet.
- Usuario con permisos `sudo`.

---

## ⚙️ Qué hace `install.sh`

En resumen, el script:

1. **Instala dependencias base**:
   - `git`, `base-devel` (para compilar AUR y brillo).

2. **Copia tus dotfiles a `~/.config`**:
   - Copia y hace backup previo de:
     - `eww`, `gsimplecal`, `hypr`, `kitty`, `matugen`, `rofi`, `waybar`, `wlogout`.
   - Ajusta permisos de scripts:
     - `~/.config/eww/scripts/brightness_osd.sh`
     - `~/.config/eww/scripts/volume_osd.sh`
     - `~/.config/hypr/scripts/wallpaper.sh`
     - Scripts de `~/.config/waybar/scripts/…`

3. **Instala `yay`** si no existe:
   - Clona desde AUR y compila.

4. **Instala paquetes con `pacman`**:
   - **Display manager y WM**:
     - `sddm`, `hyprland`
   - **Terminal y utilidades**:
     - `kitty`, `playerctl`, `jq`, `gsimplecal`, `blueman`, `gnome-calendar`
   - **Plymouth**:
     - `plymouth`
   - **Sonido / red / brillo**:
     - `brightnessctl`, `pavucontrol`, `networkmanager`
   - **Drivers Intel**:
     - `mesa`, `mesa-utils`, `intel-media-driver`, `vulkan-intel`, `libva-intel-driver`
   - **Drivers NVIDIA**:
     - `nvidia`, `nvidia-utils`, `nvidia-settings`, `nvidia-prime`, `vulkan-icd-loader`
   - **Soporte 32 bits (juegos/Steam/Proton)**:
     - `lib32-mesa`, `lib32-nvidia-utils`, `lib32-vulkan-intel`, `lib32-vulkan-icd-loader`
   - Habilita:
     - `sddm`
     - `NetworkManager`

5. **Instala paquetes AUR con `yay`**:
   - `swww`
   - `eww`
   - `matugen`
   - `rofi`
   - `waybar`
   - `wlogout`
   - `hyprshot`
   - `plymouth-theme-Unrap-git`
   - `auto-cpufreq`
   - Habilita `auto-cpufreq.service`.

6. **Configura Plymouth**:
   - Añade `plymouth` a los `HOOKS` en `/etc/mkinitcpio.conf` (dejando backup).
   - Regenera initramfs: `mkinitcpio -P`.
   - Establece tema:
     - `plymouth-set-default-theme -R unrap`
   - Escribe `/etc/plymouth/plymouthd.conf` con:
     ```ini
     [Daemon]
     Theme=unrap
     ShowDelay=0
     ```

7. **Configura systemd-boot**:
   - Edita todos los archivos en `/boot/loader/entries/*.conf` para añadir a la línea `options`:
     ```text
     quiet splash modprobe.blacklist=nvidia,nvidia_drm,nvidia_uvm,nvidia_modeset
     ```
   - Esto hace:
     - Boot silencioso con splash de Plymouth.
     - Blacklist de módulos NVIDIA en el arranque → evita pantallazo negro, pero puedes usar `prime-run`.
   - Ajusta `/boot/loader/loader.conf`:
     - `timeout 0`

8. **Instala y configura `brillo`** (control de brillo desde terminal):
   - Clona `https://gitlab.com/cameronnemo/brillo.git`
   - `make && sudo make install`
   - Permisos con grupo `video` (`make install GROUP=video`, `make install.setgid GROUP=video`).

9. **Limpia configs peligrosas de Xorg para NVIDIA**:
   - Renombra (si existen):
     - `/etc/X11/xorg.conf`
     - `/etc/X11/xorg.conf.nvidia-xconfig-original`
   - Así evitas que Xorg fuerce NVIDIA como pantalla principal y rompa SDDM.

---

## 🚀 Instalación rápida

> ⚠️ Importante: revisa el script antes de ejecutarlo, especialmente si tu hardware/bootloader es distinto.

```bash
# 1. Clonar el repo
git clone https://github.com/jefersonEspinoza29/proyecto-hyprland-final
cd proyecto-hyprland-final

# 2. Dar permisos al script
chmod +x install.sh

# 3. Ejecutar como usuario normal (NO root)
./install.sh

# 4. Reiniciar al terminar
reboot
