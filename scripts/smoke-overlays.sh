#!/bin/sh
# Smoke test: start a throwaway headless uwc, run ushell in it, open and close every overlay, and fail if
# the shell dies. (This is how "closing a panel kills quickshell" was found: uwc answered the commit that
# follows a layer surface's destroy with a protocol error.) Does not touch your running session.
#
#   scripts/smoke-overlays.sh                 uses `uwc` from PATH
#   UWC=/path/to/uwc scripts/smoke-overlays.sh
#
# Needs uwc (a build that has --headless) and quickshell. Exit status 0 = everything survived.
dir=$(cd "$(dirname "$0")/.." && pwd)
uwc=${UWC:-uwc}
overlays=${OVERLAYS:-"launcher clipboard power wallpapers notifications network bluetooth capture calendar minimap"}
tmp=$(mktemp -d) || exit 2
upid=; qpid=
cleanup() { [ -n "$qpid" ] && kill "$qpid" 2>/dev/null; [ -n "$upid" ] && kill "$upid" 2>/dev/null; rm -rf "$tmp"; }
trap cleanup EXIT INT TERM

: > "$tmp/config.kdl"
"$uwc" --headless 1920x1080 -c "$tmp/config.kdl" > "$tmp/uwc.log" 2>&1 &
upid=$!
display=; sock=
for _ in $(seq 1 50); do
    line=$(sed 's/\x1b\[[0-9;]*m//g' "$tmp/uwc.log" | grep "listening on WAYLAND_DISPLAY=" | head -1)
    if [ -n "$line" ]; then
        display=$(echo "$line" | sed 's/.*WAYLAND_DISPLAY=\([^ ]*\).*/\1/')
        sock=$(echo "$line" | sed 's/.*control socket \(.*\)$/\1/')
        break
    fi
    kill -0 "$upid" 2>/dev/null || { echo "FAIL: uwc exited at start-up"; cat "$tmp/uwc.log"; exit 1; }
    sleep 0.2
done
[ -n "$display" ] || { echo "FAIL: uwc never announced its socket"; exit 1; }

mkdir -p "$tmp/state"
WAYLAND_DISPLAY=$display UWC_SOCKET=$sock UWM_SOCKET=$sock XDG_STATE_HOME=$tmp/state \
    qs -p "$dir" > "$tmp/qs.log" 2>&1 &
qpid=$!
ready=0
for _ in $(seq 1 60); do
    kill -0 "$qpid" 2>/dev/null || { echo "FAIL: quickshell exited at start-up"; cat "$tmp/qs.log"; exit 1; }
    qs ipc --pid "$qpid" call shell close >/dev/null 2>&1 && { ready=1; break; }
    sleep 0.5
done
[ "$ready" = 1 ] || { echo "FAIL: the shell never answered IPC"; cat "$tmp/qs.log"; exit 1; }
sleep 2

fail=0
for name in $overlays; do
    qs ipc --pid "$qpid" call shell toggle "$name" >/dev/null 2>&1; sleep 1.2
    qs ipc --pid "$qpid" call shell close >/dev/null 2>&1;          sleep 1.2
    if kill -0 "$qpid" 2>/dev/null; then echo "ok    $name"; else echo "FAIL  $name: quickshell died"; fail=1; break; fi
done
[ "$fail" = 0 ] && echo "all overlays opened and closed" || { echo "--- quickshell log tail"; tail -5 "$tmp/qs.log"; }
exit $fail
