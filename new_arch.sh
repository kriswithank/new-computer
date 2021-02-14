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
  name=$(dialog --stdout --inputbox "Enter username" 0 0 2>/tmp/username) || return 1
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

createuser() {
  createnewuser() {
    useradd -m -g wheel -s /bin/zsh "$name"
  }
  updateexistinguser() {
    usermod -a -G wheel "$name" &&
      mkdir -p /home/"$name" &&
      chown "$name":wheel /home/"$name"
  }
  createnewuser || updateexistinguser
  echo "$name:$pass1" | chpasswd
  unset pass1 pass2
}

refreshkeyring() {
  set -x
  pacman --noconfirm -S archlinux-keyring
}

installpacmanpkgs() {
  set -x
  low_level_packages=(
    base-devl # Common utilities usually already installed from pacstrap during base install
    ntp       # Network Time Protocol i.e. Clock syncronization
    apci      # CLI for battery, power, and system temp
    inxi      # CLI for system info, battery, power, temp, sensors, etc -- may be able to replace apci?
    cpupower  # Adjust/throttle/overclock cpu power
  )
  driver_packages=(
    xf86-input-elographics # Elographics touchscreen
    xf86-input-evdev 
    xf86-input-keyboard 
    xf86-input-libinput 
    xf86-input-mouse 
    xf86-input-void 
    xf86-input-wacom # Wacom tablets
    xf86-video-intel # Intel graphics
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
    pulseaudio            # Sound server
    pulseaudio-alsa       # Force application that explicitly use alsa to go through PulseAudio
    pulseaudio-bluetooth  # Audio over bluetooth
    pulseaudio-jack       # Allow PulseAudio and JACK to play nice
    pulsemixer            # PulseAudio TUI
    pamixer               # PulseAudio CLI
  )
  networking_packages=(
    networkmanager 
    networkmanager-openconnect 
    networkmanager-openvpn 
    networkmanager-pptp 
    networkmanager-vpnc 
    networkmanager-strongswann 
    networkmanager-fortisslvpn 
    network-manager-sstp 
    mobile-broadband-provider-info  # Info for NM to connect to mobile connections
    modemmanager  # Mobile modem management
    iputils  # ping and other tools
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
    rsync                   # Sync files between computers
    unison                  # Alterative to rsync supporting diff based sync
    pactree                 # Easily visualize package dependencies
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
    go             # Go lang compiler and tools
    rust           # Rust lang
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
    firefox                   # Web browser
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

  # pacman --noconfirm --needed -S \
  #   # Low level packages
  #   base-devl \ # Common utilities usually already installed from pacstrap during base install
  #   ntp \       # Network Time Protocol i.e. Clock syncronization
  #   apci \      # CLI for battery, power, and system temp
  #   inxi \      # CLI for system info, battery, power, temp, sensors, etc -- may be able to replace apci?
  #   cpupower \  # Adjust/throttle/overclock cpu power
  #   # Drivers
  #   xf86-input-elographics \ # Elographics touchscreen
  #   xf86-input-evdev \
  #   xf86-input-keyboard \
  #   xf86-input-libinput \
  #   xf86-input-mouse \
  #   xf86-input-void \
  #   xf86-input-wacom \ # Wacom tablets
  #   xf86-video-intel \ # Intel graphics
  #   # File systems
  #   btrfs-progs \   # btrfs utils
  #   dosfstools \    # dos fs utils
  #   e2fsprogs \     # ext2/3/4/ utils
  #   xfsprogs \      # XFS utils
  #   exfat-utils \   # exFAT fs utils
  #   f2fs-tools \    # Flash-Friendly File System (F2FS) utils -- for NAND SSD, sd cards, etc
  #   jfsutils \      # JFS utils
  #   mtpfs \         # FUSE that supports MTP devices
  #   nfs-utils \     # Network File System
  #   ntfs-3g \       # NTFS utils
  #   reiserfsprogs \ # ReiserFS utils
  #   # Archiving
  #   tar \
  #   zip \
  #   unzip \
  #   bzip2 \
  #   p7zip \
  #   unrar \
  #   # Audio
  #   pulseaudio \           # Sound server
  #   pulseaudio-alsa \      # Force application that explicitly use alsa to go through PulseAudio
  #   pulseaudio-bluetooth \ # Audio over bluetooth
  #   pulseaudio-jack \      # Allow PulseAudio and JACK to play nice
  #   pulsemixer \           # PulseAudio TUI
  #   pamixer \              # PulseAudio CLI
  #   # Networking
  #   networkmanager \
  #   networkmanager-openconnect \
  #   networkmanager-openvpn \
  #   networkmanager-pptp \
  #   networkmanager-vpnc \
  #   networkmanager-strongswann \
  #   networkmanager-fortisslvpn \
  #   network-manager-sstp \
  #   mobile-broadband-provider-info \ # Info for NM to connect to mobile connections
  #   modemmanager \ # Mobile modem management
  #   iputils \ # ping and other tools
  #   openssh \
  #   # Basic tools
  #   man-db \                  # Manpage tooling
  #   man-pages \               # Manpage content
  #   less \                    # Pager
  #   most \                    # Pager
  #   bluez-utils \             # Bluetooth utils
  #   psmisc \                  # pstree, killall, fuser, pidof, peekfd
  #   xdg-user-dirs \           # Set XDG paths like ~/Downloads, ~/.config, etc
  #   xdg-utils \               # Various XDG CLI utils like xdg-open, etc
  #   trash-cli \               # XDG trash CLI
  #   lsd \                     # Modernized ls
  #   dash \                    # Shell: Fash sh
  #   bash \                    # Shell: The grandaddy
  #   zsh \                     # Shell: Nicer than bash
  #   zsh-autosuggestions \     # Make zsh more like fish
  #   zsh-completions \         # Make zsh more like fish
  #   zsh-syntax-highlighting \ # Make zsh more like fish
  #   fish \                    # Shell: Nicer than zsh
  #   xonsh \                   # Shell: python + shell
  #   wget \                    # Download files
  #   curl \                    # Download files
  #   httpie \                  # Curl with sane syntax
  #   rsync \                   # Sync files between computers
  #   unison \                  # Alterative to rsync supporting diff based sync
  #   pactree \                 # Easily visualize package dependencies
  #   tree \                    # List dirs as a tree
  #   bc \                      # Calculator
  #   gawk \                    # GNU awk
  #   jq \                      # Json manipulation from terminal
  #   ripgrep \                 # Grep but faster
  #   git \                     # Version control system
  #   diffutils \               # Commands for diffs and patches
  #   htop \                    # Task/Process manager
  #   sxhkd \                   # Simple X hotkey daemon for keybindings
  #   neovim \                  # Editor of choice
  #   vim \                     # Backup editor
  #   ranger \                  # File manager
  #   pandoc \                  # Convert between filetypes
  #   speedtest-cli \           # Speedtest.com but in the terminal
  #   ffmpeg \                  # CLI to record screen and audio
  #   screenfetch \             # Show system & theme info for screenshots
  #   dfc \                     # Colorful file system used and free space
  #   # Dev tools
  #   gdb \            # GNU debugger
  #   go \             # Go lang compiler and tools
  #   rust \           # Rust lang
  #   npm \            # Node package manager
  #   pyenv \          # Manage multiple python versions
  #   shellcheck \     # Lint shell scripts
  #   shfmt \          # Autoformat shell scripts
  #   aws-cli \        # AWS
  #   docker \         # Containers
  #   docker-compose \ # Containers
  #   # Graphical packages
  #   xorg-server \               # The X graphical server
  #   xorg-xinit \                # Start X server
  #   xorg-xprop \                # Detect window properties
  #   xorg-xwininfo \             # Query info about windows
  #   xorg-xdpyinfo \             # Info about X server
  #   xorg-xbacklight \           # Change screen brightness
  #   xorg-xkill \                # Utility to kill the window you click
  #   xorg-xev \                  # Display pressed keys and mouse movements, good for debugging
  #   xorg-xfontsel \             # Utility for selecting X11 font names
  #   xorg-xsetroot \             # Set X background and cursor
  #   xclip \                     # Clipboard commands from terminal
  #   xdotool \                   # Automate literally everything
  #   xwallpaper \                # Set the wallpaper
  #   qtile \                     # Window manager
  #   kitty \                     # Terminal
  #   arandr \                    # Graphical xrandr, to set screen layouts
  #   zathura \                   # PDF viewer
  #   zathura-pdf-mupdf \         # Zathura mupdf support
  #   chromium \                  # Web browser
  #   firefox                     # Web browser
  #   firefox-developer-edition \ # Web browser
  #   vlc \                       # Video player
  #   feh \                       # Image viewer
  #   xdot \                      # graphviz viewer
}


### ACTUAL SCRIPT

pacman --noconfirm --needed -Sy dialog ||
  exiterror "Could not install dialog. This should only be run as root on Arch-based distros with an internet connection"

numsteps=10

(welcomemsg && getuserandpass && confirmationmsg) || exiterror "User exited"
(refreshkeyring 2>&1 | dialog_progress "1/$numsteps Updating keyring") ||
  confirmerror "Could not update keyring, consider doing so manually"
(installpacmanpkgs 2>&1 | dialog_progress "2/$numsteps Installing pacman packages") ||
  confirmerror "Could not install pacman packages"
(dialog --infobox "3/$numsteps: Creating/updating user" 30 1000 && createuser) ||
  exiterror "Problem creating or updating user"
