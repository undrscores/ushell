#!/usr/bin/env python3
"""Back up and restore ushell's settings as one JSON file.

  backup.py export PATH PREFS_JSON   writes PATH (readable by you only) with the given preferences and config.json
  backup.py read PATH       prints {"ok":true,"prefs":{...},"config":{...}} for a file written by `export`
  backup.py writeconfig CONFIG_JSON  replaces ~/.config/ushell/config.json with that object (the old one is kept as .bak)

Always prints one JSON line: {"ok":true,...} or {"ok":false,"error":"..."}. Standard library only.
"""
import json
import os
import sys
import tempfile
from datetime import datetime

home = os.path.expanduser("~")
conf = (os.environ.get("XDG_CONFIG_HOME") or home + "/.config") + "/ushell/config.json"


def done(**kw):
    print(json.dumps(kw))
    sys.exit(0 if kw.get("ok") else 1)


def expand(p):
    return os.path.expanduser(p)


def load_config():
    try:
        with open(conf, encoding="utf-8") as f:
            j = json.load(f)
        return j if isinstance(j, dict) else {}
    except (OSError, ValueError):
        return {}


def write_private(path, text):
    d = os.path.dirname(path) or "."
    os.makedirs(d, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".ushell-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def main():
    if len(sys.argv) < 2:
        done(ok=False, error="no command")
    cmd = sys.argv[1]
    try:
        if cmd == "export" and len(sys.argv) >= 4:
            prefs = json.loads(sys.argv[3])
            if not isinstance(prefs, dict):
                done(ok=False, error="preferences must be an object")
            path = expand(sys.argv[2])
            bundle = {"app": "ushell", "version": 1, "exported": datetime.now().isoformat(timespec="seconds"),
                      "prefs": prefs, "config": load_config()}
            write_private(path, json.dumps(bundle, indent=2) + "\n")
            done(ok=True, path=path, prefs=len(prefs), config=len(bundle["config"]))
        elif cmd == "read" and len(sys.argv) >= 3:
            path = expand(sys.argv[2])
            with open(path, encoding="utf-8") as f:
                j = json.load(f)
            if not isinstance(j, dict) or j.get("app") != "ushell" or not isinstance(j.get("prefs"), dict):
                done(ok=False, error="not an ushell settings file")
            if j.get("version") != 1:
                done(ok=False, error="unsupported settings file version")
            cfg = j.get("config")
            done(ok=True, prefs=j["prefs"], config=cfg if isinstance(cfg, dict) else {})
        elif cmd == "writeconfig" and len(sys.argv) >= 3:
            cfg = json.loads(sys.argv[2])
            if not isinstance(cfg, dict):
                done(ok=False, error="config must be an object")
            if os.path.exists(conf):
                try:
                    with open(conf, encoding="utf-8") as f:
                        old = f.read()
                    write_private(conf + ".bak", old)
                except OSError:
                    pass
            write_private(conf, json.dumps(cfg, indent=2) + "\n")
            done(ok=True, path=conf)
        else:
            done(ok=False, error="unknown command")
    except FileNotFoundError:
        done(ok=False, error="file not found")
    except (OSError, ValueError) as e:
        done(ok=False, error=str(e))


main()
