#!/usr/bin/env python3
"""MPD <-> Quickshell bridge (stdlib only).

  mpd_bridge.py watch            stream one JSON line per state change
  mpd_bridge.py cmd NAME [ARGS]  send a raw MPD command, print its reply
  mpd_bridge.py art URI          fetch cover art for a song, print file path
  mpd_bridge.py search TEXT      search the library, print a JSON list of songs
  mpd_bridge.py playuri URI      add a song to the queue and play it now
  mpd_bridge.py queue URI        add a song to the end of the queue

Host/port come from MPD_HOST / MPD_PORT (default 127.0.0.1:6600).
"""
import hashlib, json, os, select, socket, sys, time

HOST = os.environ.get("MPD_HOST", "127.0.0.1")
PORT = int(os.environ.get("MPD_PORT", "6600"))
CACHE = os.path.expanduser("~/.cache/ushell/mpd-art")


def quote(arg):
    return '"' + str(arg).replace("\\", "\\\\").replace('"', '\\"') + '"'


class Mpd:
    def __init__(self):
        self.sock = socket.create_connection((HOST, PORT), timeout=3)
        self.f = self.sock.makefile("rb")
        if not self.f.readline().startswith(b"OK MPD"):
            raise OSError("not an MPD server")

    def send(self, line):
        self.sock.sendall((line + "\n").encode())

    def read_reply(self):
        """Returns (list of (key, value), binary-or-None)."""
        pairs, binary = [], None
        while True:
            raw = self.f.readline()
            if not raw:
                raise OSError("connection closed")
            text = raw.rstrip(b"\n").decode("utf-8", "replace")
            if text == "OK":
                return pairs, binary
            if text.startswith("ACK"):
                raise RuntimeError(text)
            key, _, value = text.partition(": ")
            if key == "binary":
                binary = self.f.read(int(value))
                self.f.read(1)  # trailing newline
            else:
                pairs.append((key, value))

    def run(self, line):
        self.send(line)
        return self.read_reply()

    def idle(self, subsystems, timeout):
        """Sleep inside MPD's `idle` until one of the subsystems changes, or `timeout` seconds pass.

        select() waits on the raw socket (a read timeout would poison the buffered reader);
        on timeout we send `noidle`, which makes MPD end the idle with a plain OK.
        """
        self.send("idle " + " ".join(subsystems))
        ready, _, _ = select.select([self.sock], [], [], timeout)
        if not ready:
            self.send("noidle")
        self.read_reply()

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


def fetch_art(uri):
    """Embedded picture first, then folder cover. Cached on disk; '' if none."""
    if not uri or "://" in uri:
        return ""
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, hashlib.sha1(uri.encode()).hexdigest())
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return "file://" + path
    if os.path.exists(path + ".none"):
        return ""
    for command in ("readpicture", "albumart"):
        data, total = bytearray(), None
        try:
            m = Mpd()
            while True:
                pairs, binary = m.run("%s %s %d" % (command, quote(uri), len(data)))
                if not binary:
                    break
                if total is None:
                    total = int(dict(pairs).get("size", 0))
                data += binary
                if len(data) >= total:
                    break
            m.close()
        except Exception:
            data = bytearray()
        if data:
            with open(path, "wb") as out:
                out.write(data)
            return "file://" + path
    open(path + ".none", "w").close()
    return ""


def snapshot(m, art_cache):
    status = dict(m.run("status")[0])
    song = dict(m.run("currentsong")[0])
    uri = song.get("file", "")
    if uri not in art_cache:
        art_cache.clear()
        art_cache[uri] = fetch_art(uri)
    title = song.get("Title") or (os.path.splitext(os.path.basename(uri))[0] if uri else "")
    return {
        "online": True,
        "state": status.get("state", "stop"),
        "title": title,
        "artist": song.get("Artist") or song.get("AlbumArtist", ""),
        "album": song.get("Album", ""),
        "uri": uri,
        "elapsed": float(status.get("elapsed", 0) or 0),
        "duration": float(song.get("duration") or status.get("duration") or 0),
        "volume": int(status.get("volume", -1) or -1),
        "art": art_cache[uri],
    }


IDLE_SUBSYSTEMS = ("player", "mixer", "options", "playlist")
IDLE_TIMEOUT = 30  # seconds; also re-syncs `elapsed` so interpolation on the QML side can't drift


def watch():
    """Print one JSON line when something changes. No polling: MPD tells us (idle)."""
    last, art_cache = None, {}
    offline = {"online": False}
    while True:
        try:
            m = Mpd()
            while True:
                snap = snapshot(m, art_cache)
                if snap != last:
                    print(json.dumps(snap), flush=True)
                    last = snap
                m.idle(IDLE_SUBSYSTEMS, IDLE_TIMEOUT)
        except BrokenPipeError:
            return  # Quickshell went away
        except Exception:
            try:
                if last != offline:
                    print(json.dumps(offline), flush=True)
            except BrokenPipeError:
                return
            last = offline
            time.sleep(2)


def main(argv):
    if len(argv) >= 2 and argv[1] == "watch":
        watch()
    elif len(argv) >= 3 and argv[1] == "cmd":
        m = Mpd()
        pairs, _ = m.run(" ".join([argv[2]] + [quote(a) for a in argv[3:]]))
        for k, v in pairs:
            print("%s: %s" % (k, v))
    elif len(argv) >= 3 and argv[1] == "art":
        print(fetch_art(argv[2]))
    elif len(argv) >= 3 and argv[1] == "search":
        m = Mpd()
        pairs, _ = m.run("search any %s window 0:40" % quote(argv[2]))
        songs, cur = [], None
        for k, v in pairs:
            if k == "file":
                cur = {"uri": v, "title": "", "artist": "", "album": ""}
                songs.append(cur)
            elif cur is not None and k in ("Title", "Artist", "Album"):
                cur[k.lower()] = v
        for song in songs:
            if not song["title"]:
                song["title"] = os.path.splitext(os.path.basename(song["uri"]))[0]
        print(json.dumps(songs))
    elif len(argv) >= 3 and argv[1] in ("playuri", "queue"):
        m = Mpd()
        pairs, _ = m.run("addid %s" % quote(argv[2]))
        if argv[1] == "playuri":
            m.run("playid %s" % quote(dict(pairs).get("Id", "0")))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
