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

# When run via sudo, $HOME is root's and $USER is root — but xremap lives in
# the invoking user's cargo bin, and the input group belongs to that user.
# A plain non-login shell (ssh) also misses ~/.cargo/bin (never sourced from
# ~/.profile), so put it on PATH unconditionally.
TARGET_USER="${SUDO_USER:-$USER}"
if [ "$(id -u)" = "0" ] && [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
  USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
else
  USER_HOME="$HOME"
fi
export PATH="$USER_HOME/.cargo/bin:$HOME/.cargo/bin:$PATH"

# Add user to input group
if ! groups "$TARGET_USER" | grep -q "\binput\b"; then
  echo "Adding $TARGET_USER to input group..."
  sudo gpasswd -a "$TARGET_USER" input
fi

# Configure udev rules
if [ ! -f /etc/udev/rules.d/99-input.rules ] || ! grep -q "uinput" /etc/udev/rules.d/99-input.rules; then
    echo "Configuring udev rules in /etc/udev/rules.d/99-input.rules..."
    echo 'KERNEL=="uinput", GROUP="input", MODE="0660"' | sudo tee /etc/udev/rules.d/99-input.rules
    echo "Reloading udev rules..."
    sudo udevadm control --reload-rules && sudo udevadm trigger
fi

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
# Mixed-DPI extended desktop: denser desktop on the low-DPI external output.
# Harmless when only the laptop panel is connected (the script no-ops).
SYMLINKS+=("$HOME/dotfiles/x11-config/scale-external-monitor $HOME/.local/bin/scale-external-monitor")
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

### Mixed-DPI extended desktop: autostart entry for scale-external-monitor
# The desktop entry needs the real $HOME inside Exec, and desktop-entry quoting
# cannot carry a variable there (desktop-file-validate rejects '$' inside a
# quoted Exec argument), so generate it rather than symlink it - the same
# approach keyboard-shortcuts/install.sh uses for sxhkd-dotfiles.desktop.
AUTOSTART="$HOME/.config/autostart/external-monitor-scale.desktop"
mkdir -p "$(dirname "$AUTOSTART")"
if ! grep -qxF "Exec=$HOME/.local/bin/scale-external-monitor" "$AUTOSTART" 2>/dev/null; then
  cat > "$AUTOSTART" <<EOF2
[Desktop Entry]
Type=Application
Name=External monitor scale
Comment=Denser desktop on the low-DPI external output (see x11-config/README.md)
Exec=$HOME/.local/bin/scale-external-monitor
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF2
  echo "WRITE: $AUTOSTART"
else
  echo "OK: $AUTOSTART (already present)"
fi
