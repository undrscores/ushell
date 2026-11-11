#!/usr/bin/env python3
"""Tests for the Python helpers (stdlib only).  Run: python3 scripts/test_python.py"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import date, datetime

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SERVICES = os.path.join(ROOT, "services")
STATE = tempfile.mkdtemp(prefix="ushell-test-")
os.environ["XDG_STATE_HOME"] = STATE          # before clipboard_store is imported: it reads this at import time


def load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(SERVICES, name + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ics = load("ics_events")
clip = load("clipboard_store")


def events(text, start, end):
    """Run the calendar helper on one .ics text and return its JSON list."""
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "cal.ics")
        with open(path, "w") as f:
            f.write(text)
        out = subprocess.run([sys.executable, "-I", os.path.join(SERVICES, "ics_events.py"), start, end, path],
                             capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def vevent(*lines):
    return "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\n" + "\r\n".join(lines) + "\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"


class IcsParsing(unittest.TestCase):
    def test_unfold_joins_continuation_lines(self):
        self.assertEqual(ics.unfold("SUMMARY:Hel\r\n lo\r\nX:1"), ["SUMMARY:Hello", "X:1"])

    def test_unescape(self):
        self.assertEqual(ics.unescape(r"a\, b\; c\nd\\e"), "a, b; c\nd\\e")

    def test_parse_line_params(self):
        self.assertEqual(ics.parse_line("DTSTART;TZID=Europe/Berlin:20260101T090000"),
                         ("DTSTART", {"TZID": "Europe/Berlin"}, "20260101T090000"))
        self.assertIsNone(ics.parse_line("no colon here"))

    def test_duration(self):
        self.assertEqual(ics.parse_duration("PT1H30M").total_seconds(), 5400)
        self.assertEqual(ics.parse_duration("P1DT2H").total_seconds(), 93600)
        self.assertEqual(ics.parse_duration("P1W").total_seconds(), 604800)
        self.assertEqual(ics.parse_duration("-PT15M").total_seconds(), -900)

    def test_all_day_vs_timed(self):
        self.assertEqual(ics.parse_when("20260105", {}), (date(2026, 1, 5), True))
        dt, is_date = ics.parse_when("20260105T093000", {})
        self.assertFalse(is_date)
        self.assertEqual((dt.hour, dt.minute), (9, 30))


class IcsEvents(unittest.TestCase):
    def test_single_event_inside_window(self):
        ev = events(vevent("UID:1", "SUMMARY:Dentist", "DTSTART:20260105T090000", "DTEND:20260105T100000"), "2026-01-01", "2026-02-01")
        self.assertEqual([e["title"] for e in ev], ["Dentist"])
        self.assertEqual(ev[0]["start"], "2026-01-05T09:00")
        self.assertFalse(ev[0]["allDay"])

    def test_event_outside_window_is_dropped(self):
        ev = events(vevent("UID:1", "SUMMARY:Later", "DTSTART:20260305T090000", "DTEND:20260305T100000"), "2026-01-01", "2026-02-01")
        self.assertEqual(ev, [])

    def test_all_day_event(self):
        ev = events(vevent("UID:1", "SUMMARY:Holiday", "DTSTART;VALUE=DATE:20260110", "DTEND;VALUE=DATE:20260111"), "2026-01-01", "2026-02-01")
        self.assertEqual(len(ev), 1)
        self.assertTrue(ev[0]["allDay"])
        self.assertEqual(ev[0]["start"], "2026-01-10")

    def test_daily_with_count(self):
        ev = events(vevent("UID:1", "SUMMARY:Standup", "DTSTART:20260105T090000", "DTEND:20260105T091500", "RRULE:FREQ=DAILY;COUNT=3"), "2026-01-01", "2026-02-01")
        self.assertEqual([e["start"][:10] for e in ev], ["2026-01-05", "2026-01-06", "2026-01-07"])

    def test_weekly_byday_with_exdate(self):
        # Mondays and Wednesdays from Mon 5 Jan, one Wednesday excluded
        ev = events(vevent("UID:1", "SUMMARY:Class", "DTSTART:20260105T180000", "DTEND:20260105T190000",
                           "RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4", "EXDATE:20260107T180000"), "2026-01-01", "2026-03-01")
        self.assertEqual([e["start"][:10] for e in ev], ["2026-01-05", "2026-01-12", "2026-01-14"])

    def test_monthly_until(self):
        ev = events(vevent("UID:1", "SUMMARY:Rent", "DTSTART;VALUE=DATE:20260101", "DTEND;VALUE=DATE:20260102",
                           "RRULE:FREQ=MONTHLY;UNTIL=20260301"), "2026-01-01", "2026-12-31")
        self.assertEqual([e["start"] for e in ev], ["2026-01-01", "2026-02-01", "2026-03-01"])

    def test_malformed_event_does_not_crash(self):
        ev = events(vevent("UID:1", "SUMMARY:Broken", "DTSTART:garbage"), "2026-01-01", "2026-02-01")
        self.assertEqual(ev, [])


class ClipboardStore(unittest.TestCase):
    def setUp(self):
        os.makedirs(clip.DIR, exist_ok=True)
        for name in ("clipboard.json", "clipboard.json.corrupt"):
            try:
                os.remove(os.path.join(clip.DIR, name))
            except FileNotFoundError:
                pass

    def test_text_is_stored_newest_first_and_deduplicated(self):
        items = clip.store_text([], b"one")
        items = clip.store_text(items, b"two")
        items = clip.store_text(items, b"one")
        self.assertEqual([i["text"] for i in items], ["one", "two"])

    def test_pin_survives_a_repeat_copy(self):
        items = clip.store_text([], b"keep")
        items[0]["pinned"] = True
        items = clip.store_text(items, b"keep")
        self.assertTrue(items[0]["pinned"])

    def test_blank_and_oversized_text_is_ignored(self):
        self.assertIsNone(clip.store_text([], b"   \n"))
        self.assertIsNone(clip.store_text([], b""))
        self.assertIsNone(clip.store_text([], b"x" * (clip.MAX_BYTES + 1)))

    def test_prune_keeps_pinned_and_caps_the_rest(self):
        items = [{"id": n, "time": n, "text": str(n), "pinned": n == 0} for n in range(clip.MAX_ITEMS + 50)]
        kept = clip.prune(items)
        self.assertEqual(len(kept), clip.MAX_ITEMS + 1)
        self.assertTrue(any(i["id"] == 0 for i in kept))          # the oldest, but pinned

    def test_prune_limits_images(self):
        items = [{"id": n, "time": n, "text": "img", "type": "image", "file": "%d.png" % n} for n in range(clip.MAX_IMAGES + 5)]
        self.assertEqual(len(clip.prune(items)), clip.MAX_IMAGES)

    def test_image_mime_sniffing(self):
        self.assertEqual(clip.image_mime(clip.PNG_MAGIC + b"\0" * 20), "image/png")
        self.assertEqual(clip.image_mime(b"GIF89a" + b"\0" * 20), "image/gif")
        self.assertIsNone(clip.image_mime(b"just text"))

    def test_save_then_load_round_trip_is_private(self):
        clip.save([{"id": 1, "time": 1, "text": "hi", "pinned": False}])
        self.assertEqual(clip.load()[0]["text"], "hi")
        self.assertEqual(os.stat(clip.FILE).st_mode & 0o777, 0o600)

    def test_corrupt_file_is_kept_aside_not_overwritten(self):
        with open(clip.FILE, "w") as f:
            f.write("{not json")
        self.assertEqual(clip.load(), [])
        with open(clip.FILE + ".corrupt") as f:
            self.assertEqual(f.read(), "{not json")

    def test_human_sizes(self):
        self.assertEqual(clip.human(100), "1 KB")
        self.assertEqual(clip.human(2048), "2 KB")
        self.assertEqual(clip.human(3 * 1024 * 1024), "3.0 MB")


if __name__ == "__main__":
    unittest.main(verbosity=1)
