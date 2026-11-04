#!/usr/bin/env python3
"""Clipboard history store (stdlib only), fed by `wl-paste --watch`.

  clipboard_store.py store        record the current clipboard: text, or a PNG image when no text is offered
                                  (the watcher pipes the selection on stdin)
  clipboard_store.py delete ID    remove one entry
  clipboard_store.py pin ID       toggle pinned
  clipboard_store.py clear        remove every unpinned entry
  clipboard_store.py copy ID      put one entry back on the clipboard (via wl-copy)

History lives in ~/.local/state/ushell/clipboard.json, and images next to it in clipboard-images/
(private: files 0600, folders 0700). Anything a password manager marks as secret is never stored.

Entries:  text   {id, time, pinned, text}
          image  {id, time, pinned, text, type: "image", mime, file, hash, bytes}
                 `text` is a label such as "Image 800×600 · 45.0 KB", so searching and sorting work unchanged.
"""
import fcntl, hashlib, json, os, struct, subprocess, sys, time

DIR = os.path.expanduser("~/.local/state/ushell")
FILE = os.path.join(DIR, "clipboard.json")
IMG_DIR = os.path.join(DIR, "clipboard-images")
MAX_ITEMS = 200
MAX_BYTES = 200_000            # text
MAX_IMAGES = 20                # unpinned images kept
MAX_IMAGE_BYTES = 10_000_000   # per image
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
SECRET_HINT = "x-kde-passwordManagerHint"


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
    collect_garbage(items)


def collect_garbage(items):
    """Delete image files no entry refers to any more (deleted, cleared or pruned entries)."""
    wanted = {os.path.basename(i.get("file", "")) for i in items if i.get("type") == "image"}
    try:
        names = os.listdir(IMG_DIR)
    except OSError:
        return
    for name in names:
        if name not in wanted:
            try:
                os.remove(os.path.join(IMG_DIR, name))
            except OSError:
                pass


def clipboard_types():
    """MIME types the current selection offers, or None if wl-paste couldn't say."""
    try:
        res = subprocess.run(["wl-paste", "--list-types"], capture_output=True, text=True, timeout=2)
    except Exception:
        return None
    return res.stdout.split() if res.returncode == 0 else None


def has_text(types):
    return any(t.startswith("text/plain") or t in ("UTF8_STRING", "STRING", "TEXT") for t in types)


def read_stdin():
    """Read the whole stream (so wl-paste never writes into a closed pipe) but keep only the first MAX_BYTES + 1."""
    kept = bytearray()
    while True:
        chunk = sys.stdin.buffer.read(65536)
        if not chunk:
            return bytes(kept)
        room = MAX_BYTES + 1 - len(kept)
        if room > 0:
            kept += chunk[:room]


def png_size(data):
    if data[:8] == PNG_MAGIC and data[12:16] == b"IHDR" and len(data) >= 24:
        return struct.unpack(">II", data[16:24])
    return None


def human(n):
    return "%d KB" % max(1, round(n / 1024)) if n < 1024 * 1024 else "%.1f MB" % (n / (1024 * 1024))


def prune(items):
    """Pinned entries always stay; of the rest keep the newest MAX_ITEMS, at most MAX_IMAGES of them images."""
    keep = [i for i in items if i.get("pinned")]
    rest, images = [], 0
    for i in sorted((i for i in items if not i.get("pinned")), key=lambda i: -i["time"]):
        if i.get("type") == "image":
            if images >= MAX_IMAGES:
                continue
            images += 1
        if len(rest) < MAX_ITEMS:
            rest.append(i)
    return sorted(keep + rest, key=lambda i: -i["time"])


def store_text(items, data):
    if not data or len(data) > MAX_BYTES:
        return None
    text = data.decode("utf-8", "replace")
    if not text.strip():
        return None
    is_same = lambda i: i.get("type") != "image" and i["text"] == text
    old = next((i for i in items if is_same(i)), None)
    pinned = bool(old and old.get("pinned"))
    items = [i for i in items if not is_same(i)]
    items.insert(0, {"id": int(time.time() * 1000), "text": text, "time": int(time.time()), "pinned": pinned})
    return items


def store_image(items):
    try:
        data = subprocess.run(["wl-paste", "--type", "image/png"], capture_output=True, timeout=5).stdout
    except Exception:
        return None
    if not data or len(data) > MAX_IMAGE_BYTES or data[:8] != PNG_MAGIC:
        return None
    digest = hashlib.sha1(data).hexdigest()
    old = next((i for i in items if i.get("type") == "image" and i.get("hash") == digest), None)
    if old:                                   # same picture copied again: move it to the top
        items.remove(old)
        old["time"] = int(time.time())
        items.insert(0, old)
        return items
    os.makedirs(IMG_DIR, mode=0o700, exist_ok=True)
    ident = int(time.time() * 1000)
    name = "%d.png" % ident
    fd = os.open(os.path.join(IMG_DIR, name), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "wb") as f:
        f.write(data)
    size = png_size(data)
    label = "Image" + (" %d×%d" % size if size else "") + " · " + human(len(data))
    items.insert(0, {"id": ident, "text": label, "time": int(time.time()), "pinned": False,
                     "type": "image", "mime": "image/png", "file": name, "hash": digest, "bytes": len(data)})
    return items


def copy_back(item):
    quiet = {"stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
    if item.get("type") == "image":
        try:
            with open(os.path.join(IMG_DIR, os.path.basename(item.get("file", ""))), "rb") as f:
                payload = f.read()
        except OSError:
            return
        subprocess.run(["wl-copy", "--type", item.get("mime", "image/png")], input=payload, **quiet)
    else:
        subprocess.run(["wl-copy"], input=item["text"].encode("utf-8"), **quiet)


def main(argv):
    os.makedirs(DIR, mode=0o700, exist_ok=True)
    cmd = argv[1] if len(argv) > 1 else ""
    data = read_stdin() if cmd == "store" else b""
    with open(os.path.join(DIR, ".clipboard.lock"), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        items = load()
        if cmd == "store":
            types = clipboard_types()
            if types is not None and SECRET_HINT in types:
                return
            if types is None or has_text(types):
                items = store_text(items, data)
            elif "image/png" in types:
                items = store_image(items)
            else:
                return
            if items is None:
                return
            items = prune(items)
        elif cmd == "delete" and len(argv) > 2:
            items = [i for i in items if str(i["id"]) != argv[2]]
        elif cmd == "pin" and len(argv) > 2:
            for i in items:
                if str(i["id"]) == argv[2]:
                    i["pinned"] = not i.get("pinned")
        elif cmd == "clear":
            items = [i for i in items if i.get("pinned")]
        elif cmd == "copy" and len(argv) > 2:
            item = next((i for i in items if str(i["id"]) == argv[2]), None)
            if item:
                copy_back(item)
            return
        else:
            return
        save(items)


if __name__ == "__main__":
    main(sys.argv)
