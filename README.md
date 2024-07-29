# x-windows-system-config

## Sets up configuration for [X11 based](https://en.wikipedia.org/wiki/X_Window_System) desktops.

- Maps Caps Lock to Esc
- Sets sxhkd (Simple X Hotkey Daemon) to remap C-j, C-j to the file:

  ```
  $ ~/dotfiles/x/remap_keypresses.sh
  ```

  These files in turn run some xdotool commands. Those commands:

  - Check if the focused window is Google Chrome.
  - If TRUE, send C-j or C-k to C-b or C-m, both of which are mappable
    in Chrome.

  Then, in your Chrome vim plugin you can bind what you want C-j and C-k to
  do to C-b / C-m instead.

  This effectively allows us to override Chrome's C-j,C-k behavior, which
  browser plugins can't do.

### Installation

- Dependencies:

  - xdotool
  - [sxhkd](https://github.com/baskerville/sxhkd)

### See Also

https://vi.stackexchange.com/a/39913/5223
