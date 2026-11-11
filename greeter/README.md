# ushell greeter (greetd login screen)

`sudo greeter/install.sh [wallpaper.jpg]` installs it on Arch Linux. Run it from your own account with sudo:
the greeter logs in as that user. Check it afterwards with `qs -c ushell ipc call shell doctor`.

## What it needs

| Needs | Why |
| --- | --- |
| `greetd` (pacman) | the login daemon; the script installs it |
| `uwc` and `uwc-session` on `PATH` (`/usr/bin`) | the compositor hosting the greeter, and the command that starts your session after login |
| `gnome-keyring` (optional) | unlocks the login keyring with the typed password (`pam_gnome_keyring.so`) |
| `quickshell` (`qs`) | runs the greeter UI |

## What it writes (all as root)

| Path | Contents |
| --- | --- |
| `/etc/greetd/config.toml` | **overwritten**: VT 1, runs `uwc` with the greeter config as user `greeter` |
| `/etc/greetd/uwc-greeter.kdl` | minimal uwc config (no key binds) |
| `/etc/greetd/uwc-greeter-start` | starts the greeter with `qs -p`, then quits uwc |
| `/etc/greetd/ushell-greeter/` | `shell.qml` (with your user name filled in), `theme.json`, `wallpaper.jpg` |
| `/etc/pam.d/greetd` | **overwritten**: Arch's `system-local-login` stack plus gnome-keyring |
| `getty@tty1.service` | disabled; `greetd.service` enabled |

Back up `/etc/greetd/config.toml` and `/etc/pam.d/greetd` first if you have changed them. A broken PAM file
locks you out of graphical logins; keep a spare TTY (Ctrl+Alt+F2) logged in while you try it.
