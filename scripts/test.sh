#!/bin/sh
# Runs every test that needs only quickshell and python3: qmldir consistency, the Python helpers and the headless QML
# tests. The overlay smoke test needs a headless uwc and is separate (scripts/smoke-overlays.sh).
cd "$(dirname "$0")/.." || exit 2
fail=0
run() { echo "== $1"; shift; "$@" || fail=1; }
run "qmldir" sh scripts/check-qmldir.sh
run "python helpers" python3 -I scripts/test_python.py
run "qml (Prefs, Stats, JS libraries)" sh scripts/test-qml.sh
[ "$fail" = 0 ] && echo "all passed" || echo "SOME TESTS FAILED"
exit $fail
