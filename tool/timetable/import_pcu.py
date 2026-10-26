#!/usr/bin/env python3
"""Complete Pai Chai (pcu) 2026-2 from the official 강의시간편람 PDF.

Source: https://hakgwa.pcu.ac.kr/ce/article/depart_ce_notice/37507
(attachment "2026-2학기 강의시간 편람.pdf").

  extract <handbook.pdf> <rows.json>        (needs PyMuPDF)
  apply   <rows.json> <repository root>     (pure Python)

`apply` keeps every existing course value. Rows the earlier extraction skipped
are added. A schedule is set only when the official listings state the weekday
and period directly and do not contradict each other; everything else stays
`unrecognized` (listings disagree, weekday omitted, period missing from the
official period table) or `unscheduled` (the handbook prints no weekday/period).
"""
import collections
import json
import re
import sys
import unicodedata


def extract(src, out):
    import fitz
    d = fitz.open(src)
    rows = []
    carry = None
    for pno in range(len(d)):
        page = d[pno]
        if '교과목코드' not in re.sub(r'\s+', '', page.get_text()):
            continue
        tabs = sorted(page.find_tables().tables, key=lambda t: t.bbox[1])
        # text blocks outside tables, for headings
        blocks = [(b[1], b[3], b[0], b[4].strip()) for b in page.get_text('blocks') if b[4].strip()]
        for t in tabs:
            data = t.extract()
            if not data:
                continue
            hdr = [re.sub(r'\s+', '', c or '') for c in data[0]]
            if '교과목코드' not in hdr:
                print('NOHDR', pno + 1, hdr, file=sys.stderr)
                continue
            top = t.bbox[1]
            heads = [b for b in blocks if b[1] <= top + 1]
            heads.sort(key=lambda b: b[0])
            angle = [h[3] for h in heads if h[3].startswith('<')]
            if angle:
                carry = re.sub(r'\s+', '', re.match(r'<([^>]+)>', angle[-1]).group(1))
            for ri, r in enumerate(data[1:]):
                cells = [(c or '').strip() for c in r]
                rows.append({'page': pno + 1, 'table_y': round(top, 1), 'hdr': hdr,
                             'cells': cells, 'heads': [h[3] for h in heads[-4:]], 'heading': carry})
    json.dump(rows, open(out, 'w'), ensure_ascii=False, indent=0)
    print(len(rows))


DAYS = '월화수목금토일'
# 학사가이드 수업시간표: 50분제는 수업 50분 + 쉬는 시간 10분, 75분제는 수업 75분 + 쉬는 시간 15분.
# 슬롯은 교시 시작부터 다음 교시 시작까지(수업 + 쉬는 시간)이고, Z는 A 시작에서 끊는다(08:10~09:30).
NUM = {n: (480 + 60 * n, 540 + 60 * n) for n in range(0, 14)}  # 0교시 08:00, 1교시 09:00 ... 13교시 21:00
LET = {'Z': (490, 570), 'A': (570, 660), 'B': (660, 750), 'C': (810, 900), 'D': (900, 990),
       'E': (990, 1080), 'F': (1080, 1170), 'G': (1170, 1260), 'H': (1260, 1350)}
# 같은 날·같은 강의실에서 사이가 이 값(분) 미만이면 한 구간으로 합친다.
MERGE_GAP = 60

def nfkc(s):
    return unicodedata.normalize('NFKC', s or '')

def slots_std(t):
    """'월A,수B' / '월13,월14' -> [(day, period)] or None if not standard (each token has its own weekday)."""
    t = nfkc(t)
    if not re.fullmatch(r'([월화수목금토일](\d{1,2}|[A-HZ]))(,[월화수목금토일](\d{1,2}|[A-HZ]))*', t):
        return None
    return [(DAYS.index(tok[0]) + 1, tok[1:]) for tok in t.split(',')]

def slots_shared(t):
    """공유혁신 table '강의실및강의시간': 'P408월(D)|P408화(C)' (whitespace removed)."""
    t = nfkc(t)
    out = []
    for seg in t.split('|'):
        m = re.fullmatch(r'([A-Z]{1,3}\d{2,4}(?:-\d)?)([월화수목금토일])\(((?:\d{1,2}|[A-HZ])(?:,(?:\d{1,2}|[A-HZ]))*)\)', seg)
        if not m:
            return None
        for p in m.group(3).split(','):
            out.append((DAYS.index(m.group(2)) + 1, p, m.group(1)))
    return out

def meetings(slots, room):
    """Slots of one day and room whose gap is under MERGE_GAP minutes become one block."""
    res = []
    for s in slots:
        day, p = s[0], s[1]
        r = s[2] if len(s) > 2 else room
        if p.isdigit():
            n = int(p)
            if n not in NUM:
                return None
            st, en = NUM[n]
        else:
            st, en = LET[p]
        for m in res:
            if m['weekday'] == day and m['classroom'] == r and st - m['endMinute'] < MERGE_GAP and m['startMinute'] - en < MERGE_GAP:
                m['startMinute'] = min(m['startMinute'], st)
                m['endMinute'] = max(m['endMinute'], en)
                break
        else:
            res.append({'weekday': day, 'startMinute': st, 'endMinute': en, 'classroom': r})
    return res


UNTIMED = {'온라인', 'X', '미배정'}

def source_id(key, split):
    """Final sourceId of an offering: code-section, plus the course name when one code+section is split."""
    return f"pcu/main/2026-2/{key}" + (f"/{split}" if split else '')


def existing_course(by_key, by_id, key, split):
    """The already-imported course of an offering, so a rerun never adds its sourceId twice."""
    if split is None and key in by_key:
        return by_key[key]
    return by_id.get(source_id(key, split))


def listing_slots(l):
    t = l['time']
    if t is None:
        return ('notime', None)
    t = nfkc(t)
    if t == '' or t == '-':
        # blank time cell; room cell may say 온라인
        return ('online', None) if nfkc(l['room'] or '') == '온라인' else ('blank', None)
    if t in UNTIMED:
        return ('untimed:' + t, None)
    s = slots_shared(t) if l['room'] is None else slots_std(t)
    if s is None:
        return ('nonstd', t)
    return ('slots', frozenset((d, p) for d, p, *_ in s))

def decide(L):
    """Return (status, reason, primary_listing_for_time)."""
    kinds = [listing_slots(l) for l in L]
    slotsets = {v for k, v in kinds if k == 'slots'}
    timed = [l for l, (k, v) in zip(L, kinds) if k == 'slots']
    untimed = {k for k, v in kinds if k.startswith('untimed') or k in ('online', 'notime')}
    nonstd = [v for k, v in kinds if k == 'nonstd']
    if len(slotsets) > 1:
        return 'unrecognized', '원문 간 요일·교시 불일치', None
    if slotsets and untimed - {'notime'}:
        return 'unrecognized', '원문 간 불일치(온라인·미배정과 요일·교시)', None
    if slotsets and any(p not in LET and not (p.isdigit() and int(p) in NUM) for ss in slotsets for _, p in ss):
        return 'unrecognized', '공식 수업 시간표에 없는 교시(14교시)', None
    if slotsets:
        # a non-standard listing is confirmed only when its own reading is not needed:
        # another official listing states the same course with explicit weekday per period.
        return 'scheduled', ('비표준 표기, 다른 공식 목록의 명시 표기로 확정' if nonstd else ''), timed[0]
    if nonstd:
        return 'unrecognized', '비표준 교시 표기(요일 생략·기타)', None
    return 'unscheduled', '원문에 요일·교시 없음(' + ','.join(sorted({k for k, v in kinds})) + ')', None


def official_listings(rows):
    H8=['학년','이수구분','교과목코드','교과목명','학점','시수','분반','담당교수']
    tt=[r for r in rows if r['hdr'][:8]==H8]
    def norm(s): return re.sub(r'\s+','',s or '')
    def rec(r):
        h=r['hdr']; c=r['cells']; f=dict(zip(h,c))
        if '강의실및강의시간' in f:
            time=f['강의실및강의시간']; room=None
        else:
            time=f.get('강의시간'); room=f.get('강의실')
        return {'year':norm(f['학년']),'cls':norm(f['이수구분']),'code':norm(f['교과목코드']),'name':norm(f['교과목명']),
                'cr':norm(f['학점']),'hr':norm(f['시수']),'sec':norm(f['분반']),'prof':norm(f['담당교수']),
                'time':norm(time) if time is not None else None,'room':norm(room) if room is not None else None,
                'note':(f.get('비고') or '').strip(),'page':r['page'],'heading':r['heading'],'raw':c,'heads':r['heads'],'hdr':h}
    recs=[rec(r) for r in tt]
    by=collections.defaultdict(list)
    for x in recs: by[(x['code'],x['sec'])].append(x)
    return {f'{k[0]}-{k[1]}': v for k, v in by.items()}


def apply(rows_path, WT):
    DS = f'{WT}/assets/timetable/pcu-main-2026-2.json'
    ORG = f'{WT}/assets/timetable/organizations/pcu.json'
    NOTICE = 'https://hakgwa.pcu.ac.kr/ce/article/depart_ce_notice/37507'
    off = official_listings(json.load(open(rows_path)))
    ds = json.load(open(DS))
    org = json.load(open(ORG))
    labels = {m['sourceLabel']: m for m in org['mappings']}

    def join(cell, sep=''):
        lines = [l.strip() for l in (cell or '').split('\n') if l.strip()]
        out = ''
        for l in lines:
            out += (' ' if out.endswith(',') else sep if out else '') + l
        return out

    def rooms(cell):
        parts = [p.strip() for p in re.split(r'[,/]', join(cell)) if p.strip()]
        return ' / '.join(parts)

    def printed(page):
        return page - 6

    def rowtext(l):
        return ' '.join(join(c, ' ' if i >= 10 else '') for i, c in enumerate(l['raw']) if join(c))

    def where(l):
        return f"인쇄 {printed(l['page'])}쪽(PDF {l['page']}쪽)"

    # group listings into offerings: code+section, split by course name when the PDF
    # prints one code+section for different courses (사회봉사1~4 share GEN22692).
    groups = collections.OrderedDict()
    for k, L in off.items():
        names = list(dict.fromkeys(l['name'] for l in L))
        if len(names) > 1 and all(re.fullmatch(r'사회봉사\d', n) for n in names):
            for n in names:
                groups[(k, n)] = [l for l in L if l['name'] == n]
        else:
            groups[(k, None)] = L

    existing = {f"{c['courseCode']}-{c['section']}": c for c in ds['courses']}
    existing_by_id = {c['sourceId']: c for c in ds['courses']}
    added, changed, owners = [], [], []
    stats = collections.Counter()
    fullwidth = [k for k, L in off.items() if any(l['time'] and l['time'] != nfkc(l['time']) for l in L)]
    for (k, split), L in groups.items():
        status, reason, timed = decide(L)
        prim = L[0]
        others = [l for l in L[1:] if (l['time'], l['room']) != (prim['time'], prim['room'])]
        other_note = '; '.join(f"{where(l)} {join(l['raw'][8]) if l['room'] is None else (l['time'] or '빈칸') + ' ' + (l['room'] or '빈칸')}" for l in others[:4])
        c = existing_course(existing, existing_by_id, k, split)
        if c is not None:
            stats[('existing', status, reason)] += 1
            if status == 'unrecognized' and c['scheduleStatus'] == 'scheduled':
                c['scheduleStatus'] = 'unrecognized'
                c['schedules'] = []
                c['remarks'] += f" | 시각 보류: {reason}" + (f" (같은 강좌의 다른 공식 목록: {other_note})" if other_note else '')
                changed.append(k)
            continue
        stats[('new', status, reason)] += 1
        code, sec = prim['code'], prim['sec']
        room = rooms(prim['raw'][9]) if prim['room'] is not None else ''
        sched = []
        if status == 'scheduled':
            t = timed['time']
            if timed['room'] is None:
                sl = slots_shared(t); room_for = ''
            else:
                sl = slots_std(t); room_for = rooms(timed['raw'][9])
            sched = meetings(sl, room if timed is prim else (room or room_for))
            if not room:
                room = room_for or ' / '.join(dict.fromkeys(m['classroom'] for m in sched))
        prof = next((join(l['raw'][7]) for l in L if join(l['raw'][7])), '')
        note = join(prim['raw'][10], ' ') if len(prim['raw']) > 10 else ''
        time_cell = join(prim['raw'][8]) if len(prim['raw']) > 8 else ''
        remarks = f"2026-2 공식 강의시간편람 {where(prim)} 원문: {rowtext(prim)}"
        if status == 'unrecognized':
            remarks += f" | 시각 보류: {reason}" + (f" (같은 강좌의 다른 공식 목록: {other_note})" if other_note else '')
        elif status == 'scheduled' and timed is not prim:
            remarks += f" | 시각 근거: {where(timed)} {timed['time']}"
        other_rooms = [f"{where(l)} {l['room']}" for l in L[1:] if l['room'] and nfkc(l['room']) not in ('온라인',) and rooms(l['raw'][9]) != room and prim['room'] is not None]
        if status == 'scheduled' and other_rooms:
            remarks += ' | 다른 공식 목록 강의실: ' + '; '.join(other_rooms[:4])
            stats['room-differs'] += 1
        sid = source_id(f"{code}-{sec}", split)
        added.append({
            'sourceId': sid, 'campus': 'main', 'academicYear': 2026, 'semester': '2',
            'courseCode': code, 'section': sec, 'courseName': join(prim['raw'][3]), 'professor': prof,
            'classification': prim['cls'], 'credits': float(prim['cr']), 'departments': [],
            'departmentCredits': {}, 'departmentClassifications': {},
            'sourceSchedule': ' '.join(x for x in [prof, time_cell, join(prim['raw'][9]) if prim['room'] is not None else '', note] if x),
            'sourceClassroom': room, 'remarks': remarks,
            'period': {'startDate': '2026-09-01', 'endDate': '2026-12-18'},
            'scheduleStatus': status, 'schedules': sched,
        })
        units = []
        for l in L:
            if 185 <= l['page'] <= 240 and l['heading'] in labels and l['heading'] not in [u['sourceLabel'] for u in units]:
                m = labels[l['heading']]
                units.append({
                    'college': m['college'], 'department': m['department'], 'sourceLabel': m['sourceLabel'],
                    'sourceUrl': NOTICE,
                    'evidence': f"Official 2026-2 강의시간편람 PDF page {l['page']} (printed {printed(l['page'])}), academic table heading <{l['heading']}> precedes the exact code+section row; college relationship explicit printed309/310 organization table.",
                    'sourceFile': 'work/issue-601-pcu-timetable/src/handbook.pdf', 'isOfferingUnit': False,
                })
        if units:
            owners.append({'sourceId': sid, 'units': units})

    ids = [c['sourceId'] for c in ds['courses']] + [c['sourceId'] for c in added]
    assert len(ids) == len(set(ids))
    ds['courses'].extend(added)
    org['courseOwners'].extend(owners)
    json.dump(ds, open(DS, 'w'), ensure_ascii=False, indent=2); open(DS, 'a').write('\n')
    json.dump(org, open(ORG, 'w'), ensure_ascii=False, indent=2); open(ORG, 'a').write('\n')
    print(json.dumps({'stats': {' / '.join(k) if isinstance(k, tuple) else k: v for k, v in stats.items()}, 'changed': changed, 'added': len(added), 'owners': len(owners), 'fullwidth': fullwidth},
              ensure_ascii=False, indent=1))
    for k, v in sorted(stats.items(), key=str): print(v, k)
    print('added', len(added), 'changed', len(changed), 'owners', len(owners), 'total', len(ds['courses']))


if __name__ == '__main__':
    {'extract': extract, 'apply': apply}[sys.argv[1]](sys.argv[2], sys.argv[3])
