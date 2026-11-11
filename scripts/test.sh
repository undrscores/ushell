#!/bin/sh
# Runs every test that can run on this machine: Python helpers, headless QML (Prefs / Stats), qmldir consistency,
# and the node tests (skipped when node is not installed). The overlay smoke test needs a headless uwc and is separate
# (scripts/smoke-overlays.sh).
cd "$(dirname "$0")/.." || exit 2
fail=0
run() { echo "== $1"; shift; "$@" || fail=1; }
run "qmldir" sh scripts/check-qmldir.sh
run "python helpers" python3 -I scripts/test_python.py
run "qml (Prefs, Stats)" sh scripts/test-qml.sh
if command -v node >/dev/null 2>&1; then
    run "nm.js" node scripts/test-nm.js
    run "dnd.js" node scripts/test-dnd.js
else
    echo "== node not installed: skipping scripts/test-nm.js and scripts/test-dnd.js"
fi
[ "$fail" = 0 ] && echo "all passed" || echo "SOME TESTS FAILED"
exit $fail
