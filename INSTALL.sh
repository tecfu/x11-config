#!/bin/bash

PRODUCT="X11 CONFIG"

OPENING_MESSAGE="STARTING $PRODUCT CONFIGURATION INSTALL"
echo -e "\033[0;32m$OPENING_MESSAGE\033[0m"

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

### Check for xmodmap
if ! [ -x "$(which xmodmap)" ]; then
  echo "
  ERROR! This package depends on \"xmodmap\". 
  It must be installed in order to remap keys on startup."

  exit
fi

### Check for sxhkd
if ! [ -x "$(which sxhkd)" ]; then
  echo "
  ERROR! This package depends on \"sxhkd\" (Simple X Hotkey Daemon). 
  To install it on Ubuntu use: 

  apt install sxhkd"
  exit
fi

### Check for xdotool
if ! [ -x "$(which xdotool)" ]; then
  echo "
  ERROR! This package depends on \"xdotool\". 
  To install it on Ubuntu use:

  apt install xdotool"
  exit
fi

# declare array
SYMLINKS=()
SYMLINKS+=("$HOME/dotfiles/x11-config/.xinitrc $HOME/.xinitrc")
SYMLINKS+=("$HOME/dotfiles/x11-config/.Xmodmap $HOME/.Xmodmap")
SYMLINKS+=("$HOME/dotfiles/x11-config/sxhkdrc $HOME/sxhkdrc")

#printf '%s\n' "${SYMLINKS[@]}"
#
for i in "${SYMLINKS[@]}"; do
  #echo $i
  # split each command at the space to get config path
  IFS=' ' read -ra OUT <<< "$i"
  # ${OUT[1]} is path config file should be at
  #no config, create symlink to one
  if [ ! -f "${OUT[1]}" ] && [ ! -L "${OUT[1]}" ]; then
    echo "Creating $i"
    ln -s $i 
  
  #config exsts; save if doesn't point to correct target
  elif [ "$(readlink -- "${OUT[1]}")" != "${OUT[0]}" ]; then
    echo "MOVING ${OUT[1]} to ${OUT[1]}.saved"
    mv "${OUT[1]}" "${OUT[1]}.saved"
    ln -s $i
  fi
done

CLOSING_MESSAGE="ENDING $PRODUCT CONFIGURATION INSTALL"
echo -e "\033[0;32m$CLOSING_MESSAGE\033[0m"
