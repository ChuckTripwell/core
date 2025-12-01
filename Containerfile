FROM docker.io/cachyos/cachyos-v3:latest

ENV DRACUT_NO_XATTR=1

########################################################################################################################################
# 
########################################################################################################################################

# Move everything from `/var` to `/usr/lib/sysimage` so behavior around pacman remains the same on `bootc usroverlay`'d systems
RUN grep "= */var" /etc/pacman.conf | sed "/= *\/var/s/.*=// ; s/ //" | xargs -n1 sh -c 'mkdir -p "/usr/lib/sysimage/$(dirname $(echo $1 | sed "s@/var/@@"))" && \
mv -v "$1" "/usr/lib/sysimage/$(echo "$1" | sed "s@/var/@@")"' '' && \
    sed -i -e "/= *\/var/ s/^#//" -e "s@= */var@= /usr/lib/sysimage@g" -e "/DownloadUser/d" /etc/pacman.conf

# Set it up such that pacman is always cleaned after installs
RUN echo -e "[Trigger]\n\
Operation = Install\n\
Operation = Upgrade\n\
Type = Package\n\
Target = *\n\
\n\
[Action]\n\
Description = Cleaning up package cache...\n\
Depends = coreutils\n\
When = PostTransaction\n\
Exec = /usr/bin/rm -rf /var/cache/pacman/pkg" > /usr/share/libalpm/hooks/package-cleanup.hook

# Initialize the database
RUN pacman -Syu --noconfirm

# Use the Arch mirrorlist that will be best at the moment for both the containerfile and user too.
RUN pacman -S --noconfirm reflector
RUN pacman -Syyuu --noconfirm

# Base packages
RUN pacman -S --noconfirm base dracut linux-firmware ostree systemd btrfs-progs e2fsprogs xfsprogs binutils dosfstools skopeo dbus dbus-glib glib2 shadow runc

# Media/Install utilities/Media drivers
RUN pacman -S --noconfirm librsvg libglvnd qt6-multimedia-ffmpeg plymouth acpid ddcutil dmidecode mesa-utils ntfs-3g \
      vulkan-tools wayland-utils playerctl

# Fonts
RUN pacman -S --noconfirm noto-fonts noto-fonts-cjk noto-fonts-emoji unicode-emoji noto-fonts-extra ttf-fira-code ttf-firacode-nerd \
      ttf-ibm-plex ttf-jetbrains-mono-nerd otf-font-awesome ttf-jetbrains-mono gnu-free-fonts awesome-terminal-fonts

# CLI Utilities
RUN pacman -S --noconfirm sudo bash bash-completion fastfetch btop jq less lsof nano openssh powertop man-db wget yt-dlp \
      tree usbutils vim wl-clipboard unzip ptyxis glibc-locales tar udev starship tuned-ppd tuned hyfetch curl

# Virtualization and containerization
RUN pacman -S --noconfirm distrobox docker podman firejail bubblewrap

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

RUN pacman -S --noconfirm \
    chaotic-aur/sc-controller chaotic-aur/flatpak-git \
    chaotic-aur/ttf-symbola chaotic-aur/opentabletdriver chaotic-aur/qt6ct-kde chaotic-aur/bootc

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

# All kindsa Sudo changes for ease and flavor
RUN echo -e '%wheel ALL=(ALL:ALL) ALL\n\
\n\
Defaults insults\n\
Defaults pwfeedback\n\
Defaults secure_path="/usr/local/bin:/usr/bin:/bin:/home/linuxbrew/.linuxbrew/bin"\n\
Defaults env_keep += "EDITOR VISUAL PATH"\n\
Defaults timestamp_timeout=0' > /etc/sudoers.d/xenias-sudo-quiver && \
    chmod 440 /etc/sudoers.d/xenias-sudo-quiver

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

# Symlink Vi to Vim / Make it to where a user can use vi in terminal command to use vim automatically | Thanks Tulip
RUN ln -s ./vim /usr/bin/vi

# Symlink GTK to Libadwaita
#RUN mkdir -p /usr/share/gtk-4.0

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

RUN curl -s https://api.github.com/repos/ublue-os/packages/releases/latest \
    | jq -r '.assets[] | select(.name | test("homebrew-x86_64.*\\.tar\\.zst")) | .browser_download_url' \
    | xargs -I {} wget -O /usr/share/homebrew.tar.zst {}

RUN echo '[[ -d /home/linuxbrew/.linuxbrew && $- == *i* ]] && \
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' > /etc/profile.d/brew.sh

RUN echo -e "[Unit]\n\
Description=Setup Homebrew from tarball\n\
After=local-fs.target\n\
ConditionPathExists=!/var/home/linuxbrew/.linuxbrew\n\
ConditionPathExists=/usr/share/homebrew.tar.zst\n\
\n\
[Service]\n\
Type=oneshot\n\
ExecStart=/usr/bin/mkdir -p /tmp/homebrew\n\
ExecStart=/usr/bin/mkdir -p /var/home/linuxbrew\n\
ExecStart=/usr/bin/tar --zstd -xf /usr/share/homebrew.tar.zst -C /tmp/homebrew\n\
ExecStart=/usr/bin/cp -R -n /tmp/homebrew/linuxbrew/.linuxbrew /var/home/linuxbrew\n\
ExecStart=/usr/bin/chown -R 1000:1000 /var/home/linuxbrew\n\
ExecStart=/usr/bin/rm -rf /tmp/homebrew\n\
ExecStart=/usr/bin/touch /etc/.linuxbrew\n\
\n\
[Install]\n\
WantedBy=multi-user.target" > /usr/lib/systemd/system/brew-setup.service

RUN systemctl enable brew-setup.service

# Activate NTSync
RUN echo -e 'ntsync' > /etc/modules-load.d/ntsync.conf

# CachyOS bbr3 Config Option
RUN echo -e 'net.core.default_qdisc=fq \n\
net.ipv4.tcp_congestion_control=bbr' > /etc/sysctl.d/99-bbr3.conf

########################################################################################################################################
# 
########################################################################################################################################

#Shell setup
#RUN echo -e 'fish' >> /etc/bash.bashrc
#RUN echo -e 'fastfetch' >> /etc/bash.bashrc
