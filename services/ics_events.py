#!/usr/bin/env python3
"""List calendar events from .ics files for the calendar panel.

usage: ics_events.py FROM TO PATH...      FROM / TO are dates (YYYY-MM-DD, TO exclusive)

PATH is an .ics file or a folder (searched recursively, e.g. a vdirsyncer / khal calendar). Prints a JSON
list of { title, start, end, allDay, location, calendar } with start / end as local "YYYY-MM-DDTHH:MM"
(all-day events: "YYYY-MM-DD", end exclusive), sorted by start. Recurring events (DAILY / WEEKLY / MONTHLY /
YEARLY with INTERVAL, COUNT, UNTIL, BYDAY, BYMONTHDAY, EXDATE) are expanded inside the window.
Standard library only.
"""
import calendar as cal
import json
import os
import sys
from datetime import date, datetime, timedelta, timezone

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover
    ZoneInfo = None

LOCAL = datetime.now().astimezone().tzinfo
DAYS = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
MAX_OCCURRENCES = 5000


def unfold(text):
    lines = []
    for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if raw[:1] in (" ", "\t") and lines:
            lines[-1] += raw[1:]
        else:
            lines.append(raw)
    return lines


def unescape(v):
    return v.replace("\\n", "\n").replace("\\N", "\n").replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\")


def parse_line(line):
    """'DTSTART;TZID=X:2026...' -> ('DTSTART', {'TZID': 'X'}, '2026...')"""
    if ":" not in line:
        return None
    head, value = line.split(":", 1)
    parts = head.split(";")
    params = {}
    for p in parts[1:]:
        if "=" in p:
            k, v = p.split("=", 1)
            params[k.upper()] = v.strip('"')
    return parts[0].upper(), params, value


def parse_when(value, params):
    """Returns (datetime-or-date, is_date). Datetimes come back timezone-aware in the local zone, except
    floating ones which stay naive wall-clock (treated as local)."""
    v = value.strip()
    if params.get("VALUE") == "DATE" or (len(v) == 8 and v.isdigit()):
        return date(int(v[0:4]), int(v[4:6]), int(v[6:8])), True
    dt = datetime(int(v[0:4]), int(v[4:6]), int(v[6:8]), int(v[9:11]), int(v[11:13]), int(v[13:15]) if len(v) >= 15 else 0)
    if v.endswith("Z"):
        return dt.replace(tzinfo=timezone.utc).astimezone(LOCAL), False
    tzid = params.get("TZID")
    if tzid and ZoneInfo:
        try:
            return dt.replace(tzinfo=ZoneInfo(tzid)).astimezone(LOCAL), False
        except Exception:
            pass
    return dt.replace(tzinfo=LOCAL), False


def parse_duration(v):
    sign = -1 if v.startswith("-") else 1
    v = v.lstrip("+-")[1:]  # drop the leading P
    num, secs, in_time = "", 0, False
    for ch in v:
        if ch == "T":
            in_time = True
        elif ch.isdigit():
            num += ch
        else:
            n = int(num or 0)
            num = ""
            if ch == "W":
                secs += n * 604800
            elif ch == "D":
                secs += n * 86400
            elif ch == "H":
                secs += n * 3600
            elif ch == "M" and in_time:
                secs += n * 60
            elif ch == "S":
                secs += n
    return timedelta(seconds=sign * secs)


def parse_events(text, calname):
    events, cur = [], None
    for line in unfold(text):
        if line == "BEGIN:VEVENT":
            cur = {"props": {}, "exdates": [], "calendar": calname}
        elif line == "END:VEVENT":
            if cur is not None:
                events.append(cur)
            cur = None
        elif cur is not None:
            p = parse_line(line)
            if p is None:
                continue
            name, params, value = p
            if name == "EXDATE":
                for part in value.split(","):
                    try:
                        cur["exdates"].append(parse_when(part, params)[0])
                    except Exception:
                        pass
            elif name in ("DTSTART", "DTEND", "RECURRENCE-ID"):
                try:
                    cur["props"][name] = parse_when(value, params)
                except Exception:
                    pass
            elif name in ("SUMMARY", "LOCATION", "UID", "RRULE", "DURATION", "STATUS"):
                cur["props"][name] = unescape(value) if name in ("SUMMARY", "LOCATION") else value
    return events


def parse_rrule(v):
    r = {}
    for part in v.split(";"):
        if "=" in part:
            k, val = part.split("=", 1)
            r[k.upper()] = val
    return r


def as_day(x):
    return x.date() if isinstance(x, datetime) else x


def occurrences(ev, win_start, win_end):
    """Yield start values (date or aware datetime) of the event inside [win_start, win_end) days."""
    start, is_date = ev["props"]["DTSTART"]
    rr = ev["props"].get("RRULE")
    if not rr:
        yield start
        return
    r = parse_rrule(rr)
    freq = r.get("FREQ")
    interval = max(1, int(r.get("INTERVAL", "1") or 1))
    count = int(r["COUNT"]) if "COUNT" in r else None
    until = None
    until_dt = None
    if "UNTIL" in r:
        try:
            until_v = parse_when(r["UNTIL"], {})[0]
            until = as_day(until_v)
            until_dt = until_v if isinstance(until_v, datetime) else None
        except Exception:
            pass
    byday = []
    for d in r.get("BYDAY", "").split(","):
        d = d.strip()
        if len(d) >= 2 and d[-2:] in DAYS:
            n = d[:-2]
            byday.append((int(n) if n.lstrip("+-").isdigit() else 0, DAYS.index(d[-2:])))
    bymonthday = [int(x) for x in r.get("BYMONTHDAY", "").split(",") if x.lstrip("-").isdigit()]
    base_day = as_day(start)
    time_part = None if is_date else start.timetz()
    exd = {as_day(x) for x in ev["exdates"]}

    def build(day):
        if is_date:
            return day
        return datetime.combine(day, time_part.replace(tzinfo=None)).replace(tzinfo=start.tzinfo)

    produced = 0
    candidates = []

    def over(d):
        """True when the occurrence on day d lies after UNTIL."""
        if until is None:
            return False
        if until_dt is not None and not is_date:
            return build(d) > until_dt
        return d > until

    def month_days(year, month):
        out = []
        last = cal.monthrange(year, month)[1]
        if bymonthday:
            for d in bymonthday:
                dd = d if d > 0 else last + 1 + d
                if 1 <= dd <= last:
                    out.append(date(year, month, dd))
        elif byday:
            for n, wd in byday:
                days = [date(year, month, d) for d in range(1, last + 1) if date(year, month, d).weekday() == wd]
                if n == 0:
                    out.extend(days)
                elif n > 0 and n <= len(days):
                    out.append(days[n - 1])
                elif n < 0 and -n <= len(days):
                    out.append(days[n])
        else:
            if base_day.day <= last:
                out.append(date(year, month, base_day.day))
        return sorted(out)

    # walk period by period from the first occurrence
    if freq == "DAILY":
        period = 0
        while produced < MAX_OCCURRENCES:
            day = base_day + timedelta(days=period * interval)
            if over(day) or day >= win_end:
                break
            candidates = [day]
            period += 1
            for d in candidates:
                produced += 1
                if count is not None and produced > count:
                    return
                if d >= win_start and d not in exd:
                    yield build(d)
    elif freq == "WEEKLY":
        wds = sorted({wd for _, wd in byday}) or [base_day.weekday()]
        week0 = base_day - timedelta(days=base_day.weekday())
        period = 0
        while produced < MAX_OCCURRENCES:
            ws = week0 + timedelta(weeks=period * interval)
            if ws >= win_end or (until and ws > until):
                break
            for wd in wds:
                d = ws + timedelta(days=wd)
                if d < base_day:
                    continue
                if over(d):
                    return
                produced += 1
                if count is not None and produced > count:
                    return
                if d >= win_start and d < win_end and d not in exd:
                    yield build(d)
            period += 1
    elif freq in ("MONTHLY", "YEARLY"):
        step = interval if freq == "MONTHLY" else 12 * interval
        months = 0
        while produced < MAX_OCCURRENCES:
            y = base_day.year + (base_day.month - 1 + months) // 12
            m = (base_day.month - 1 + months) % 12 + 1
            if date(y, m, 1) >= win_end or (until and date(y, m, 1) > until):
                break
            if freq == "YEARLY" and "BYMONTH" in r:
                ok = m in [int(x) for x in r["BYMONTH"].split(",") if x.isdigit()]
                days = month_days(y, m) if ok else []
            elif freq == "YEARLY" and not byday and not bymonthday:
                days = month_days(y, m)
            else:
                days = month_days(y, m)
            for d in days:
                if d < base_day:
                    continue
                if over(d):
                    return
                produced += 1
                if count is not None and produced > count:
                    return
                if d >= win_start and d < win_end and d not in exd:
                    yield build(d)
            months += step


def event_span(ev):
    start, is_date = ev["props"]["DTSTART"]
    end = ev["props"].get("DTEND")
    if end is not None and end[1] == is_date:
        return end[0] - start
    if "DURATION" in ev["props"]:
        try:
            return parse_duration(ev["props"]["DURATION"])
        except Exception:
            pass
    return timedelta(days=1) if is_date else timedelta(0)


def fmt(x):
    if isinstance(x, datetime):
        return x.astimezone(LOCAL).strftime("%Y-%m-%dT%H:%M")
    return x.strftime("%Y-%m-%d")


def collect(paths):
    files = []
    for p in paths:
        p = os.path.expanduser(p)
        if os.path.isdir(p):
            for root, _, names in os.walk(p):
                files.extend(os.path.join(root, n) for n in sorted(names) if n.lower().endswith(".ics"))
        elif os.path.isfile(p):
            files.append(p)
    return files


def main(argv):
    if len(argv) < 3:
        print("[]")
        return
    win_start = date.fromisoformat(argv[1])
    win_end = date.fromisoformat(argv[2])
    out = []
    overridden = set()
    parsed = []
    for f in collect(argv[3:]):
        try:
            with open(f, encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError:
            continue
        name = os.path.basename(os.path.dirname(f)) or os.path.basename(f)
        for ev in parse_events(text, name):
            if "DTSTART" not in ev["props"] or ev["props"].get("STATUS", "").upper() == "CANCELLED":
                continue
            parsed.append(ev)
            if "RECURRENCE-ID" in ev["props"] and "UID" in ev["props"]:
                overridden.add((ev["props"]["UID"], as_day(ev["props"]["RECURRENCE-ID"][0])))

    for ev in parsed:
        span = event_span(ev)
        is_date = ev["props"]["DTSTART"][1]
        uid = ev["props"].get("UID")
        for s in occurrences(ev, win_start - timedelta(days=max(1, span.days + 1)), win_end):
            if "RECURRENCE-ID" not in ev["props"] and uid and (uid, as_day(s)) in overridden:
                continue
            e = s + span
            first = as_day(s)
            last = as_day(e) - timedelta(days=1) if (is_date and e != s) else as_day(e)
            if last < first:
                last = first
            if first >= win_end or last < win_start:
                continue
            out.append({
                "title": ev["props"].get("SUMMARY", "(no title)"),
                "start": fmt(s), "end": fmt(e), "allDay": is_date,
                "location": ev["props"].get("LOCATION", ""), "calendar": ev["calendar"],
            })
    out.sort(key=lambda x: (x["start"], x["title"]))
    print(json.dumps(out))


if __name__ == "__main__":
    main(sys.argv)
