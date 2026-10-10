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

. "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# Skip when the live session is not X11 (e.g. Wayland on KDE/GNOME), or when
# no X server actually runs on this machine. xremap/sxhkd need local X: check
# for real X sockets (/tmp/.X11-unix/X*) — the Xorg binary alone is NOT
# evidence (servers often carry it unused), and DISPLAY over SSH forwarding
# is not a local X session (xremap would be dead weight there).
SESSION="$(detect_session)"
if [ "$SESSION" = "wayland" ] || ! ls /tmp/.X11-unix/X* >/dev/null 2>&1; then
  install_skip "session type '$SESSION', no local X server; x11-config (xremap/sxhkd) does not apply."
  exit 0
fi

# x11-config is DE-agnostic on X11: xremap/sxhkd work the same under XFCE and KDE.
echo "INFO: detected desktop: $(detect_de), session: $SESSION (x11-config is DE-agnostic on X11)"

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

# cargo installs into ~/.cargo/bin, but a non-login shell (e.g. running
# INSTALL.sh over plain ssh) never sources ~/.profile, so xremap can be
# installed and running yet invisible to command -v. Put it on PATH first.
export PATH="$HOME/.cargo/bin:$PATH"

HAVE_XREM=1
if ! command -v xremap >/dev/null 2>&1; then
  apt_install cargo && cargo install xremap --features x11
fi
require_dep xremap || HAVE_XREM=0

### Check for sxhkd / xdotool (both needed by sxhkdrc bindings)
HAVE_SXHKD=1
require_dep sxhkd sxhkd || HAVE_SXHKD=0
require_dep xdotool xdotool || HAVE_SXHKD=0

# declare array
SYMLINKS=()
SYMLINKS+=("$HOME/dotfiles/x11-config/.xprofile $HOME/.xprofile")
# dep-gated configs: skipped when their dependency is missing and --ignore-missing-deps is set
[ "$HAVE_XREM" = 1 ] && SYMLINKS+=("$HOME/dotfiles/x11-config/xremap.yml $HOME/.config/xremap/xremap.yml")
[ "$HAVE_SXHKD" = 1 ] && SYMLINKS+=("$HOME/dotfiles/x11-config/sxhkdrc $HOME/.config/sxhkd/sxhkdrc")

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
