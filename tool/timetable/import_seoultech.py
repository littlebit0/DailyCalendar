#!/usr/bin/env python3
"""Validate Seoultech's published regular clock; never infer half periods.

The current official guide confirms periods 0..14 at 08:00..22:50.
Dated future-faculty schedules must use their separately published clocks.
This helper alone does not establish exception dates or per-meeting classrooms.
"""
import re

DAYS = '월화수목금토일'


def regular_meetings(text):
    """Parse all published integer ranges, keeping disjoint same-day blocks.

    Classroom is intentionally blank: source aggregate room order is not a
    reliable association with the order of weekday groups. Keep the aggregate
    separately in sourceClassroom until an explicit association is available.
    """
    if not isinstance(text, str):
        raise ValueError('Invalid Seoultech schedule text')
    if not text.strip():
        return []
    groups = list(re.finditer(r'([월화수목금토일])\(([^()]*)\)', text))
    remainder = re.sub(r'[월화수목금토일]\([^()]*\)', '', text)
    if not groups or not re.fullmatch(r'[\s,]*', remainder):
        raise ValueError('Unrecognized Seoultech schedule')
    periods_by_day = {}
    for group in groups:
        day = DAYS.index(group[1]) + 1
        periods = periods_by_day.setdefault(day, set())
        for block in group[2].split(','):
            match = re.fullmatch(r'\s*(\d+)(?:\s*~\s*(\d+))?\s*', block)
            if not match:
                raise ValueError('Unverified Seoultech half-period clock')
            first, last = int(match[1]), int(match[2] or match[1])
            if not 0 <= first <= last <= 14:
                raise ValueError('Invalid Seoultech period range')
            added = set(range(first, last + 1))
            if periods.intersection(added):
                raise ValueError('Duplicate Seoultech period')
            periods.update(added)
    meetings = []
    for day, periods in sorted(periods_by_day.items()):
        for period in sorted(periods):
            start = 480 + period * 60
            previous = meetings[-1] if meetings else None
            if previous and previous['weekday'] == day and previous['endMinute'] + 10 == start:
                previous['endMinute'] = start + 50
            else:
                meetings.append({'weekday': day, 'startMinute': start,
                                 'endMinute': start + 50, 'classroom': ''})
    return meetings
