#!/usr/bin/env python3
"""MPD <-> Quickshell bridge (stdlib only).

  mpd_bridge.py watch            stream one JSON line per state change
  mpd_bridge.py cmd NAME [ARGS]  send a raw MPD command, print its reply
  mpd_bridge.py art URI          fetch cover art for a song, print file path
  mpd_bridge.py search TEXT      search the library, print a JSON list of songs
  mpd_bridge.py playuri URI      add a song to the queue and play it now
  mpd_bridge.py queue URI        add a song to the end of the queue

Host/port come from MPD_HOST / MPD_PORT (default 127.0.0.1:6600). MPD_HOST may also be
"password@host", a unix socket path (/run/mpd/socket), or an abstract socket (@name),
the same conventions mpc uses. Errors go to stderr (Quickshell logs them).
"""
import hashlib, json, os, select, socket, sys, threading, time, traceback

PORT = int(os.environ.get("MPD_PORT") or "6600")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "ushell", "mpd-art")


def parse_host(value):
    """MPD_HOST -> (password or None, host, is_unix_socket)."""
    password = None
    if "@" in value and not value.startswith("@"):
        password, value = value.split("@", 1)
    return password, value or "127.0.0.1", value.startswith(("/", "@"))


PASSWORD, HOST, UNIX = parse_host(os.environ.get("MPD_HOST", "127.0.0.1"))


def quote(arg):
    return '"' + str(arg).replace("\\", "\\\\").replace('"', '\\"') + '"'


class Mpd:
    def __init__(self):
        if UNIX:
            self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self.sock.settimeout(3)
            # "@name" is a Linux abstract socket: a leading NUL byte instead of the "@"
            self.sock.connect("\0" + HOST[1:] if HOST.startswith("@") else HOST)
        else:
            self.sock = socket.create_connection((HOST, PORT), timeout=3)
        self.f = self.sock.makefile("rb")
        if not self.f.readline().startswith(b"OK MPD"):
            raise OSError("not an MPD server")
        if PASSWORD:
            self.run("password " + quote(PASSWORD))

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


def snapshot(m):
    """Current player state. `art` is filled in by the caller (cover art is fetched in the background)."""
    status = dict(m.run("status")[0])
    song = dict(m.run("currentsong")[0])
    uri = song.get("file", "")
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
        "art": "",
    }


IDLE_SUBSYSTEMS = ("player", "options", "playlist")
IDLE_TIMEOUT = 30  # seconds; also re-syncs `elapsed` so interpolation on the QML side can't drift


def watch():
    """Print one JSON line when something changes. No polling: MPD tells us (idle).

    Cover art can take a few round trips to fetch, so it never holds up the track info: the line goes out
    at once with art "", and a background thread prints it again with the cover when that is ready.
    """
    lock = threading.RLock()
    art = {}                      # uri -> cover path ('' while pending or if there is none); only the current song
    state = {"last": None, "snap": None}

    def emit(snap):
        with lock:
            if snap == state["last"]:
                return
            state["last"] = snap
            try:
                print(json.dumps(snap), flush=True)
            except BrokenPipeError:
                os._exit(0)       # Quickshell went away (also reached from the art thread)

    def fetch_in_background(uri):
        path = fetch_art(uri)
        with lock:
            if uri not in art or not path:
                return            # the song changed meanwhile, or no cover
            art[uri] = path
            snap = state["snap"]
            if snap and snap.get("uri") == uri:
                state["snap"] = dict(snap, art=path)
                emit(state["snap"])

    offline = {"online": False}
    last_error = ""
    while True:
        try:
            m = Mpd()
            while True:
                snap = snapshot(m)
                last_error = ""
                with lock:
                    uri = snap["uri"]
                    start = uri != "" and uri not in art
                    if uri not in art:
                        art.clear()
                        art[uri] = ""
                    snap["art"] = art[uri]
                    state["snap"] = snap
                    emit(snap)
                if start:
                    threading.Thread(target=fetch_in_background, args=(uri,), daemon=True).start()
                m.idle(IDLE_SUBSYSTEMS, IDLE_TIMEOUT)
        except Exception as e:
            # MPD simply not running (refused / gone) is a one-line note; anything else gets a traceback.
            # Each distinct error is reported once, not every retry.
            msg = "%s: %s" % (type(e).__name__, e)
            # MPD not running (nothing listening / no socket) is the normal offline state, already
            # reported as "offline" to the shell, so it stays quiet.
            quiet = isinstance(e, (ConnectionRefusedError, FileNotFoundError))
            if msg != last_error:
                last_error = msg
                if not quiet:
                    print(msg if isinstance(e, OSError) else traceback.format_exc(), file=sys.stderr, flush=True)
            with lock:
                if state["last"] != offline:
                    state["snap"] = None
                    emit(offline)
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
