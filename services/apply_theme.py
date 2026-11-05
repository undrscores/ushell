#!/usr/bin/env python3
"""Write the shell's current colours out for other programs (terminals, GTK apps, niri borders).

Called by services/ThemeExport.qml with one argument: a JSON object of "#rrggbb" colours
(bg surface surfaceHi fg fgDim accent accent2 accentFg danger ok mode).
Everything lands in $XDG_STATE_HOME/ushell/theme/ and ~/.config/gtk-{3.0,4.0}/gtk.css.
"""
import json, os, sys

c = json.loads(sys.argv[1])
home = os.path.expanduser("~")
state = os.environ.get("XDG_STATE_HOME") or home + "/.local/state"
conf = os.environ.get("XDG_CONFIG_HOME") or home + "/.config"
out = state + "/ushell/theme"
os.makedirs(out, exist_ok=True)


def write(path, text):
    """Only touch the file when it changed (niri reloads on every write)."""
    try:
        with open(path) as f:
            if f.read() == text:
                return
    except OSError:
        pass
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, path)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    ra, rb = rgb(a), rgb(b)
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * t) for x, y in zip(ra, rb))


bg, fg, acc, acc2 = c["bg"], c["fg"], c["accent"], c["accent2"]
dim, surf, hi = c["fgDim"], c["surface"], c["surfaceHi"]
import colorsys


def contrast(a, b):
    def lum(h):
        f = lambda v: v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
        r, g, bl = (f(x / 255) for x in rgb(h))
        return 0.2126 * r + 0.7152 * g + 0.0722 * bl
    x, y = lum(a), lum(b)
    return (max(x, y) + 0.05) / (min(x, y) + 0.05)


def tuned(hue):
    """A terminal colour of the given hue (degrees) that shares the accent's saturation and brightness,
    so the palette feels like one family, eased until it reads on the background."""
    _, s, v = colorsys.rgb_to_hsv(*(x / 255 for x in rgb(acc)))
    light = c.get("mode") == "light"
    s = min(max(s, 0.3), 0.6) if not light else max(s, 0.6)
    while True:
        r, g, b = colorsys.hsv_to_rgb(hue / 360, s, v)
        h = "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))
        if contrast(h, bg) >= 4.5 or v <= 0.35 or v >= 0.99:
            return h
        v = v - 0.04 if light else v + 0.04


red, green, yellow, cyan = tuned(350), tuned(125), tuned(45), tuned(180)

ansi_normal = [surf, red, green, yellow, acc, acc2, cyan, fg]
ansi_bright = [hi, red, green, yellow, acc, acc2, cyan, c["fg"]]
names = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]

# ── alacritty ───────────────────────────────────────────────────────────────
a = f'[colors.primary]\nbackground = "{bg}"\nforeground = "{fg}"\n\n'
a += f'[colors.cursor]\ncursor = "{acc}"\ntext = "{bg}"\n\n'
a += f'[colors.selection]\nbackground = "{hi}"\ntext = "{fg}"\n\n'
a += "[colors.normal]\n" + "".join(f'{n} = "{v}"\n' for n, v in zip(names, ansi_normal)) + "\n"
a += "[colors.bright]\n" + "".join(f'{n} = "{v}"\n' for n, v in zip(names, ansi_bright))
write(out + "/alacritty.toml", a)

# ── foot ────────────────────────────────────────────────────────────────────
nb = lambda h: h.lstrip("#")
sec = "colors-light" if c.get("mode") == "light" else "colors-dark"
f = f"[main]\ninitial-color-theme={'light' if c.get('mode') == 'light' else 'dark'}\n\n[{sec}]\n"
f += f"background={nb(bg)}\nforeground={nb(fg)}\nselection-background={nb(hi)}\nselection-foreground={nb(fg)}\n"
f += f"cursor={nb(bg)} {nb(acc)}\n"
for i, v in enumerate(ansi_normal):
    f += f"regular{i}={nb(v)}\n"
for i, v in enumerate(ansi_bright):
    f += f"bright{i}={nb(v)}\n"
write(out + "/foot.ini", f)

# ── niri borders ────────────────────────────────────────────────────────────
write(out + "/niri-colors.kdl",
      f'layout {{\n    border {{\n        active-color "{acc}"\n        inactive-color "{surf}"\n'
      f'        urgent-color "{red}"\n    }}\n    focus-ring {{\n        active-color "{acc}"\n'
      f'        inactive-color "{surf}"\n    }}\n}}\n')

# ── GTK 3 / 4 (libadwaita named colours + the classic ones) ─────────────────
defs = {
    "accent_color": acc, "accent_bg_color": acc, "accent_fg_color": c["accentFg"],
    "window_bg_color": bg, "window_fg_color": fg,
    "view_bg_color": mix(bg, surf, 0.5), "view_fg_color": fg,
    "headerbar_bg_color": surf, "headerbar_fg_color": fg, "headerbar_border_color": hi,
    "card_bg_color": surf, "card_fg_color": fg,
    "popover_bg_color": surf, "popover_fg_color": fg,
    "sidebar_bg_color": mix(bg, surf, 0.5), "sidebar_fg_color": fg,
    "dialog_bg_color": surf, "dialog_fg_color": fg,
    "destructive_bg_color": red, "success_bg_color": green, "warning_bg_color": yellow, "error_bg_color": red,
    # GTK 3 theme colours
    "theme_bg_color": bg, "theme_fg_color": fg, "theme_base_color": mix(bg, surf, 0.5), "theme_text_color": fg,
    "theme_selected_bg_color": acc, "theme_selected_fg_color": c["accentFg"],
    "insensitive_fg_color": dim, "borders": hi,
}
css = "/* generated by ushell (services/apply_theme.py) - edits are overwritten */\n"
css += "".join(f"@define-color {k} {v};\n" for k, v in defs.items())
for d in ("gtk-3.0", "gtk-4.0"):
    write(f"{conf}/{d}/gtk.css", css)

# ── make sure the terminals pick the colour files up (once, never overwriting) ──
def ensure(path, text):
    if not os.path.exists(path):
        write(path, text)

ensure(conf + "/alacritty/alacritty.toml", f'[general]\nimport = ["{out}/alacritty.toml"]\n')
ensure(conf + "/foot/foot.ini", f"include={out}/foot.ini\n")
