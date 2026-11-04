# quickshell-config

A bouncy Quickshell desktop shell for [niri](https://github.com/YaLTeR/niri).

- **Top pill** (auto-hides): clock/calendar, media, volume/quick settings (incl. monitor brightness), settings, power
- **Left dock** (auto-hides): workspaces, pinned + running apps with magnification, clipboard history, tray
- **Right panel** (auto-hides): Media (MPRIS/MPD + cava), System, Weather tabs
- **Launcher**: apps, windows, calculator, system actions, zypper, music, files, web

## Requirements
`quickshell`, `niri`, a Nerd Font (`Symbols Nerd Font`), `wl-clipboard`, `cava`, `ddcutil` (brightness),
`python3`, `curl`, `fd`; optional `mpd`, `playerctl`.

## Install
```sh
git clone <this repo> ~/projects/quickshell-config
ln -s ~/projects/quickshell-config ~/.config/quickshell
```
Start with `qs` (e.g. `spawn-at-startup "qs"` in niri). Pinned apps live in `config/Config.qml`;
auto-hide and weather options are in the Settings menu.

## niri keybinds
```kdl
Mod+D        { spawn "qs" "ipc" "call" "launcher" "toggle"; }
Mod+A        { spawn "qs" "ipc" "call" "shell" "toggle" "widgets"; }
Mod+S        { spawn "qs" "ipc" "call" "shell" "toggle" "quicksettings"; }
Mod+Ctrl+V   { spawn "qs" "ipc" "call" "shell" "toggle" "clipboard"; }
Mod+X        { spawn "qs" "ipc" "call" "shell" "toggle" "power"; }
XF86MonBrightnessUp   { spawn "qs" "ipc" "call" "shell" "brightness" "5"; }
XF86MonBrightnessDown { spawn "qs" "ipc" "call" "shell" "brightness" "-5"; }
```
