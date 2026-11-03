"""연세대 시간표: 50분 교시 구간을 쉬는 시간 포함 60분 슬롯으로 늘리고 연속 교시를 합친다 (#628).
사용: merge_slots_20261024.py <worktree> [--dry]"""
import json, sys, collections, pathlib

IGN = {'startMinute', 'endMinute', 'sourcePeriod', 'sourcePeriods'}
SLOT = 60


def convert(c, strict_groups=True, stats=None):
    out = []
    for m in c['schedules']:
        # 시계 시각을 원문이 직접 적은 구간(75분제)은 그대로 둔다
        if 'explicitSourceHH' in m or m['endMinute'] - m['startMinute'] != 50:
            out.append(m); stats['kept'] += 1; continue
        n = dict(m); n['endMinute'] = m['startMinute'] + SLOT
        out.append(n)
    # 합치기: 같은 날짜·강의실·모드·그룹 종류가 같고 앞 끝과 뒤 시작 간격이 60분 미만
    ign = IGN | (set() if strict_groups else {'sourceGroupIndex', 'sourceSubgroupIndex'})
    res = []; last = {}
    for m in out:
        key = (m['date'], m['classroom'], json.dumps({k: v for k, v in m.items() if k not in ign}, sort_keys=True))
        prev = last.get(key)
        if ('explicitSourceHH' not in m and prev is not None and 'explicitSourceHH' not in prev
                and 0 <= m['startMinute'] - prev['endMinute'] < 60):
            prev['endMinute'] = max(prev['endMinute'], m['endMinute'])
            if 'sourcePeriod' in m or 'sourcePeriod' in prev:
                ps = (prev.get('sourcePeriods') or [prev['sourcePeriod']]) + (m.get('sourcePeriods') or [m['sourcePeriod']])
                rebuilt = {}
                for k, v in prev.items():
                    if k == 'sourcePeriod': rebuilt['sourcePeriods'] = ps
                    elif k == 'sourcePeriods': rebuilt[k] = ps
                    else: rebuilt[k] = v
                prev.clear(); prev.update(rebuilt)
            stats['merged'] += 1
        else:
            e = dict(m); res.append(e); last[key] = e
    # 원래 순서 보존: 날짜 순서가 이미 달라질 수 있으므로 원본 정렬 규칙을 따른다
    return res


def main():
    wt = pathlib.Path(sys.argv[1]); dry = '--dry' in sys.argv
    strict = '--relaxed' not in sys.argv
    tot = collections.Counter()
    for f in ['sinchon', 'international', 'mirae']:
        p = wt / f'assets/timetable/yonsei-{f}-2026-2.json'
        d = json.loads(p.read_text())
        for c in d['courses']:
            st = collections.Counter()
            before = len(c['schedules'])
            if not c['schedules']: continue
            new = convert(c, strict, st)
            tot['before'] += before; tot['after'] += len(new)
            if new != c['schedules']: tot['changedCourses'] += 1
            if len(new) < before: tot['mergedCourses'] += 1
            tot['kept'] += st['kept']
            c['schedules'] = new
        if not dry:
            p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + '\n')
    print(dict(tot))

main()
