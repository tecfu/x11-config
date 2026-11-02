# x11-config

## Introduction

This repo contains configuration files for X11 desktops, specifically Xubuntu

- Key remapping
- Display scaling for a mixed-DPI extended desktop

## X11 configuration files

*Note*: Multiple system-level remapping app configurations are stored here. 
Only one of them should be used at a time:

- Xremap (system + application level mappings)
- xmodmap (system level mappings)
- skhd (application level mappings)

### Xremap / xremap.yaml

> Comment:
> On paper, this is the most powerful and flexible option. But the maintainers have decided to hide issues by migrating to Github "Discussions" and not allowing issues to be opened. This is a red flag.

- Process started in .xprofile
- Has a watch feature to automatically load mappings for new devices
- Maps Caps Lock to Esc
- Maps C-j to C-b and C-k to C-m in Google Chrome
- Maps Aider vim mode begin/end line to `<space>a`, `<space>;`

### Xmodmap / .xmodmap

**DISABLED** Commented code retained for reference

- Process started in .xprofile
- No watch feature
- Maps Caps Lock to Esc

### Simple X Hotkey Daemon / skhdrc

**DISABLED** Commented code retained for reference

- Process started in .xprofile
- No watch feature
- By design cannot effectively remap Caps Lock to Esc
- Calls scripts to remap keys in Google Chrome using xdotool

### Display scaling (mixed-DPI extended desktop)

> Recorded 2026-11-02 on an XFCE 4.16 / X11 laptop with an external monitor, after
> terminals and VS Code became unusably large on the external screen.

**The problem.** X11 has exactly **one** `Xft.dpi` for the whole screen, and XFCE
stores it as `/Xft/DPI` in the `xsettings` channel (Settings → Appearance →
Fonts → Custom DPI). The session where this was measured sets **144**, which
suits the laptop panel but not the external one:

| Output | Mode | Physical size | Real DPI | What 144 gives |
|---|---|---|---|---|
| `eDP-1` laptop panel | 1920×1080 | 309×173 mm | **158** | 0.91× — correct, this is what 144 was tuned for |
| `HDMI-2` external | 1920×1080 | 598×336 mm | **82** | **1.76× too large** |

So on the external a maximized editor behaves like a ~900×500 window: the extra
screen buys no extra content. (VS Code compounded it with
`"window.zoomLevel": 1.0`, another 1.2× on top, so the editor behaved like ~2.1×.)

**The fix.** X11 cannot give two outputs two DPIs, so the external output is
scaled *geometrically* instead — it presents a 2880×1620 desktop into its
1920×1080 panel, which lands UI text at ~96 dpi there, while the laptop panel is
left exactly as it was:

```sh
xrandr --output HDMI-2 --scale 1.5x1.5
```

`scale-external-monitor` wraps that command; `INSTALL.sh` symlinks it to
`~/.local/bin/scale-external-monitor` and **generates**
`~/.config/autostart/external-monitor-scale.desktop`, which runs it at login.
(The entry is generated rather than tracked-and-symlinked because
`desktop-file-validate` rejects `$HOME` inside a quoted `Exec` value, and the
autostart environment does not reliably have `~/.local/bin` on `PATH`.)

```sh
scale-external-monitor --status   # e.g. HDMI-2 connected 2880x1620+1920+0 ...
scale-external-monitor --revert   # back to 1:1
EXTERNAL_SCALE=1.75 scale-external-monitor   # match the real DPI ratio exactly
```

**Why an autostart hook and not the display settings dialog.** xfce4-settings
does store `/Default/<output>/Scale/X|Y` in the `displays` channel, and setting
those to 1.5 *looks* like the persistent answer — but `xfsettingsd` 4.16.2 does
**not** re-apply `Scale` when it loads the profile: with the keys set to 1.5,
reloading `xfsettingsd` put the output back to `1920x1080` (measured 2026-11-02;
note it also *restores* the pre-session geometry when it exits, which is a quick
way to revert by accident). The profile is re-applied at login and on monitor
hotplug, so the hook sleeps 5 s and applies the scale after that, and:

- **After a monitor hotplug** the scale is back to 1:1 — rerun
  `scale-external-monitor`, or log out and back in.
- If the external is unplugged the script no-ops (it checks `xrandr --query`
  first), so autostart stays harmless on laptop-only sessions.

**Tradeoffs.** The external's pixels are rendered at 1.5× and downsampled by the
display engine, so text is slightly soft (grayscale-AA look) and video on that
output goes through an extra scale step; the composite is 4800×1620, which is
fine for integrated graphics in 2D. The worthwhile alternative, if crispness
matters more than the laptop panel:

- Set Custom DPI to **96** (Settings → Appearance → Fonts) and revert the scale:
  external becomes exactly 1:1, but the laptop panel drops to ~0.61× (19 of 30
  GTK dialogs become small).
- Or keep 144 and override per app: Alacritty honours `WINIT_X11_SCALE_FACTOR=1`
  with `font.size` ≈ 11, while VS Code would need a second instance with
  `--force-device-scale-factor=1` — it cannot do per-window DPI.

**Restarting `xfsettingsd` by hand: give it the session's environment.**
`xfsettingsd` also owns the keyboard shortcuts, and it spawns each bound command
with *its own* `PATH`. An instance started from a root shell (or any context that
did not inherit the desktop session) still grabs the keys, but every binding
whose command lives outside the system path dies silently — no window, no error.
Measured 2026-11-02: `Ctrl-Alt-T` → `alacritty` in `~/.cargo/bin` stopped working
after a hand-restart, while bindings to system binaries kept firing.

```sh
# wrong: PATH comes from the caller
setpriv --reuid="$(id -u)" --regid="$(id -g)" --init-groups \
  env HOME="$HOME" DISPLAY="$DISPLAY" xfsettingsd

# right: adopt a session-owned process's environment
mapfile -d '' ENVV < "/proc/$(pgrep -u "$USER" xfce4-panel | head -1)/environ"
setsid nohup env -i "${ENVV[@]}" xfsettingsd &
```

A fresh login also fixes it (the session starts it with the right environment).
Either way the restarted daemon re-applies the saved display profile, which drops
the output back to 1:1 — rerun `scale-external-monitor` afterwards.

Diagnosing: `xrdb -query | grep Xft.dpi` proves the xsettings half is alive, and
`xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Primary><Alt>t'`
shows the binding. A binding that exists and whose grab works but opens nothing
is a `PATH` problem inside the daemon, not a lost key grab.

**Diagnosing a similar box.** `xrandr --query` prints each output's mode and
physical size, so DPI = `width_px * 25.4 / width_mm`; `xrdb -query | grep Xft.dpi`
shows what apps actually get; `xfconf-query -c xsettings -p /Xft/DPI` shows the
stored XFCE value. A ratio above ~1.2 in that third column is the symptom.

### Installation

- Dependencies:

  - [xremap](https://github.com/xremap/xremap)
  - [xdotool](https://github.com/jordansissel/xdotool)
  - [sxhkd](https://github.com/baskerville/sxhkd)

  Run `INSTALL.sh` to verify dependencies and automatically configure necessary permissions (udev rules, user groups) for xremap.

  **Important:** You must log out and log back in (or reboot) after running the script for the group permission changes to take effect.

### See Also

https://vi.stackexchange.com/a/39913/5223
