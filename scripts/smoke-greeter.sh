#!/bin/sh
# Smoke test for the login screen: start a throwaway headless uwc, run greeter/shell.qml in it (with a fake user name
# and no greetd), and fail if it dies or logs QML errors. Does not touch greetd, PAM or your session.
#
#   scripts/smoke-greeter.sh                 uses `uwc` from PATH
#   UWC=/path/to/uwc scripts/smoke-greeter.sh
dir=$(cd "$(dirname "$0")/.." && pwd)
uwc=${UWC:-uwc}
tmp=$(mktemp -d) || exit 2
upid=; qpid=
cleanup() { [ -n "$qpid" ] && kill "$qpid" 2>/dev/null; [ -n "$upid" ] && kill "$upid" 2>/dev/null; rm -rf "$tmp"; }
trap cleanup EXIT INT TERM

: > "$tmp/config.kdl"
"$uwc" --headless 1920x1080 -c "$tmp/config.kdl" > "$tmp/uwc.log" 2>&1 &
upid=$!
display=
for _ in $(seq 1 50); do
    line=$(sed 's/\x1b\[[0-9;]*m//g' "$tmp/uwc.log" | grep "listening on WAYLAND_DISPLAY=" | head -1)
    [ -n "$line" ] && { display=$(echo "$line" | sed 's/.*WAYLAND_DISPLAY=\([^ ]*\).*/\1/'); break; }
    kill -0 "$upid" 2>/dev/null || { echo "FAIL: uwc exited at start-up"; cat "$tmp/uwc.log"; exit 1; }
    sleep 0.2
done
[ -n "$display" ] || { echo "FAIL: uwc never announced its socket"; exit 1; }

# the installed greeter is shell.qml with the user name filled in (install.sh); theme.json is optional
mkdir -p "$tmp/greeter"
sed "s/@USER@/smoketest/" "$dir/greeter/shell.qml" > "$tmp/greeter/shell.qml"
env -u GREETD_SOCK WAYLAND_DISPLAY=$display qs -p "$tmp/greeter" > "$tmp/qs.log" 2>&1 &
qpid=$!
sleep 4
if ! kill -0 "$qpid" 2>/dev/null; then echo "FAIL: the greeter exited at start-up"; cat "$tmp/qs.log"; exit 1; fi
if sed 's/\x1b\[[0-9;]*m//g' "$tmp/qs.log" | grep -E 'ERROR|ReferenceError|TypeError|is not a type|unavailable'; then
    echo "FAIL: the greeter logged QML errors (above)"; exit 1
fi
echo "ok    the greeter started and stayed up"
