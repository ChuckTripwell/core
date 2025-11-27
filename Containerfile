FROM docker.io/cachyos/cachyos-v3:latest

ENV DRACUT_NO_XATTR=1

########################################################################################################################################
# 
########################################################################################################################################

# Move everything from `/var` to `/usr/lib/sysimage` so behavior around pacman remains the same on `bootc usroverlay`'d systems
RUN grep "= */var" /etc/pacman.conf | sed "/= *\/var/s/.*=// ; s/ //" | xargs -n1 sh -c 'mkdir -p "/usr/lib/sysimage/$(dirname $(echo $1 | sed "s@/var/@@"))" && mv -v "$1" "/usr/lib/sysimage/$(echo "$1" | sed "s@/var/@@")"' '' && \
    sed -i -e "/= *\/var/ s/^#//" -e "s@= */var@= /usr/lib/sysimage@g" -e "/DownloadUser/d" /etc/pacman.conf

# Initialize the database
RUN pacman -Sy --noconfirm

# Use the Arch mirrorlist that will be best at the moment for both the containerfile and user too! Fox will help!
RUN pacman -S --noconfirm reflector

RUN pacman -S --noconfirm cachyos-mirrorlist cachyos-v3-mirrorlist cachyos-v4-mirrorlist
RUN pacman -Syyu --noconfirm


# Use the Arch mirrorlist that will be best at the moment for both the containerfile and user too! Fox will help!
RUN pacman -S --noconfirm reflector

# Base packages \ Linux Foundation \ Foss is love, foss is life! We split up packages by category for readability, debug ease, and less dependency trouble
RUN pacman -S --noconfirm base dracut linux-cachyos-bore linux-firmware ostree systemd btrfs-progs e2fsprogs xfsprogs binutils dosfstools skopeo dbus dbus-glib glib2 shadow

# Media/Install utilities/Media drivers
RUN pacman -S --noconfirm librsvg libglvnd qt6-multimedia-ffmpeg plymouth acpid ddcutil dmidecode mesa-utils ntfs-3g \
      vulkan-tools wayland-utils playerctl

# Fonts
RUN pacman -S --noconfirm noto-fonts noto-fonts-cjk noto-fonts-emoji unicode-emoji noto-fonts-extra ttf-fira-code ttf-firacode-nerd \
      ttf-ibm-plex ttf-jetbrains-mono-nerd otf-font-awesome ttf-jetbrains-mono gnu-free-fonts awesome-terminal-fonts

# CLI Utilities
RUN pacman -S --noconfirm sudo bash bash-completion fastfetch btop jq less lsof nano openssh powertop man-db wget yt-dlp \
      tree usbutils vim wl-clipboard unzip ptyxis glibc-locales tar udev starship tuned-ppd tuned hyfetch curl

# Virtualization
RUN pacman -S --noconfirm distrobox docker podman

# Drivers \ "Business, business, business! Numbersss."
RUN pacman -S --noconfirm amd-ucode intel-ucode efibootmgr shim mesa lib32-mesa libva-intel-driver libva-mesa-driver \
      vpl-gpu-rt vulkan-icd-loader vulkan-intel vulkan-radeon apparmor xf86-video-amdgpu lib32-vulkan-radeon 

# Network / VPN / SMB / storage
RUN pacman -S --noconfirm libmtp networkmanager-openconnect networkmanager-openvpn nss-mdns samba smbclient networkmanager firewalld udiskie

# Accessibility
RUN pacman -S --noconfirm espeak-ng orca

# Pipewire
RUN pacman -S --noconfirm pipewire pipewire-pulse pipewire-zeroconf pipewire-ffado pipewire-libcamera sof-firmware wireplumber

# Printer
#RUN pacman -S --noconfirm cups cups-browsed hplip

# Desktop Environment needs
RUN pacman -S --noconfirm greetd xwayland-satellite greetd-regreet xdg-desktop-portal-kde xdg-desktop-portal xdg-user-dirs xdg-desktop-portal-gnome \
      ffmpegthumbs kdegraphics-thumbnailers kdenetwork-filesharing kio-admin chezmoi matugen accountsservice quickshell dgop cliphist cava dolphin \ 
      breeze brightnessctl wlsunset ddcutil xdg-utils kservice5 archlinux-xdg-menu shared-mime-info kio glycin

# User frontend programs/apps
RUN pacman -S --noconfirm steam gamescope scx-scheds scx-manager gnome-disk-utility mangohud

RUN pacman -S --clean

##############################################
# isolated distrobox homes
#
RUN mkdir -p /etc/distrobox/
RUN touch /etc/distrobox/distrobox.conf
RUN echo "DBX_CONTAINER_HOME_PREFIX=$HOME/distrobox" >> /etc/distrobox/distrobox.conf
##############################################

########################################################################################################################################
# 
########################################################################################################################################

RUN pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com

RUN pacman-key --init && pacman-key --lsign-key 3056513887B78AEB

RUN pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --noconfirm

RUN pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm

RUN echo -e '[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' >> /etc/pacman.conf

RUN pacman -Sy --noconfirm

RUN pacman -S \
      chaotic-aur/flatpak-git chaotic-aur/ttf-twemoji chaotic-aur/ttf-symbola chaotic-aur/opentabletdriver chaotic-aur/paru \
      --noconfirm

########################################################################################################################################
# 
########################################################################################################################################

RUN mkdir -p /usr/share/flatpak/preinstall.d/

# Bazaar
RUN echo -e "[Flatpak Preinstall io.github.kolunmi.Bazaar]\nBranch=stable\nIsRuntime=false" > /usr/share/flatpak/preinstall.d/Bazaar.preinstall

# Systemd flatpak preinstall service, thanks Aurora
RUN echo -e '[Unit]\n\
Description=Preinstall Flatpaks\n\
After=network-online.target\n\
Wants=network-online.target\n\
ConditionPathExists=/usr/bin/flatpak\n\
Documentation=man:flatpak-preinstall(1)\n\
\n\
[Service]\n\
Type=oneshot\n\
ExecStart=/usr/bin/flatpak preinstall -y\n\
RemainAfterExit=true\n\
Restart=on-failure\n\
RestartSec=30\n\
\n\
StartLimitIntervalSec=600\n\
StartLimitBurst=3\n\
\n\
[Install]\n\
WantedBy=multi-user.target' > /usr/lib/systemd/system/flatpak-preinstall.service

RUN systemctl enable flatpak-preinstall.service

########################################################################################################################################
# 
########################################################################################################################################

# Place XeniaOS logo at plymouth folder location to appear on boot and shutdown.
#RUN mkdir -p /etc/plymouth && \
#      echo -e '[Daemon]\nTheme=spinner' | tee /etc/plymouth/plymouthd.conf && \
#      wget --tries=5 -O /usr/share/plymouth/themes/spinner/watermark.png \
#      https://raw.githubusercontent.com/XeniaMeraki/XeniaOS-G-Euphoria/refs/heads/main/xeniaos_textlogo_plymouth_delphic_melody.png

# Add all users to sudoers file for sudo ability, enable polkit
RUN echo -e "%wheel      ALL=(ALL:ALL) ALL" | tee -a /etc/sudoers
RUN systemctl enable polkit

# Set up zram, this will help users not run out of memory. Fox will fix!
RUN echo -e '[zram0]\nzram-size = min(ram, 8192)' >> /usr/lib/systemd/zram-generator.conf
RUN echo -e 'enable systemd-resolved.service' >> usr/lib/systemd/system-preset/91-resolved-default.preset
RUN echo -e 'L /etc/resolv.conf - - - - ../run/systemd/resolve/stub-resolv.conf' >> /usr/lib/tmpfiles.d/resolved-default.conf
RUN systemctl preset systemd-resolved.service

# Enable wifi, firewall, power profiles.
RUN systemctl enable NetworkManager firewalld

# OS Release and Update
#RUN echo -e 'NAME="XeniaOS"\n\
#PRETTY_NAME="XeniaOS"\n\
#ID=arch\n\
#BUILD_ID=rolling\n\
#ANSI_COLOR="38;2;23;147;209"\n\
#HOME_URL="https://github.com/XeniaMeraki/XeniaOS"\n\
#LOGO=archlinux-logo\n\
#DEFAULT_HOSTNAME="XeniaOS"' > /etc/os-release

# Automounter Systemd Service for flash drives and CDs
RUN echo -e '[Unit] \n\
Description=Udiskie automount \n\
PartOf=graphical-session.target \n\
After=graphical-session.target \n\
 \n\
[Service] \n\
ExecStart=udiskie \n\
Restart=on-failure \n\
RestartSec=1 \n\
\n\
[Install] \n\
WantedBy=graphical-session.target' > /usr/lib/systemd/user/udiskie.service

# Clip history / Cliphist systemd service / Clipboard history for copy and pasting to work properly in Niri~
RUN echo -e '[Unit]\n\
Description=Clipboard History service\n\
PartOf=graphical-session.target\n\
After=graphical-session.target\n\
\n\
[Service]\n\
ExecStart=wl-paste --watch cliphist store\n\
Restart=on-failure\n\
RestartSec=1\n\
\n\
[Install]\n\
WantedBy=graphical-session.target' > /usr/lib/systemd/user/cliphist.service

# Symlink Vi to Vim / Make it to where a user can use vi in terminal command to use vim automatically | Thanks Tulip
RUN ln -s ./vim /usr/bin/vi

# Symlink GTK to Libadwaita
RUN mkdir -p /usr/share/gtk-4.0

RUN ln -sf /usr/share/themes/Colloid-Orange-Dark-Catppuccin/gtk-4.0/{assets,gtk.css,gtk-dark.css} \
       /usr/share/gtk-4.0/

# System-wide default application associations for filetype calls
RUN mkdir -p /etc/xdg/

RUN echo -e '[Default Applications]\n\
text/plain=org.kde.kate.desktop\n\
application/json=org.kde.kate.desktop\n\
\n\
text/html=floorp.desktop\n\
\n\
video/mp4=haruna.desktop\n\
video/x-matroska=haruna.desktop\n\
video/webm=haruna.desktop\n\
video/quicktime=haruna.desktop\n\
\n\
audio/mpeg=org.kde.elisa.desktop\n\
audio/flac=org.kde.elisa.desktop\n\
audio/ogg=org.kde.elisa.desktop\n\
audio/wav=org.kde.elisa.desktop\n\
\n\
image/png=pinta.desktop\n\
image/jpeg=pinta.desktop\n\
image/gif=org.kde.gwenview.desktop\n\
\n\
application/zip=org.kde.ark.desktop\n\
application/x-rar=org.kde.ark.desktop\n\
application/x-tar=org.kde.ark.desktop\n\
\n\
[Added Associations]' > /etc/xdg/mimeapps.list

# ENV default exports, QT theming 
# Load shared objects immediately for better first time latency
# Apply OBS_VK to all vulkan instances for better OBS game capture, some other windows may come along for the ride
ENV QT_QPA_PLATFORMTHEME=qt6ct
ENV LD_BIND_NOW=1
ENV OBS_VKCAPTURE=1

# Set vm.max_map_count for stability/improved gaming performance
# https://wiki.archlinux.org/title/Gaming#Increase_vm.max_map_count
RUN echo -e "vm.max_map_count = 2147483642" > /etc/sysctl.d/80-gamecompatibility.conf

# Autoclean pacman package cache after each update, install, and uninstall
RUN mkdir -p /etc/pacman.d/hooks/

RUN echo -e '[Trigger]\n\
Operation = Upgrade\n\
Operation = Install\n\
Operation = Remove\n\
Type = Package\n\
Target = *\n\
[Action]\n\
Description = Cleaning pacman cache...\n\
When = PostTransaction\n\
Exec = /usr/bin/paccache -r' > /etc/pacman.d/hooks/clean_package_cache.hook

# Automount ext4/btrfs drives, feel free to mount your own in fstab if you understand how to do so
# To turn off, run sudo ln -s /dev/null /etc/media-automount.d/_all.conf
RUN git clone --depth=1 https://github.com/Zeglius/media-automount-generator /tmp/media-automount-generator && \
    cd /tmp/media-automount-generator && \
    ./install_udev.sh && \
    rm -rf /tmp/media-automount-generator

########################################################################################################################################
# 
########################################################################################################################################

# Activate NTSync
RUN echo -e 'ntsync' > /etc/modules-load.d/ntsync.conf

# CachyOS bbr3 Config Option
RUN echo -e 'net.core.default_qdisc=fq \n\
net.ipv4.tcp_congestion_control=bbr' > /etc/sysctl.d/99-bbr3.conf

########################################################################################################################################
# 
########################################################################################################################################

#Shell setup
RUN echo -e 'fish' >> /etc/bash.bashrc
