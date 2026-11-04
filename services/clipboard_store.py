#!/usr/bin/env python3
"""Clipboard history store (stdlib only), fed by `wl-paste --watch`.

  clipboard_store.py store        read clipboard text from stdin and record it
  clipboard_store.py delete ID    remove one entry
  clipboard_store.py pin ID       toggle pinned
  clipboard_store.py clear        remove every unpinned entry

History lives in ~/.local/state/ushell/clipboard.json (private: mode 0600).
Anything a password manager marks as secret is never stored.
"""
import fcntl, json, os, subprocess, sys, time

DIR = os.path.expanduser("~/.local/state/ushell")
FILE = os.path.join(DIR, "clipboard.json")
MAX_ITEMS = 200
MAX_BYTES = 200_000


def load():
    try:
        with open(FILE) as f:
            return json.load(f).get("items", [])
    except FileNotFoundError:
        return []
    except (OSError, ValueError, AttributeError):
        # unreadable or corrupt: keep it aside instead of overwriting it with an empty history
        try:
            os.replace(FILE, FILE + ".corrupt")
        except OSError:
            pass
        return []


def save(items):
    tmp = FILE + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump({"items": items}, f)
    os.replace(tmp, FILE)


def is_secret():
    try:
        out = subprocess.run(["wl-paste", "--list-types"], capture_output=True, text=True, timeout=2).stdout
    except Exception:
        return False
    return "x-kde-passwordManagerHint" in out


def main(argv):
    os.makedirs(DIR, mode=0o700, exist_ok=True)
    with open(os.path.join(DIR, ".clipboard.lock"), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        cmd = argv[1] if len(argv) > 1 else ""
        items = load()
        if cmd == "store":
            data = sys.stdin.buffer.read(MAX_BYTES + 1)
            if not data or len(data) > MAX_BYTES or is_secret():
                return
            text = data.decode("utf-8", "replace")
            if not text.strip():
                return
            old = next((i for i in items if i["text"] == text), None)
            pinned = bool(old and old.get("pinned"))
            items = [i for i in items if i["text"] != text]
            items.insert(0, {"id": int(time.time() * 1000), "text": text, "time": int(time.time()), "pinned": pinned})
            keep = [i for i in items if i.get("pinned")]
            rest = [i for i in items if not i.get("pinned")][:MAX_ITEMS]
            items = sorted(keep + rest, key=lambda i: -i["time"])
        elif cmd == "delete" and len(argv) > 2:
            items = [i for i in items if str(i["id"]) != argv[2]]
        elif cmd == "pin" and len(argv) > 2:
            for i in items:
                if str(i["id"]) == argv[2]:
                    i["pinned"] = not i.get("pinned")
        elif cmd == "clear":
            items = [i for i in items if i.get("pinned")]
        else:
            return
        save(items)


if __name__ == "__main__":
    main(sys.argv)
