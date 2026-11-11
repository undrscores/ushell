#!/bin/sh
# Check what ushell needs from the system. Prints one line per check: "ok|warn  name  what it is for".
# Arguments: the font families the theme asks for. Used by services/Doctor.qml.
for fam in "$@"; do
    if fc-list : family 2>/dev/null | tr ',' '\n' | grep -qxF "$fam"; then
        echo "ok    font $fam"
    else
        echo "warn  font $fam is not installed; text and icons fall back to the default sans (install a Nerd Font)"
    fi
done
check() {   # program, what it is for
    if command -v "$1" >/dev/null 2>&1; then echo "ok    $1"; else echo "warn  $1 is missing: $2"; fi
}
check python3    "wallpaper colours, clipboard history, calendar, mpd"
check nmcli      "the network menu"
check ddcutil    "monitor brightness (DDC/CI)"
check wlsunset   "night light"
check wl-copy    "clipboard actions"
check wl-paste   "clipboard history"
check slurp      "choosing a screenshot / recording region"
check grim       "screenshots"
check wf-recorder "screen recording"
check cava       "the music visualiser"
check notify-send "some confirmation messages"
check xdg-open   "opening links and files"
check curl       "weather"
