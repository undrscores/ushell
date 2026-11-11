# ushell

A [Quickshell](https://quickshell.org) desktop shell for the `uwc` Wayland compositor: bar, launcher, notifications,
lock screen, clipboard history, wallpaper picker, calendar, canvas minimap and more, with a theme that follows the wallpaper.
It talks to `uwc` over its IPC socket (`$UWC_SOCKET`), so it expects to run inside `uwc`.

## Run it

Put the folder where Quickshell looks for configs and start it:

```sh
ln -s /path/to/ushell ~/.config/quickshell/ushell
qs -c ushell          # or: qs -p /path/to/ushell
```

It reloads by itself when a file changes. Check what is missing from your system with
`qs -c ushell ipc call shell doctor`, or open **Settings → About → System check**.

## What it needs

Required: `quickshell` (developed on 0.3.2), `uwc`, `python3`, a Nerd Font (JetBrainsMono Nerd Font by default).
Each feature needs its own helper, and does nothing without it:

| Feature | Needs |
| --- | --- |
| network menu | `nmcli` (NetworkManager) |
| clipboard history, copy actions | `wl-clipboard` (`wl-copy`, `wl-paste`) |
| screenshots, recording | `grim`, `slurp`, `wf-recorder` |
| night light | `wlsunset` |
| music visualiser | `cava` |
| monitor brightness | `ddcutil` |
| file search (`f `) | `fd` |
| package search (`z `) | `pacman`; an AUR helper (`paru`, `yay`) is used when present |
| weather | `curl` |
| GPU stats | `nvidia-smi` (NVIDIA only) |

## Configuration

* **Settings window** (open it with `qs -c ushell ipc call shell settings general`): everything you can toggle.
  Stored in `~/.local/state/ushell/prefs.json`. If that file is corrupt it is kept as `prefs.json.corrupt` and defaults are used.
* **`~/.config/ushell/config.json`**: optional, for the few things Settings does not cover (terminal, lock command,
  search shortcuts, folders). See `config.example.json`. Invalid keys are ignored with a warning in `qs log`.
* **Backup**: `qs ipc call settings save [PATH]` / `restore [PATH]`, or Settings → About.

## Launcher

Type to search apps and windows. Calculations (`2*(3+4)`) and unit conversions (`5 km in mi`) answer inline. Prefixes:

| Prefix | Mode |
| --- | --- |
| `>` | run a shell command (Shift+Enter: in a terminal) |
| `z` / `pkg` / `pacman` | search, install and remove packages |
| `m` | search and play music from MPD |
| `f` | find files |
| `g`, `yt`, `gh`, `w`, `so`, `maps` | web searches |
| `e` | emoji picker |
| `c` | clipboard history |
| `?` | list of modes |

## Control from a key binding or script

Everything is reachable with `qs -c ushell ipc call <target> <function> [args]`. Targets: `shell`
(toggle/open/close panels, `settings`, `theme`, `wallpaper`, `brightness`, `doctor`), `launcher`, `notifications`, `modes`
(focus, night light), `timer`, `network`, `capture`, `switcher`, `power`, `lock`, `idle`, `settings`, `auth`, `hud`, `keys`, `wm`, `osd`.
`qs -c ushell ipc show` lists every function with its arguments; the comments above each handler in `shell.qml` explain them.

## Layout

```
shell.qml        entry point: mounts every module, holds the IPC handlers
modules/         one folder per feature (bar, dock, launcher, notifications, settings, ...)
services/        singletons that talk to the system (Wm, Audio, Network, Prefs, Clipboard, ...) and their Python/JS helpers
components/      small reusable widgets (Glass, Slider, Switch, Pill, ...)
config/          Config (config.json), Theme, palette
greeter/         greetd login screen (see greeter/README.md)
scripts/         tests
```

## Tests

```sh
sh scripts/test.sh              # qmldir consistency, Python helpers, headless QML tests (Prefs, Stats, JS libraries)
sh scripts/smoke-overlays.sh    # opens and closes every overlay in a headless uwc (needs a uwc with --headless)
sh scripts/smoke-greeter.sh     # starts the login screen in a headless uwc
```

The first needs only `quickshell` and `python3`; it uses a temporary state folder and never touches your settings.
GitHub Actions runs it on every push (`.github/workflows/test.yml`).

## Login screen

`sudo greeter/install.sh` sets up greetd with a ushell greeter. Read `greeter/README.md` first: it overwrites
`/etc/greetd/config.toml` and `/etc/pam.d/greetd`.
