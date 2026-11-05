#!/usr/bin/env python3
"""Watch the Caps Lock / Num Lock LEDs (stdlib only) and print "<caps> <num>" (0 or 1 each) whenever either
changes, and once at start. The kernel exposes the lock state as LEDs under /sys/class/leds, one per input
device; a lock counts as on when any keyboard shows it on. (sysfs files give no change events, so this
looks four times a second, which costs next to nothing.)"""
import glob
import sys
import time


def state(kind):
    for path in glob.glob("/sys/class/leds/*::" + kind + "/brightness"):
        try:
            with open(path) as f:
                if int(f.read().strip() or 0) > 0:
                    return 1
        except (OSError, ValueError):
            pass
    return 0


last = None
while True:
    now = (state("capslock"), state("numlock"))
    if now != last:
        print("%d %d" % now, flush=True)
        last = now
    time.sleep(0.25)
