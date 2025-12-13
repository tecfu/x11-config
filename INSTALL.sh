#!/bin/bash

###
#   RUN THIS WITH /bin/bash NOT /bin/sh
#   /bin/sh MAPS TO INCOMPATIBLE TERM EMULATORS 
#   IN SOME OS
#   
#   ```
#    $ /bin/bash INSTALL.sh
#   ```
#
###

if ! [ -x "$(which Xorg)" ]; then
  echo "INFO: X Window System not installed, skipping related config (keymappings)"
  exit 0
fi

### check for xremap & configure permissions
  
echo "INFO: configuring udev rules for xremap..."

# Create input group if it doesn't exist
if ! getent group input > /dev/null; then
  echo "Creating input group..."
  sudo groupadd input
fi

# Add user to input group
if ! groups $USER | grep -q "\binput\b"; then
  echo "Adding $USER to input group..."
  sudo gpasswd -a $USER input
fi

# Configure udev rules
if [ ! -f /etc/udev/rules.d/99-input.rules ] || ! grep -q "uinput" /etc/udev/rules.d/99-input.rules; then
    echo "Configuring udev rules in /etc/udev/rules.d/99-input.rules..."
    echo 'KERNEL=="uinput", GROUP="input", MODE="0660"' | sudo tee /etc/udev/rules.d/99-input.rules
    echo "Reloading udev rules..."
    sudo udevadm control --reload-rules && sudo udevadm trigger
fi

if ! [ -x "$(which xremap)" ]; then
  echo "
  ERROR: This package depends on \"xremap\". 
  It must be installed in order to remap keys on startup.
  To install and set it up on Ubuntu use: 

  cargo install xremap --features x11
  "
  exit 1
fi

### Check for sxhkd
if ! [ -x "$(which sxhkd)" ]; then
  echo "
  ERROR: This package depends on \"sxhkd\" (Simple X Hotkey Daemon). 
  To install it on Ubuntu use: 

  apt install sxhkd"
  exit 1
fi

### Check for xdotool
if ! [ -x "$(which xdotool)" ]; then
  echo "
  ERROR: This package depends on \"xdotool\". 
  To install it on Ubuntu use:

  apt install xdotool"
  exit 1
fi

# declare array
SYMLINKS=()
SYMLINKS+=("$HOME/dotfiles/x11-config/.xprofile $HOME/.xprofile")
SYMLINKS+=("$HOME/dotfiles/x11-config/xremap.yml $HOME/.config/xremap/xremap.yml")
SYMLINKS+=("$HOME/dotfiles/x11-config/sxhkdrc $HOME/.config/sxhkd/sxhkdrc")

#printf '%s\n' "${SYMLINKS[@]}"
#
for i in "${SYMLINKS[@]}"; do
  #echo $i
  # split each command at the space to get config path
  IFS=' ' read -ra OUT <<< "$i"
  # ${OUT[1]} is path config file should be at
  #no config, create symlink to one
  if [ ! -f "${OUT[1]}" ] && [ ! -L "${OUT[1]}" ]; then
    mkdir -p "$(dirname "${OUT[1]}")"
    echo "SYMLINK: $i"
    ln -s $i 
  
  #config exsts; save if doesn't point to correct target
  elif [ "$(readlink -- "${OUT[1]}")" != "${OUT[0]}" ]; then
    echo "MOVING: git@github.com:tecfu/x11-config.git ${OUT[1]} to ${OUT[1]}.saved"
    mkdir -p "$(dirname "${OUT[1]}")"
    mv "${OUT[1]}" "${OUT[1]}.saved"
    ln -s $i
  fi
done
