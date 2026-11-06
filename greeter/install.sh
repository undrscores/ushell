#!/bin/sh
# Installs greetd + the ushell greeter. Run as root:  sudo ./greeter/install.sh [wallpaper.jpg]
set -e
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
USER_NAME="${SUDO_USER:-jremover}"
SRC="$(cd "$(dirname "$0")" && pwd)"
zypper --non-interactive install greetd
D=/etc/greetd/ushell-greeter
mkdir -p "$D"
sed "s/@USER@/$USER_NAME/" "$SRC/shell.qml" > "$D/shell.qml"
[ -n "$1" ] && cp "$1" "$D/wallpaper.jpg"
cp "$SRC/niri.kdl" /etc/greetd/niri-greeter.kdl
cp "$SRC/pam-greetd" /etc/pam.d/greetd
cat > /etc/greetd/config.toml <<EOT
[terminal]
vt = 1
[default_session]
command = "niri -c /etc/greetd/niri-greeter.kdl"
user = "greeter"
EOT
id greeter >/dev/null 2>&1 || useradd -M -G video -s /usr/sbin/nologin greeter
chown -R greeter: "$D"
systemctl disable getty@tty1.service 2>/dev/null || true
systemctl enable greetd.service
echo "Done. Reboot (or 'systemctl start greetd' from another TTY) to try it."
