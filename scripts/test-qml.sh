#!/bin/sh
# Headless QML unit tests: Prefs validation and corrupt-file handling, the Stats and GPU parsers, and the pure JS
# libraries (nm.js, dnd.js, config rules, launcher search / calc / units).
# Runs quickshell with the offscreen Qt platform against scripts/qmltests/shell.qml.in; XDG_STATE_HOME points at a
# temp dir with a deliberately corrupt prefs.json, so your real settings are never read or written.
# Also checks the corrupt file was kept as prefs.json.corrupt. Needs: qs (quickshell). Exit status 0 = all passed.
dir=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d) || exit 2
qpid=
cleanup() { [ -n "$qpid" ] && kill "$qpid" 2>/dev/null; rm -rf "$tmp"; }
trap cleanup EXIT INT TERM

mkdir -p "$tmp/state/ushell"
printf '{"themeMode": "light", oops' > "$tmp/state/ushell/prefs.json"
mkdir -p "$tmp/cfg"
sed "s#@ROOT@#file://$dir#" "$dir/scripts/qmltests/shell.qml.in" > "$tmp/cfg/shell.qml"
XDG_STATE_HOME="$tmp/state" XDG_CONFIG_HOME="$tmp/config" QML_XHR_ALLOW_FILE_READ=1 QT_QPA_PLATFORM=offscreen qs -p "$tmp/cfg" > "$tmp/out.log" 2>&1 &
qpid=$!
for _ in $(seq 1 100); do
    grep -q 'TESTS DONE' "$tmp/out.log" && break
    kill -0 "$qpid" 2>/dev/null || break
    sleep 0.2
done
sed 's/\x1b\[[0-9;]*m//g' "$tmp/out.log" | grep -E '^(.* DEBUG.*qml: )?(ok  |FAIL|TESTS DONE)' | sed 's/.*qml: //'
status=1
grep -q 'TESTS DONE: all' "$tmp/out.log" && status=0
if [ -f "$tmp/state/ushell/prefs.json.corrupt" ] && grep -q oops "$tmp/state/ushell/prefs.json.corrupt"; then
    echo "ok   prefs: the corrupt file was kept as prefs.json.corrupt"
else
    echo "FAIL prefs: the corrupt file was not kept"; status=1
fi
[ "$status" = 0 ] || { echo "--- log ---"; tail -20 "$tmp/out.log"; }
exit $status
