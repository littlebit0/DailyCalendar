"""Shared helpers for confirming held (unrecognized) timetable rows.

2026-11-23 user decision: when the official source gives a weekday and a
period or clock time, treat the course as in-person at that time even if the
delivery mode (online, blended, intensive, recorded, ...) is unclear. Periods
missing from an official period table continue with the same slot length.
Rows whose source has no time, or whose sources contradict each other, stay
held. Re-running a confirm_held_<university>.py script is a no-op.
"""
import collections
import datetime
import hashlib
import json
from pathlib import Path

DECISION = ('2026-11-23 사용자 결정: 공식 요일·교시(시각)를 대면 수업 시각으로 확정'
            '(운영 방식 불명확 여부와 무관)')
APPROVED_PATH = Path('test/fixtures/timetable_asset_changes_after_4_0_0.json')


def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def save(path, dataset, reason):
    path = Path(path)
    text = json.dumps(dataset, ensure_ascii=False, separators=(',', ':'))
    if text == path.read_text(encoding='utf-8'):
        return False
    path.write_text(text, encoding='utf-8')
    approved = json.loads(APPROVED_PATH.read_text(encoding='utf-8'))
    key = path.as_posix()
    previous = approved.get(key, {}).get('reason')
    approved[key] = {
        'sha256': hashlib.sha256(text.encode()).hexdigest(),
        'reason': f'{previous}; {reason}' if previous and reason not in previous else previous or reason,
    }
    APPROVED_PATH.write_text(json.dumps(approved, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return True


def merge(meetings, join=True):
    """Join same-weekday, same-room meetings less than 60 minutes apart.

    join=False keeps source clock blocks as written (schools whose source
    prints HH:mm times rather than periods).

    Meetings at the same time in several rooms become one meeting listing
    every room, so a course never holds two identical time blocks.
    """
    rooms = {}
    for m in meetings:
        names = rooms.setdefault((m['weekday'], m['startMinute'], m['endMinute']), [])
        if m['classroom'] not in names:
            names.append(m['classroom'])
    meetings = [{'weekday': w, 'startMinute': s, 'endMinute': e,
                 'classroom': ', '.join(n for n in names if n)}
                for (w, s, e), names in rooms.items()]
    result = []
    for m in sorted(meetings, key=lambda m: (m['weekday'], m['classroom'], m['startMinute'])):
        prior = result[-1] if result else None
        if (join and prior and prior['weekday'] == m['weekday'] and prior['classroom'] == m['classroom']
                and m['startMinute'] - prior['endMinute'] < 60):
            prior['endMinute'] = max(prior['endMinute'], m['endMinute'])
        else:
            result.append(dict(m))
    for m in result:
        if not (0 <= m['startMinute'] < m['endMinute'] <= 1440 and 1 <= m['weekday'] <= 7):
            raise ValueError(f'invalid meeting {m}')
    return sorted(result, key=lambda m: (m['weekday'], m['startMinute']))


def weekday_dates(dataset):
    """Regular weekly dates per weekday, taken from the dataset's own scheduled rows.

    The most common date set per weekday is the school's regular pattern
    (holidays already removed). A weekday no scheduled row uses (e.g. Sunday)
    gets that weekday in every Monday-Sunday week the pattern covers, minus
    the holidays observed on the other weekdays.
    """
    per = collections.defaultdict(collections.Counter)
    for course in dataset['courses']:
        if course.get('scheduleStatus', 'scheduled') != 'scheduled':
            continue
        by_day = collections.defaultdict(set)
        for s in course['schedules']:
            if s.get('date'):
                by_day[s['weekday']].add(s['date'])
        for weekday, dates in by_day.items():
            per[weekday][tuple(sorted(dates))] += 1
    regular = {w: list(c.most_common(1)[0][0]) for w, c in per.items()}
    if not regular:
        return {}
    mondays = sorted({datetime.date.fromisoformat(d) - datetime.timedelta(days=datetime.date.fromisoformat(d).isoweekday() - 1)
                      for ds in regular.values() for d in ds})

    def all_days(weekday):
        return [(monday + datetime.timedelta(days=weekday - 1)).isoformat() for monday in mondays]

    holidays = set()
    for weekday, dates in regular.items():
        lo, hi = dates[0], dates[-1]
        holidays |= {d for d in all_days(weekday) if lo <= d <= hi and d not in dates}
    for weekday in range(1, 8):
        regular.setdefault(weekday, [d for d in all_days(weekday) if d not in holidays])
    return regular


def expand(meetings, dates_by_weekday):
    if not dates_by_weekday:
        return meetings
    out = []
    for m in meetings:
        for date in dates_by_weekday[m['weekday']]:
            out.append({**m, 'date': date})
    return sorted(out, key=lambda s: (s['date'], s['startMinute'], s['classroom']))


def confirm(course, schedules, note, drop=()):
    """Mark a held course as scheduled and record why in its remarks."""
    course['schedules'] = schedules
    course['scheduleStatus'] = 'scheduled'

    def clean(text):
        # drop: exact hold-reason phrases written by the importer.
        text = text or ''
        for phrase in drop:
            text = text.replace(phrase, '')
        lines = [line.strip() for line in text.split('\n')] + [note]
        return '\n'.join(line for line in lines if line)

    if course.get('departmentRemarks'):
        course['departmentRemarks'] = {k: clean(v) for k, v in course['departmentRemarks'].items()}
    else:
        course['remarks'] = clean(course.get('remarks'))
