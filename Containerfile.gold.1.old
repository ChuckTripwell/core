FROM docker.io/cachyos/cachyos-v3:latest AS final

ENV DRACUT_NO_XATTR=1

########################################################################################################################################
# BASE #################################################################################################################################
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

# Base packages \ Linux Foundation \ Foss is love, foss is life! We split up packages by category for readability, debug ease, and less dependency trouble
RUN pacman -S --noconfirm base dracut linux-firmware ostree systemd btrfs-progs e2fsprogs xfsprogs binutils dosfstools skopeo dbus dbus-glib glib2 shadow

# Media/Install utilities/Media drivers
RUN pacman -S --noconfirm librsvg libglvnd qt6-multimedia-ffmpeg plymouth acpid ddcutil dmidecode mesa-utils ntfs-3g \
      vulkan-tools wayland-utils playerctl

# Network / VPN / SMB / storage
RUN pacman -S --noconfirm libmtp networkmanager-openconnect networkmanager-openvpn nss-mdns samba smbclient networkmanager firewalld udiskie \
      udisks2 iwd

########################################################################################################################################
# AUR ##################################################################################################################################
########################################################################################################################################

RUN pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com

RUN pacman-key --init && pacman-key --lsign-key 3056513887B78AEB

RUN pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --noconfirm

RUN pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm

RUN echo -e '[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' >> /etc/pacman.conf

RUN pacman -Sy --noconfirm

RUN pacman -S --noconfirm chaotic-aur/bootc

# Regular AUR Build Section
# Create build user
RUN useradd -m --shell=/bin/bash build && usermod -L build && \
    echo "build ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    echo "root ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Install AUR packages
USER build
WORKDIR /home/build
RUN --mount=type=tmpfs,dst=/tmp \
    git clone https://aur.archlinux.org/paru-bin.git --single-branch /tmp/paru && \
    cd /tmp/paru && \
    makepkg -si --noconfirm && \
    cd .. && \
    rm -drf paru-bin

# AUR packages
RUN paru -S --noconfirm \
        aur/uupd

USER root
WORKDIR /
# Cleanup and delete build user
RUN userdel -r build && \
    rm -drf /home/build && \
    sed -i '/build ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers && \
    sed -i '/root ALL=(ALL) NOPASSWD: ALL/d' /etc/sudoers && \
    rm -rf /home/build && \
    rm -rf \
        /tmp/* \
        /var/cache/pacman/pkg/*


########################################################################################################################################
# FLATPAK ##############################################################################################################################
########################################################################################################################################

RUN mkdir -p /usr/share/flatpak/preinstall.d/

# Bazaar | Get most of your software here, flatpaks that are easy to install and use~
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

########################################################################################################################################
# LINUX ################################################################################################################################
########################################################################################################################################

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

# Set vm.max_map_count for stability/improved gaming performance
# https://wiki.archlinux.org/title/Gaming#Increase_vm.max_map_count
RUN echo -e "vm.max_map_count = 2147483642" > /etc/sysctl.d/80-gamecompatibility.conf

# iwd / Wifi backend setup for networkmanager / Expanded support for more wifi devices
RUN echo -e '[device]\nwifi.backend=iwd' > /etc/NetworkManager/conf.d/wifi_backend.conf

########################################################################################################################################
# BREW #################################################################################################################################
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


