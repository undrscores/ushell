#!/bin/sh
# Installs greetd + the ushell greeter. Run as root:  sudo ./greeter/install.sh [fixed-wallpaper.jpg]
set -e
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
USER_NAME="${SUDO_USER:-$USER}"
SRC="$(cd "$(dirname "$0")" && pwd)"
zypper --non-interactive install greetd
D=/etc/greetd/ushell-greeter
mkdir -p "$D"
sed "s/@USER@/$USER_NAME/" "$SRC/shell.qml" > "$D/shell.qml"
# theme + wallpaper of the user's current ushell setup
STATE="$(getent passwd "$USER_NAME" | cut -d: -f6)/.local/state/ushell"
[ -f "$STATE/theme/greeter.json" ] && cp "$STATE/theme/greeter.json" "$D/theme.json"
# The greeter's wallpaper is fixed: pass one to set/replace it, otherwise the installed one is kept.
# Only the very first install falls back to whatever ushell currently shows.
if [ -n "$1" ]; then WP="$1"
elif [ -f "$D/wallpaper.jpg" ]; then WP=""
else WP="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("wallpaper",""))' "$STATE/prefs.json" 2>/dev/null)"; fi
[ -n "$WP" ] && [ -f "$WP" ] && cp "$WP" "$D/wallpaper.jpg"
cp "$SRC/uwm.kdl" /etc/greetd/uwm-greeter.kdl
install -m 755 "$SRC/start.sh" /etc/greetd/uwm-greeter-start
cp "$SRC/pam-greetd" /etc/pam.d/greetd
cat > /etc/greetd/config.toml <<EOT
[terminal]
vt = 1
[default_session]
command = "uwm -c /etc/greetd/uwm-greeter.kdl -s /etc/greetd/uwm-greeter-start"
user = "greeter"
EOT
id greeter >/dev/null 2>&1 || useradd -M -G video -s /usr/sbin/nologin greeter
chown -R greeter: "$D"
systemctl disable getty@tty1.service 2>/dev/null || true
systemctl enable greetd.service
echo "Done. Reboot (or 'systemctl start greetd' from another TTY) to try it."
