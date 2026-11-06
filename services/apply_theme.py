#!/usr/bin/env python3
"""Write the shell's current colours out for other programs (terminals, GTK apps, niri borders).

Called by services/ThemeExport.qml with one argument: a JSON object of "#rrggbb" colours
(bg surface surfaceHi fg fgDim accent accent2 accentFg danger ok mode).
Everything lands in $XDG_STATE_HOME/ushell/theme/ and ~/.config/gtk-{3.0,4.0}/gtk.css.
"""
import json, os, subprocess, sys

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


# ── a real GTK theme, so GTK 3 apps (Thunar, ...) follow the palette instead of staying Adwaita grey ──────────
# Adwaita's GTK 3 theme computes most of its colours itself, so named colours alone change very little. The theme
# written here is the stock Adwaita (dark or light) plus explicit rules for the common widgets. Two identical copies
# (ushell-a / ushell-b) are written in turn and the active one is switched through gsettings: running apps reload
# their theme when its name changes, so they follow the wallpaper without being restarted.
base = mix(bg, surf, 0.5)
dark = c.get("mode") != "light"
gtk3 = (
    '@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained%s.css");\n' % ("-dark" if dark else "")
    + css
    + f"""
window, .background {{ background-color: {bg}; color: {fg}; }}
.view, iconview, treeview.view, textview text, .content-view, .view text {{ background-color: {base}; color: {fg}; }}
.view:selected, iconview:selected, treeview.view:selected, row:selected, selection, *:selected {{ background-color: {acc}; color: {c["accentFg"]}; }}
headerbar, .titlebar, toolbar, .toolbar, menubar, .menubar, .primary-toolbar, .inline-toolbar, actionbar {{
    background-image: none; background-color: {surf}; color: {fg}; border-color: {hi}; box-shadow: none; text-shadow: none; }}
.sidebar, placessidebar, placessidebar list, .sidebar list {{ background-color: {base}; color: {fg}; border-color: {hi}; }}
placessidebar row:hover, .sidebar row:hover {{ background-color: {mix(base, hi, 0.5)}; }}
placessidebar row:selected, .sidebar row:selected {{ background-color: {acc}; color: {c["accentFg"]}; }}
button, button.flat, .toolbar button {{ background-image: none; background-color: {surf}; color: {fg}; border-color: {hi}; box-shadow: none; text-shadow: none; }}
button:hover {{ background-color: {hi}; }}
button:checked, button:active, button.toggle:checked {{ background-color: {acc}; color: {c["accentFg"]}; }}
button.suggested-action, button.suggested-action:hover {{ background-color: {acc}; color: {c["accentFg"]}; }}
button.destructive-action, button.destructive-action:hover {{ background-color: {red}; color: {bg}; }}
button:disabled {{ color: {dim}; }}
entry, spinbutton, .entry, combobox entry {{ background-image: none; background-color: {base}; color: {fg}; border-color: {hi}; box-shadow: none; }}
entry:focus, spinbutton:focus {{ border-color: {acc}; }}
menu, .menu, popover, popover.background, .popup, .csd.popup {{ background-color: {surf}; color: {fg}; border-color: {hi}; }}
menuitem:hover, modelbutton:hover, menu menuitem:hover {{ background-color: {acc}; color: {c["accentFg"]}; }}
separator, .separator {{ background-color: {hi}; color: {hi}; }}
scrollbar, scrollbar trough {{ background-color: transparent; }}
scrollbar slider {{ background-color: {hi}; }}
scrollbar slider:hover, scrollbar slider:active {{ background-color: {acc}; }}
tooltip, .tooltip {{ background-color: {surf}; color: {fg}; border: 1px solid {hi}; }}
notebook, notebook > header, notebook > header > tabs > tab {{ background-color: {surf}; color: {fg}; border-color: {hi}; }}
notebook > header > tabs > tab:checked {{ background-color: {bg}; box-shadow: inset 0 -2px {acc}; }}
statusbar, .statusbar {{ color: {dim}; }}
.dim-label, label.dim-label, .subtitle {{ color: {dim}; }}
progressbar progress, scale highlight, scale fill, switch:checked, check:checked, radio:checked {{ background-color: {acc}; border-color: {acc}; color: {c["accentFg"]}; }}
scale trough, progressbar trough, switch {{ background-color: {hi}; border-color: {hi}; }}
link, *:link {{ color: {acc}; }}
placessidebar .sidebar-icon, .sidebar .sidebar-icon, placessidebar row image, .sidebar row image, menuitem image, button image, treeview image, row image {{ color: {fg}; -gtk-icon-effect: none; }}
placessidebar row:selected .sidebar-icon, placessidebar row:selected image, .sidebar row:selected image {{ color: {c["accentFg"]}; }}
"""
)
themes = home + "/.local/share/themes"
cur = None
try:
    cur = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"],
                         capture_output=True, text=True, timeout=5).stdout.strip().strip("'")
except (OSError, subprocess.SubprocessError):
    pass
nxt = "ushell-b" if cur == "ushell-a" else "ushell-a"
for name in ("ushell-a", "ushell-b"):
    write(f"{themes}/{name}/gtk-3.0/gtk.css", gtk3)
    write(f"{themes}/{name}/gtk-4.0/gtk.css", css)
    write(f"{themes}/{name}/index.theme", f"[Desktop Entry]\nType=X-GNOME-Metatheme\nName={name}\nComment=Generated by ushell\n\n[X-GNOME-Metatheme]\nGtkTheme={name}\n")

# prefer-dark for apps that read settings.ini rather than gsettings; other keys in the file are left alone
for d in ("gtk-3.0", "gtk-4.0"):
    path = f"{conf}/{d}/settings.ini"
    try:
        with open(path) as f:
            lines = f.read().splitlines()
    except OSError:
        lines = ["[Settings]"]
    want = {"gtk-application-prefer-dark-theme": "1" if dark else "0", "gtk-theme-name": nxt}
    out_lines, seen = [], set()
    for ln in lines:
        k = ln.split("=", 1)[0].strip()
        if k in want and "=" in ln:
            ln = f"{k}={want[k]}"
            seen.add(k)
        out_lines.append(ln)
    if "[Settings]" not in out_lines:
        out_lines.insert(0, "[Settings]")
    i = out_lines.index("[Settings]") + 1
    for k, v in want.items():
        if k not in seen:
            out_lines.insert(i, f"{k}={v}")
    write(path, "\n".join(out_lines) + "\n")


def gset(key, value):
    try:
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", key, value], capture_output=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        pass


gset("color-scheme", "prefer-dark" if dark else "default")
gset("gtk-theme", nxt)          # a different name each time, so running GTK apps reload

# ── terminals that are already open: set their colours through the standard escape sequences ──────────────
# (new terminals read the files above; a running foot / kitty / alacritty only changes when told to)
seq = "".join(f"\033]4;{i};{v}\033\\" for i, v in enumerate(ansi_normal + ansi_bright))
seq += f"\033]10;{fg}\033\\\033]11;{bg}\033\\\033]12;{acc}\033\\\033]17;{hi}\033\\\033]19;{fg}\033\\"
data = seq.encode()
me = os.getuid()
try:
    pts = os.listdir("/dev/pts")
except OSError:
    pts = []
for name in pts:
    if not name.isdigit():
        continue
    path = "/dev/pts/" + name
    try:
        if os.stat(path).st_uid != me:
            continue
        fd = os.open(path, os.O_WRONLY | os.O_NOCTTY | os.O_NONBLOCK)
        try:
            os.write(fd, data)
        finally:
            os.close(fd)
    except OSError:
        pass
