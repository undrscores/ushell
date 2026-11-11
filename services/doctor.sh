#!/bin/sh
# Check what ushell needs from the system. Prints one line per check: "ok|warn  name  what it is for".
# Arguments: the font families the theme asks for. Used by services/Doctor.qml.
for fam in "$@"; do
    if fc-list : family 2>/dev/null | tr ',' '\n' | grep -qxF "$fam"; then
        echo "ok    font $fam"
    else
        echo "warn  font $fam is not installed; text and icons fall back to the default sans (install a Nerd Font, e.g. pacman -S ttf-jetbrains-mono-nerd)"
    fi
done
check() {   # program, what it is for, [Arch package that provides it, when the name differs]
    if command -v "$1" >/dev/null 2>&1; then echo "ok    $1"; else echo "warn  $1 is missing: $2 (install: pacman -S ${3:-$1})"; fi
}
check python3    "wallpaper colours, clipboard history, calendar, mpd" python
check nmcli      "the network menu" networkmanager
check ddcutil    "monitor brightness (DDC/CI)"
check wlsunset   "night light"
check wl-copy    "clipboard actions" wl-clipboard
check wl-paste   "clipboard history" wl-clipboard
check slurp      "choosing a screenshot / recording region"
check grim       "screenshots"
check wf-recorder "screen recording"
check cava       "the music visualiser"
check notify-send "some confirmation messages" libnotify
check xdg-open   "opening links and files" xdg-utils
check curl       "weather"
check paplay     "the timer's alarm sound" libpulse
if command -v paplay >/dev/null 2>&1 && [ ! -f /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga ]; then
    echo "warn  the timer's alarm sound is missing: /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga (install: pacman -S sound-theme-freedesktop)"
fi
optional() {   # like check, but absence is normal on many machines: reported as "info", not counted as a problem
    if command -v "$1" >/dev/null 2>&1; then echo "ok    $1"; else echo "info  $1 not found: $2"; fi
}
check pacman     "package search and install in the launcher (z)"
check fd         "file search in the launcher (f)"
check uwc        "the compositor ushell is built for"
optional nvidia-smi "GPU stats for NVIDIA cards (the System tab hides the GPU row without it)"

# the login screen (greeter/install.sh): only checked once it is installed
if [ -f /etc/greetd/config.toml ]; then
    for f in /etc/greetd/ushell-greeter/shell.qml /etc/greetd/uwc-greeter.kdl /etc/greetd/uwc-greeter-start /etc/pam.d/greetd ; do
        if [ -e "$f" ]; then echo "ok    greeter file $f"; else echo "warn  greeter file $f is missing: re-run greeter/install.sh"; fi
    done
    command -v uwc-session >/dev/null 2>&1 || echo "warn  uwc-session is not on PATH: the greeter starts the session with it"
    command -v greetd >/dev/null 2>&1 || echo "warn  greetd is not installed but /etc/greetd/config.toml exists"
else
    echo "info  greeter not installed (optional: sudo greeter/install.sh)"
fi
