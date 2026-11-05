#!/bin/sh
# Verify that every `pragma Singleton` QML file is registered in its directory's qmldir, and that every
# qmldir `singleton` entry points at an existing file that really is a singleton. A missing entry makes
# the name fail at runtime with "X is not defined", so run this before committing.
#
#   scripts/check-qmldir.sh        (exit status 1 if anything is wrong)
cd "$(dirname "$0")/.." || exit 2
fail=0

for f in $(find . -name '*.qml' -not -path './.git/*' | sort); do
    grep -q '^pragma Singleton' "$f" || continue
    dir=$(dirname "$f"); name=$(basename "$f")
    if ! grep -Eq "^singleton +[A-Za-z0-9_]+ +[0-9.]+ +$name\$" "$dir/qmldir" 2>/dev/null; then
        echo "MISSING: $f is a singleton but is not registered in $dir/qmldir"
        echo "         add: singleton ${name%.qml} 1.0 $name"
        fail=1
    fi
done

for q in $(find . -name qmldir -not -path './.git/*' | sort); do
    dir=$(dirname "$q")
    grep -E '^singleton ' "$q" | while read -r _ type _ file; do
        if [ ! -f "$dir/$file" ]; then
            echo "STALE: $q lists $file, which does not exist"
            exit 1
        fi
        if ! grep -q '^pragma Singleton' "$dir/$file"; then
            echo "BAD: $q lists $file as a singleton, but it has no 'pragma Singleton'"
            exit 1
        fi
        if [ "$type" != "${file%.qml}" ]; then
            echo "NAME: $q registers $file as $type (expected ${file%.qml})"
            exit 1
        fi
    done || fail=1
done

[ "$fail" -eq 0 ] && echo "qmldir OK"
exit $fail
