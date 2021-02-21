#!/bin/bash
set -o pipefail

## GLOBAL VARS

logfile="/tmp/new_arch.log.$$"

### FUNCTIONS

exiterror() {
  clear
  echo "ERROR: $1"
  exit 1
}

confirmerror() {
  dialog --colors --title "\Z1An error occurred (see logs for more details)" --tailbox "$logfile" 35 1000
  clear
  echo "ERROR:    $1"
  echo "LOG FILE: $logfile"
  exit 1
}

dialog_progress() {
  echo "$1" >> "$logfile"
  tee -a "$logfile" | dialog --progressbox "$1" 30 1000
}

welcomemsg() {
  dialog \
    --trim \
    --title "Welcome!" \
    --yes-label "All ready!" \
    --no-label "Go back" \
    --yesno "This script will automatically install and configure the system

    Be sure pacman and the Arch keyrings are up to date

    If they aren't some programs may fail to install" \
    0 0
}

getuserandpass() {
  name=$(dialog --stdout --inputbox "Enter username" 0 0) || return 1
  while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
    name=$(dialog --stdout --no-cancel --inputbox "Username not valid, must start with a lowercase letter and contain only lowercase letters, -, or _" 0 0) ||
      return 1
  done
  pass1=$(dialog --stdout --passwordbox "Enter password" 0 0) || return 1
  pass2=$(dialog --stdout --passwordbox "Retype password" 0 0) || return 1
  while ! [ "$pass1" = "$pass2" ]; do
    unset pass2
    pass1=$(dialog --stdout --passwordbox "Passwords didn't match\\nEnter password" 0 0) || return 1
    pass2=$(dialog --stdout --passwordbox "Retype password" 0 0) || return 1
  done
  dialog \
    --colors \
    --title "\Z1WARNING" \
    --yes-label "OK" \
    --no-label "Cancel" \
    --yesno "If user already exists, password will be reset" 0 0
}

confirmationmsg() {
  dialog \
    --title "Let's get this party started!" \
    --yes-label "Let's go!" \
    --no-label "No, nevermind!" \
    --yesno 'Last chance to back out\n\nThe rest of the installation will be totally automated, sit back and relax' \
    0 0
}

refreshkeyring() {
  set -x
  pacman --noconfirm -S archlinux-keyring
  set +x
}

updatesudoers() {
  set -x
  sed -i "/# SETUPSCRIPT/d" /etc/sudoers  # Clearout old lines from setupscript if they exist
  {
    # Allow wheel users to use sudo
    echo "%wheel   ALL=(ALL) ALL  # SETUPSCRIPT"
    # Allow wheel users to run the following commands without a password
    echo "%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/systemctl restart NetworkManager  # SETUPSCRIPT"
    # Run all sudo commands without a password (required for AUR builds) will be removed afterwards
    echo "%wheel ALL=(ALL) NOPASSWD: ALL  # DELETEME"
  } >> /etc/sudoers
  set +x
}

cleanupsudoers() {
  set -x
  sed -i "/# DELETEME$/d" /etc/sudoers
  set +x
}

makepacmanandyaycolorful() {
  set -x
  grep -q "^Color" /etc/pacman.conf ||
    sed -i "s/^#Color$/Color/" /etc/pacman.conf
  grep -q "ILoveCandy" /etc/pacman.conf ||
    sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
  set +x
}

installpacmanpkgs() {
  set -x
  low_level_packages=(
    base-devel     # Common utilities usually already installed from pacstrap during base install
    ntp            # Network Time Protocol i.e. Clock syncronization
    acpi           # CLI for battery, power, and system temp
    cpupower       # Adjust/throttle/overclock cpu power
    pacman-contrib # Pacman utils ex. pactree, pacsearch, rankmirrors, etc.
  )
  driver_packages=(
    xf86-input-elographics # Elographics touchscreen
    xf86-input-synaptics   # Laptop touchpads
    xf86-input-evdev       # Generic event devices (all inputs the kernel knows about)
    xf86-input-wacom       # Wacom tablets
    xf86-video-intel       # Intel graphics
  )
  file_system_packages=(
    btrfs-progs   # btrfs utils
    dosfstools    # dos fs utils
    e2fsprogs     # ext2/3/4/ utils
    xfsprogs      # XFS utils
    exfat-utils   # exFAT fs utils
    f2fs-tools    # Flash-Friendly File System (F2FS) utils -- for NAND SSD, sd cards, etc
    jfsutils      # JFS utils
    mtpfs         # FUSE that supports MTP devices
    nfs-utils     # Network File System
    ntfs-3g       # NTFS utils
    reiserfsprogs # ReiserFS utils
  )
  compression_packages=(
    tar
    zip
    unzip
    bzip2
    p7zip
    unrar
  )
  audio_packages=(
    pulseaudio           # Sound server
    pulseaudio-alsa      # Force application that explicitly use alsa to go through PulseAudio
    pulseaudio-bluetooth # Audio over bluetooth
    pulseaudio-jack      # Allow PulseAudio and JACK to play nice
    pulsemixer           # PulseAudio TUI
    pamixer              # PulseAudio CLI
  )
  networking_packages=(
    networkmanager
    networkmanager-openconnect
    networkmanager-openvpn
    networkmanager-pptp
    networkmanager-vpnc
    networkmanager-strongswan
    networkmanager-fortisslvpn
    network-manager-sstp
    mobile-broadband-provider-info # Info for NM to connect to mobile connections
    modemmanager                   # Mobile modem management
    iputils                        # ping and other tools
    openssh
  )
  basic_tool_packages=(
    man-db                  # Manpage tooling
    man-pages               # Manpage content
    less                    # Pager
    most                    # Pager
    bluez-utils             # Bluetooth utils
    psmisc                  # pstree, killall, fuser, pidof, peekfd
    xdg-user-dirs           # Set XDG paths like ~/Downloads, ~/.config, etc
    xdg-utils               # Various XDG CLI utils like xdg-open, etc
    trash-cli               # XDG trash CLI
    lsd                     # Modernized ls
    dash                    # Shell: Fash sh
    bash                    # Shell: The grandaddy
    zsh                     # Shell: Nicer than bash
    zsh-autosuggestions     # Make zsh more like fish
    zsh-completions         # Make zsh more like fish
    zsh-syntax-highlighting # Make zsh more like fish
    fish                    # Shell: Nicer than zsh
    xonsh                   # Shell: python + shell
    wget                    # Download files
    curl                    # Download files
    httpie                  # Curl with sane syntax
    rsync                   # Sync files
    unison                  # rsync but better at bi-directional sync
    tree                    # List dirs as a tree
    bc                      # Calculator
    gawk                    # GNU awk
    jq                      # Json manipulation from terminal
    ripgrep                 # Grep but faster
    git                     # Version control system
    diffutils               # Commands for diffs and patches
    htop                    # Task/Process manager
    sxhkd                   # Simple X hotkey daemon for keybindings
    neovim                  # Editor of choice
    vi                      # Just in case
    vim                     # Backup editor
    ranger                  # File manager
    pandoc                  # Convert between filetypes
    speedtest-cli           # Speedtest.com but in the terminal
    ffmpeg                  # CLI to record screen and audio
    screenfetch             # Show system & theme info for screenshots
    dfc                     # Colorful file system used and free space
  )
  dev_tool_packages=(
    gdb            # GNU debugger
    npm            # Node package manager
    pyenv          # Manage multiple python versions
    shellcheck     # Lint shell scripts
    shfmt          # Autoformat shell scripts
    aws-cli        # AWS
    docker         # Containers
    docker-compose # Containers
  )
  graphical_packages=(
    xorg-server               # The X graphical server
    xorg-xinit                # Start X server
    xorg-xprop                # Detect window properties
    xorg-xwininfo             # Query info about windows
    xorg-xdpyinfo             # Info about X server
    xorg-xbacklight           # Change screen brightness
    xorg-xkill                # Utility to kill the window you click
    xorg-xev                  # Display pressed keys and mouse movements, good for debugging
    xorg-xfontsel             # Utility for selecting X11 font names
    xorg-xsetroot             # Set X background and cursor
    xclip                     # Clipboard commands from terminal
    xdotool                   # Automate literally everything
    xwallpaper                # Set the wallpaper
    qtile                     # Window manager
    kitty                     # Terminal
    arandr                    # Graphical xrandr, to set screen layouts
    zathura                   # PDF viewer
    zathura-pdf-mupdf         # Zathura mupdf support
    chromium                  # Web browser
    firefox-developer-edition # Web browser
    vlc                       # Video player
    feh                       # Image viewer
    xdot                      # graphviz viewer
  )
  pacman --noconfirm --needed -S \
    "${low_level_packages[@]}" \
    "${driver_packages[@]}" \
    "${file_system_packages[@]}" \
    "${compression_packages[@]}" \
    "${audio_packages[@]}" \
    "${networking_packages[@]}" \
    "${basic_tool_packages[@]}" \
    "${dev_tool_packages[@]}" \
    "${graphical_packages[@]}"
  set +x
}

createuser() {
  set -x
  createnewuser() {
    useradd -m -g wheel -s /bin/zsh "$name"
  }
  updateexistinguser() {
    usermod -a -G wheel "$name" &&
      mkdir -p /home/"$name" &&
      chown "$name":wheel /home/"$name"
  }
  createnewuser || updateexistinguser
  set +x
  # Don't want to log the password...
  echo "$name:$pass1" | chpasswd
  unset pass1 pass2
}

installaurhelper() {
  set -x
  cd /tmp || return 1
  sudo -u "$name" git clone https://aur.archlinux.org/yay.git
  cd yay || return 1
  sudo -u "$name" makepkg --noconfirm -si
  set +x
}

disablesystembeep() {
  rmmod pcspkr
  echo "blacklist pcspkr" | tee /etc/modprobe.d/nobeep.conf
}

setupdotfiles() {
  # See https://www.anand-iyer.com/blog/2018/a-simpler-way-to-manage-your-dotfiles.html
  set -x
  sudo -u "$name" mkdir -p "/home/$name/Projects"
  sudo -u "$name" git clone --separate-git-dir="/home/$name/Projects/dotfiles" https://github.com/kriswithank/dotfiles.git /tmp/dotfiles
  sudo -u "$name" rsync --recursive --verbose --exclude ".git" /tmp/dotfiles "/home/$name"
  # TODO switch git to ssh after initial download
  set +x
}

### ACTUAL SCRIPT

pacman --noconfirm --needed -Sy dialog ||
  exiterror "Could not install dialog. This should only be run as root on Arch-based distros with an internet connection"

{ welcomemsg && getuserandpass && confirmationmsg; } ||
  exiterror "User exited"

# No more user input from here on out
numsteps=10

{ refreshkeyring 2>&1 | dialog_progress "1/$numsteps Updating keyring"; } ||
  confirmerror "Could not update keyring, consider doing so manually"

{ updatesudoers 2>&1 | dialog_progress "2/$numsteps Updating sudoers"; } ||
  confirmerror "Could not update sudoers"

{ makepacmanandyaycolorful 2>&1 | dialog_progress "3/$numsteps Making pacman colorful"; } ||
  confirmerror "Could not add pretty colors to pacman"

{ installpacmanpkgs 2>&1 | dialog_progress "4/$numsteps Installing pacman packages"; } ||
  confirmerror "Could not install pacman packages"

{ createuser 2>&1 | dialog_progress "5/$numsteps Creating/updating user"; } ||
  confirmerror "Could not create/update user"

{ installaurhelper 2>&1 | dialog_progress "6/$numsteps Installing AUR helper"; } ||
  confirmerror "Could not install AUR helper"

{ cleanupsudoers 2>&1 | dialog_progress "7/$numsteps Cleaning up sudoers"; } ||
  confirmerror "Could not clean up sudoers"

{ disablesystembeep 2>&1 | dialog_progress "8/$numsteps Diabling system beep"; } ||
  confirmerror "Could not disable system beep"

{ setupdotfiles 2>&1 | dialog_progress "9/$numsteps Setting up dotfiles"; } ||
  confirmerror "Could not setup dotfiles"

# TODO:
# pip/pipx packages
# Clone from backup?
# dmenu/st emojis
