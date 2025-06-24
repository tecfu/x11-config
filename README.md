# x11-config

## Introduction

This repo contains configuration files for X11 desktops, specifically Xubuntu

- Key remapping

## X11 configuration files

Note: We have multiple system-level remapping application configurations saved options. Only one of them should be used at a time:

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

- Process started in .xprofile
- No watch feature
- Maps Caps Lock to Esc

### Simple X Hotkey Daemon / skhdrc

- Process started in .xprofile
- No watch feature
- By design cannot effectively remap Caps Lock to Esc
- Calls scripts to remap keys in Google Chrome using xdotool

### Installation

- Dependencies:

  - [xremap](https://github.com/xremap/xremap)
  - [xdotool](https://github.com/jordansissel/xdotool)
  - [sxhkd](https://github.com/baskerville/sxhkd)

### See Also

https://vi.stackexchange.com/a/39913/5223
