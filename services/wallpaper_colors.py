#!/usr/bin/env python3
"""Dominant colour of a wallpaper, for the theme's "colours from wallpaper" option.

  wallpaper_colors.py PATH    prints  {"hue", "sat", "hue2", "sat2", "luma"}
                              (hue 0..360 and sat 0..1 for the main colour, hue2/sat2 for a second distinct
                              colour; hue is null for a grey picture, hue2 when there is no second colour), or  {"error": "..."}  and exits 1.

Reads the picture at ~64x64 with the first decoder that works: Pillow, ImageMagick, ffmpeg,
or a built-in PNG reader (stdlib only) as the last resort.
"""
import colorsys, json, math, os, shutil, struct, subprocess, sys, zlib

SIZE = 64
BINS = 36                      # 10 degrees each
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
MAX_PNG_BYTES = 40_000_000     # the built-in reader is slow on huge pictures


def run(cmd):
    res = subprocess.run(cmd, capture_output=True, timeout=15)
    if res.returncode != 0:
        raise RuntimeError(cmd[0] + " failed")
    return res.stdout


def triples(raw):
    return [(raw[i], raw[i + 1], raw[i + 2]) for i in range(0, len(raw) - 2, 3)]


def decode_pil(path):
    from PIL import Image
    with Image.open(path) as img:
        img.draft("RGB", (SIZE * 2, SIZE * 2))      # JPEGs decode at reduced size
        img = img.convert("RGB").resize((SIZE, SIZE))
        return triples(img.tobytes())


def decode_magick(path):
    tool = shutil.which("magick") or shutil.which("convert")
    if not tool:
        raise RuntimeError("no ImageMagick")
    raw = run([tool, path + "[0]", "-resize", "%dx%d!" % (SIZE, SIZE), "-depth", "8", "rgb:-"])
    if len(raw) != SIZE * SIZE * 3:
        raise RuntimeError("unexpected ImageMagick output")
    return triples(raw)


def decode_ffmpeg(path):
    tool = shutil.which("ffmpeg")
    if not tool:
        raise RuntimeError("no ffmpeg")
    raw = run([tool, "-v", "error", "-i", path, "-vf", "scale=%d:%d" % (SIZE, SIZE), "-frames:v", "1",
               "-f", "rawvideo", "-pix_fmt", "rgb24", "-"])
    if len(raw) != SIZE * SIZE * 3:
        raise RuntimeError("unexpected ffmpeg output")
    return triples(raw)


def decode_png(path):
    """8-bit, non-interlaced PNG only; samples ~SIZE x SIZE pixels."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != PNG_MAGIC:
        raise ValueError("not a PNG")
    pos, idat, palette, head = 8, [], b"", None
    while pos + 8 <= len(data):
        n = struct.unpack(">I", data[pos:pos + 4])[0]
        kind, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + n]
        pos += 12 + n
        if kind == b"IHDR":
            head = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            palette = body
        elif kind == b"IDAT":
            idat.append(body)
        elif kind == b"IEND":
            break
    if head is None:
        raise ValueError("no IHDR")
    w, h, depth, ctype, _, _, interlace = head
    if depth != 8 or interlace != 0 or ctype not in (0, 2, 3, 4, 6):
        raise ValueError("PNG variant not supported by the built-in reader")
    if w * h * 4 > MAX_PNG_BYTES:
        raise ValueError("picture too large for the built-in reader")
    bpp = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw = zlib.decompress(b"".join(idat))
    stride = w * bpp
    xstep, ystep = max(1, w // SIZE), max(1, h // SIZE)
    prev = bytearray(stride)
    out = []
    for y in range(h):
        off = y * (stride + 1)
        ftype, line = raw[off], bytearray(raw[off + 1:off + 1 + stride])
        if ftype == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 255
        elif ftype == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif ftype == 3:
            for i in range(stride):
                line[i] = (line[i] + (((line[i - bpp] if i >= bpp else 0) + prev[i]) >> 1)) & 255
        elif ftype == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        elif ftype != 0:
            raise ValueError("bad PNG filter")
        prev = line
        if y % ystep:
            continue
        for x in range(0, w, xstep):
            i = x * bpp
            if ctype in (0, 4):
                out.append((line[i],) * 3)
            elif ctype == 3:
                j = line[i] * 3
                out.append((palette[j], palette[j + 1], palette[j + 2]))
            else:
                out.append((line[i], line[i + 1], line[i + 2]))
    return out


DECODERS = (decode_pil, decode_magick, decode_ffmpeg, decode_png)


def read_pixels(path):
    errors = []
    for decode in DECODERS:
        try:
            pixels = decode(path)
            if pixels:
                return pixels
        except Exception as e:                       # try the next decoder
            errors.append("%s: %s" % (decode.__name__[7:], e))
    raise RuntimeError("; ".join(errors) or "no decoder")


def analyze(pixels):
    """The picture's main colours: the accent hue most of its colourful pixels agree on, and a second,
    clearly different hue when the picture really has one (grey, dark and washed-out pixels barely count).

    Each pixel votes for its hue with the weight saturation x brightness, so a big patch of moderately
    colourful sky beats a few neon pixels, but vivid colours still beat dull ones."""
    weight = [0.0] * BINS
    cos_sum, sin_sum, sat_sum = [0.0] * BINS, [0.0] * BINS, [0.0] * BINS
    luma = 0.0
    for r, g, b in pixels:
        luma += 0.299 * r + 0.587 * g + 0.114 * b
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if s < 0.15 or v < 0.2:
            continue
        wgt = s * v
        k = min(BINS - 1, int(h * BINS))
        weight[k] += wgt
        cos_sum[k] += wgt * math.cos(h * 2 * math.pi)
        sin_sum[k] += wgt * math.sin(h * 2 * math.pi)
        sat_sum[k] += wgt * s
    result = {"luma": round(luma / (255 * max(1, len(pixels))), 3)}
    if sum(weight) < 0.003 * len(pixels):             # practically grey
        return dict(result, hue=None, sat=0.0, hue2=None, sat2=0.0)
    score = [weight[(k - 1) % BINS] * 0.5 + weight[k] + weight[(k + 1) % BINS] * 0.5 for k in range(BINS)]

    def colour(k):
        near = [(k - 1) % BINS, k, (k + 1) % BINS]
        c, s_ = sum(cos_sum[i] for i in near), sum(sin_sum[i] for i in near)
        total = sum(weight[i] for i in near)
        return round((math.degrees(math.atan2(s_, c)) + 360) % 360, 1), round(sum(sat_sum[i] for i in near) / total, 3)

    best = max(range(BINS), key=lambda k: score[k])
    hue, sat = colour(best)
    # second colour: the strongest hue at least 50 degrees away from the first, and at least a third as strong
    far = [k for k in range(BINS) if min((k - best) % BINS, (best - k) % BINS) >= 5]
    best2 = max(far, key=lambda k: score[k])
    if score[best2] >= 0.33 * score[best]:
        hue2, sat2 = colour(best2)
    else:
        hue2, sat2 = None, 0.0
    return dict(result, hue=hue, sat=sat, hue2=hue2, sat2=sat2)


def main(argv):
    if len(argv) < 2 or not os.path.isfile(argv[1]):
        print(json.dumps({"error": "no such file"}))
        return 1
    try:
        print(json.dumps(analyze(read_pixels(argv[1]))))
    except Exception as e:
        print(json.dumps({"error": str(e)[:300]}))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
