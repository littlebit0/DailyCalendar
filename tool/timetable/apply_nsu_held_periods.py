"""Schedule held NSU 2026-2 courses that the public timetables print with a weekday and period.

Held rows were field/clinical practicum or capstone rows (operation unknown) and
rows matching the published closure list. Both now follow the printed slot:
the timetables' own clock (period n = (8+n):00~(8+n):50, e.g. the PDF cell
"10:00~10:50" for 2교시), each slot running to the next period's start.
Per-period rooms (and, for image rows, professors) are kept; contiguous periods
with the same room on one day merge, as in the scheduled rows.
Meeting dates are copied from the dataset's scheduled courses on the same
weekday. Already scheduled courses are left alone. Idempotent.

    python3 tool/timetable/apply_nsu_held_periods.py
"""
import json
from pathlib import Path

PATH = Path('assets/timetable/nsu-unknown-2026-2.json')


def weekday_dates(courses):
    dates = {}
    for c in courses:
        if c['scheduleStatus'] != 'scheduled':
            continue
        for wd in {s['weekday'] for s in c['schedules']}:
            ds = sorted({s['date'] for s in c['schedules'] if s['weekday'] == wd})
            assert dates.setdefault(wd, ds) == ds, (c['sourceId'], wd)
    return dates


def period_cells(c):
    """(weekday, period, room, split key, provenance) for each printed period cell.

    PDF rows keep the cell's row/column; image rows keep the period's professor,
    which also splits a block like the existing scheduled image rows."""
    if 'publicEducationCells' in c:
        return [(x['weekday'], x['period'], x['room'], '',
                 {'sourceRow': x['row'], 'sourceColumn': x['column']})
                for x in c['publicEducationCells']]
    e = c['publicImageEducation']
    rooms = {r['period']: r['classroom'] for r in e.get('readingRegions', [])}
    teachers = e.get('periodProfessors', {})
    out = []
    for p in e['periods']:
        teacher = teachers.get(str(p), e['professor'])
        out.append((e['weekday'], p, rooms.get(p, e['room']), teacher,
                    {'sourcePeriod': p, 'sourceGrade': e['grade'], 'sourceBand': e['imageBand'],
                     'sourceProfessor': teacher}))
    return out


def blocks(cells):
    """[weekday, start, end, room, provenance]; slot = period start to next period start."""
    out = []
    for wd, p, room, key, prov in sorted(cells, key=lambda x: (x[0], x[1])):
        start, end = (8 + p) * 60, (9 + p) * 60
        last = out[-1] if out else None
        if last and last[0] == wd and last[3] == room and last[5] == key and start - last[2] < 60:
            last[2] = max(last[2], end)
        else:
            out.append([wd, start, end, room, prov, key])
    return [b[:5] for b in out]


def meetings(c, dates):
    return sorted(
        ({'date': d, 'weekday': wd, 'startMinute': s, 'endMinute': e, 'classroom': r, **prov}
         for wd, s, e, r, prov in blocks(period_cells(c)) for d in dates[wd]),
        key=lambda x: (x['date'], x['startMinute']))


def apply(data, base_remarks):
    dates = weekday_dates(data['courses'])
    changed = 0
    for c in data['courses']:
        if c['scheduleStatus'] != 'unrecognized':
            continue
        schedules = meetings(c, dates)
        if not schedules:
            continue
        c['schedules'] = schedules
        c['scheduleStatus'] = 'scheduled'
        if 'publicEducationCells' in c and c['remarks'] != base_remarks:
            # Same remarks as the scheduled PDF rows; the old partial-period text is kept.
            c['previousResearchRemarks'] = c['remarks']
            c['remarks'] = base_remarks
        c['resolvedScheduleHoldReason'] = c.pop('scheduleHoldReason', '')
        changed += 1
    return changed


def scheduled_pdf_remarks(data):
    texts = {c['remarks'] for c in data['courses']
             if c['scheduleStatus'] == 'scheduled' and 'publicEducationCells' in c}
    assert len(texts) == 1, texts
    return texts.pop()


def main():
    data = json.loads(PATH.read_text(encoding='utf-8'))
    n = apply(data, scheduled_pdf_remarks(data))
    if n:
        PATH.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print(PATH, 'scheduled', n)


if __name__ == '__main__':
    main()
