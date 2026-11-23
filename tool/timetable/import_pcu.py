#!/usr/bin/env python3
"""Complete Pai Chai (pcu) 2026-2 from the official 강의시간편람 PDF.

Source: https://hakgwa.pcu.ac.kr/ce/article/depart_ce_notice/37507
(attachment "2026-2학기 강의시간 편람.pdf").

  extract <handbook.pdf> <rows.json>        (needs PyMuPDF)
  apply   <rows.json> <repository root>     (pure Python)
  apply   <rows_latest.json> <repository root> 2026-11-04   update to the latest edition (LATEST)

`apply` keeps every existing course value. Rows the earlier extraction skipped
are added. A schedule is set only when the official listings state the weekday
and period directly and do not contradict each other; everything else stays
`unrecognized` (listings disagree, weekday omitted, period missing from the
official period table) or `unscheduled` (the handbook prints no weekday/period).
With edition 2026-11-04 (the school homepage file, newer than the August attachment)
existing courses take that edition's weekday/period, room and professor when they
differ (earlier values kept in remarks), its new sections are added, and sections it
no longer prints stay with a remark.
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
    json.dump(rows, open(out, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
    print(len(rows))


DAYS = '월화수목금토일'
# 학사가이드 수업시간표: 50분제는 수업 50분 + 쉬는 시간 10분, 75분제는 수업 75분 + 쉬는 시간 15분.
# 슬롯은 교시 시작부터 다음 교시 시작까지(수업 + 쉬는 시간)이고, Z는 A 시작에서 끊는다(08:10~09:30).
# 0교시 08:00, 1교시 09:00 ... 13교시 21:00. 표에 없는 14교시는 같은 60분 슬롯으로 이어 계산한다
# (2026-11-23 사용자 결정: 표에 없는 교시는 같은 슬롯 길이로 이어 계산).
NUM = {n: (480 + 60 * n, 540 + 60 * n) for n in range(0, 15)}
LET = {'Z': (490, 570), 'A': (570, 660), 'B': (660, 750), 'C': (810, 900), 'D': (900, 990),
       'E': (990, 1080), 'F': (1080, 1170), 'G': (1170, 1260), 'H': (1260, 1350)}
# 같은 날·같은 강의실에서 사이가 이 값(분) 미만이면 한 구간으로 합친다.
MERGE_GAP = 60

def nfkc(s):
    return unicodedata.normalize('NFKC', s or '')

def slots_std(t):
    """'월A,수B' / '월13,월14' / '수D,E' -> [(day, period)] or None if not standard.

    A token without a weekday ('수D,E' -> 수D, 수E) takes the weekday written before it
    (2026-11-23 사용자 결정)."""
    t = nfkc(t)
    if not re.fullmatch(r'([월화수목금토일](\d{1,2}|[A-HZ]))(,[월화수목금토일]?(\d{1,2}|[A-HZ]))*', t):
        return None
    out, day = [], None
    for tok in t.split(','):
        if tok[0] in DAYS:
            day, tok = DAYS.index(tok[0]) + 1, tok[1:]
        out.append((day, tok))
    return out

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
    nonstd = [v for k, v in kinds if k == 'nonstd']
    if len(slotsets) > 1:
        return 'unrecognized', '원문 간 요일·교시 불일치', None
    # 한 목록은 온라인·미배정, 다른 공식 목록은 요일·교시를 적은 경우: 공식 요일·교시를 대면 수업으로
    # 확정한다(2026-11-23 사용자 결정: 운영 방식이 불명확해도 공식 시각이 있으면 확정).
    if slotsets and any(p not in LET and not (p.isdigit() and int(p) in NUM) for ss in slotsets for _, p in ss):
        return 'unrecognized', '공식 수업 시간표에 없는 교시(14교시)', None
    if slotsets:
        # a non-standard listing is confirmed only when its own reading is not needed:
        # another official listing states the same course with explicit weekday per period.
        return 'scheduled', ('비표준 표기, 다른 공식 목록의 명시 표기로 확정' if nonstd else ''), timed[0]
    if nonstd:
        return 'unrecognized', '비표준 교시 표기(요일 생략·기타)', None
    return 'unscheduled', '원문에 요일·교시 없음(' + ','.join(sorted({k for k, v in kinds})) + ')', None


H8 = ['학년', '이수구분', '교과목코드', '교과목명', '학점', '시수', '분반', '담당교수']
CANON = H8 + ['강의시간', '강의실', '비고']
CODE = re.compile(r'[A-Z]{3,4}\d{4,5}')


def _fields(hdr, cells):
    """Header label -> cell text. PyMuPDF splits some 2026-11-04 tables into blank-labelled
    sub-columns; a value (or the tail of a wrapped one, '화5,화6,화7,화' + '8') may sit in any
    sub-column, so each label takes the text of the blank columns that follow it. A merged
    cell PyMuPDF repeats in each sub-column ('DPA22406', 'DPA22406') is taken once."""
    f, cur = {}, None
    for h, c in zip(hdr, cells):
        h = re.sub(r'\s+', '', h or '')
        if h:
            cur = {'교과목명학': '교과목명', '점시수': '학점시수', '강의실매': '강의실'}.get(h, h)
            f.setdefault(cur, '')
        c = c or ''
        if cur is not None and c.strip() and c.strip() != f[cur].strip():
            f[cur] += c
    if '학점시수' in f:  # '교과목명학' / '점시수' header split: cell '3 3'
        f['학점'], f['시수'] = (f.pop('학점시수').split() + ['', ''])[:2]
    return f


def _course_table(hdr):
    return '교과목코드' in hdr and '학년' in hdr and '학기' not in hdr and '강의실및강의시간' not in hdr


def normalize_rows(rows):
    """Rewrite irregular course-table rows into CANON column order (blank sub-columns and split
    labels folded into their label; regular tables keep their columns), drop empty rows, and join a course row the table split in two:
    two consecutive rows of one table are joined when no field is filled differently in both.
    The 2026-08 handbook rows come out with the same values (checked by `selfcheck`)."""
    out, prev = [], None
    has = lambda c, i: bool(re.sub(r'\s+', '', c[i]))
    for r in rows:
        hdr = [re.sub(r'\s+', '', h or '') for h in r['hdr']]
        if not _course_table(hdr):
            out.append(r); prev = None
            continue
        if hdr[:8] == H8 and '' not in hdr and '강의실매' not in hdr:
            hdr, cells = r['hdr'], [c or '' for c in r['cells']]  # regular table: keep its columns
        else:
            f = _fields(hdr, r['cells'])
            hdr, cells = CANON, [f.get(k, '') for k in CANON]
        if not any(has(cells, i) for i in range(len(cells))):
            continue
        key = (r['page'], r['table_y'])
        if prev is not None and prev[0] == key:
            pc = prev[1]['cells']
            sq = lambda c, i: re.sub(r'\s+', '', c[i])
            both = [i for i in range(min(len(pc), len(cells))) if has(pc, i) and has(cells, i)]
            # parts of one printed row: at most one part has the course code and no field is
            # filled differently in both parts
            # (code+name on one line and the rest on another, a professor a line lower,
            # a time/room cell finished on the next line)
            if not (has(pc, 2) and has(cells, 2)) and all(sq(pc, i) == sq(cells, i) for i in both):
                prev[1]['cells'] = [a if re.sub(r'\s+', '', a) else b for a, b in zip(pc, cells)]
                continue
        nr = dict(r, hdr=hdr, cells=cells)
        out.append(nr)
        prev = (key, nr)
    for r in out:
        c = r['cells']
        if r['hdr'] is CANON:
            # the end of a long time cell spilled into the room cell (rooms start with a letter):
            # '..,금6,금' + '7B301' -> '..,금7' + 'B301', '..,목1' + '0B306' -> '..,목10' (PDF 219쪽)
            m = re.match(r'(\d{1,2})(?=[A-Z])', re.sub(r'\s+', '', c[9]))
            if m and re.search(r'[월화수목금토일]\d?$', re.sub(r'\s+', '', c[8])):
                c[8] = re.sub(r'\s+', '', c[8]) + m.group(1)
                c[9] = re.sub(r'\s+', '', c[9])[len(m.group(1)):]
    return out


def official_listings(rows):
    tt=[r for r in normalize_rows(rows) if r['hdr'][:8]==H8]
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
    recs=[x for x in map(rec, tt) if x['code']]  # a stray fragment without any course code
    by=collections.defaultdict(list)
    for x in recs: by[(x['code'],x['sec'])].append(x)
    return {f'{k[0]}-{k[1]}': v for k, v in by.items()}


def join(cell, sep=''):
    lines = [l.strip() for l in (cell or '').split('\n') if l.strip()]
    out = ''
    for l in lines:
        out += (' ' if out.endswith(',') else sep if out else '') + l
    return out


def rooms(cell):
    # a line starting with a letter is another room ('A314\nA311'); a digit continues one ('W21\n0')
    cell = re.sub(r'\n\s*(?=[A-Za-z가-힣])', ',', (cell or '').strip())
    parts = [p.strip() for p in re.split(r'[,/]', join(cell)) if p.strip()]
    return ' / '.join(parts)


def printed(page):
    return page - 6


def rowtext(l):
    return ' '.join(join(c, ' ' if i >= 10 else '') for i, c in enumerate(l['raw']) if join(c))


def where(l):
    return f"인쇄 {printed(l['page'])}쪽(PDF {l['page']}쪽)"


NOTICE = 'https://hakgwa.pcu.ac.kr/ce/article/depart_ce_notice/37507'
# 2026-11-04 갱신본(Last-Modified: Wed, 04 Nov 2026 07:05:17 GMT). 학교 홈페이지 강의시간 편람
# 메뉴(https://www.pcu.ac.kr/kor/contents/155)의 2026-2학기 파일로, 8월 학과 공지 첨부본보다 최신이다.
LATEST = 'https://www.pcu.ac.kr/images/site/kor/pdf/2026-2-handbook.pdf'
EDITIONS = {
    '2026-08': {'name': '2026-2 공식 강의시간편람', 'url': NOTICE, 'dept': (185, 240),
                'file': 'work/issue-601-pcu-timetable/src/handbook.pdf'},
    '2026-11-04': {'name': '2026-2 공식 강의시간편람(2026-11-04 갱신본)', 'url': LATEST, 'dept': (186, 241),
                   'file': 'work/issue-601-pcu-timetable/src/handbook-2026-11-04.pdf'},
}


def offering(L, edition):
    """Course values one handbook edition states for an offering (its listings L)."""
    status, reason, timed = decide(L)
    prim = L[0]
    others = [l for l in L[1:] if (l['time'], l['room']) != (prim['time'], prim['room'])]
    other_note = '; '.join(f"{where(l)} {join(l['raw'][8]) if l['room'] is None else (l['time'] or '빈칸') + ' ' + (l['room'] or '빈칸')}" for l in others[:4])
    room = rooms(prim['raw'][9]) if prim['room'] is not None else ''
    sched = []
    if status == 'scheduled' and timed is not prim and nfkc(room) in UNTIMED | {'-'}:
        room = ''  # '온라인' listing beside a timed one: the room comes from the timed listing
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
    remarks = f"{EDITIONS[edition]['name']} {where(prim)} 원문: {rowtext(prim)}"
    if status == 'unrecognized':
        remarks += f" | 시각 보류: {reason}" + (f" (같은 강좌의 다른 공식 목록: {other_note})" if other_note else '')
    elif status == 'scheduled' and timed is not prim:
        remarks += f" | 시각 근거: {where(timed)} {timed['time']}"
    other_rooms = [f"{where(l)} {l['room']}" for l in L[1:] if l['room'] and nfkc(l['room']) not in ('온라인',) and rooms(l['raw'][9]) != room and prim['room'] is not None]
    if status == 'scheduled' and other_rooms:
        remarks += ' | 다른 공식 목록 강의실: ' + '; '.join(other_rooms[:4])
    return {'status': status, 'reason': reason, 'other_note': other_note, 'schedules': sched, 'room': room,
            'professor': prof, 'remarks': remarks, 'prim': prim,
            'sourceSchedule': ' '.join(x for x in [prof, time_cell, join(prim['raw'][9]) if prim['room'] is not None else '', note] if x)}


def _room_set(r):
    # 'C104(new)' and 'C104' name the same room in the two editions
    return frozenset(x.strip() for x in re.split(r'[,/]', re.sub(r'\(new\)', '', r or '')) if x.strip())


def refresh(c, o):
    """Bring an existing course to the latest edition's values (2026-11-23 사용자 지시: 같은 강좌의
    새 공식 자료가 기존 자료와 다르면 새 자료로 교체). Weekday/period, room and professor are
    compared; a blank professor or room in the latest edition keeps the earlier value.
    The earlier values stay in remarks. Returns True when the course changed."""
    span = lambda s: sorted((m['weekday'], m['startMinute'], m['endMinute']) for m in s)
    nows = lambda s: re.sub(r'\s+', '', s or '')
    if (c['scheduleStatus'] == o['status'] and span(c['schedules']) == span(o['schedules'])
            and (not o['professor'] or nows(c['professor']) == nows(o['professor']))
            and (not o['room'] or _room_set(c['sourceClassroom']) == _room_set(o['room']))):
        return False
    before = (f"상태 {c['scheduleStatus']}, 담당 {c['professor'] or '빈칸'}, 시간 원문 '{c['sourceSchedule'] or '빈칸'}', "
              f"강의실 {c['sourceClassroom'] or '빈칸'}")
    c['scheduleStatus'], c['schedules'] = o['status'], o['schedules']
    c['professor'] = o['professor'] or c['professor']
    c['sourceClassroom'] = o['room'] or c['sourceClassroom']
    c['sourceSchedule'] = o['sourceSchedule']
    c['remarks'] += f" | 최신 편람으로 갱신({LATEST}): {o['remarks']} | 이전 8월 편람 값: {before}"
    return True


def _slot_order(slot):
    day, p = slot[0], slot[1]
    return day, (NUM[int(p)] if p.isdigit() else LET[p])[0]


def settle_conflict(L, c, edition):
    """Listings of the latest edition that disagree on weekday/period (2026-11-23 사용자 결정):
    take the value that differs from the earlier edition's course c (the updated listings);
    when several values differ from it, the value printed in more listings. A tie stays
    unsettled (None). The other listings' values are kept in remarks."""
    span = lambda s: sorted((m['weekday'], m['startMinute'], m['endMinute']) for m in s)
    by = collections.OrderedDict()
    for l in L:
        k, v = listing_slots(l)
        if k == 'slots':
            by.setdefault(v, []).append(l)
    if len(by) < 2:
        return None
    before = span(c['schedules'])
    changed = {v: ls for v, ls in by.items() if span(meetings(sorted(v, key=_slot_order), '')) != before}
    if not changed:
        return None
    ranked = sorted(changed.items(), key=lambda kv: -len(kv[1]))
    if len(ranked) > 1 and len(ranked[0][1]) == len(ranked[1][1]):
        return None
    pick = ranked[0][1]
    rule = ('8월판과 달라진 목록의 값' if len(changed) == 1 else '8월판과 다른 값 중 더 많은 목록에 나온 값')
    o = offering(pick + [l for l in L if listing_slots(l)[0] != 'slots'], edition)
    rest = '; '.join(f"{where(l)} {l['time']} {l['room'] or ''}".strip() for l in L if l not in pick and listing_slots(l)[0] == 'slots')
    o['remarks'] += f" | 갱신본 목록끼리 요일·교시가 달라 {rule}으로 정함(다른 목록: {rest})"
    return o


def apply(rows_path, WT, edition='2026-08'):
    DS = f'{WT}/assets/timetable/pcu-main-2026-2.json'
    ORG = f'{WT}/assets/timetable/organizations/pcu.json'
    ed = EDITIONS[edition]
    off = official_listings(json.load(open(rows_path, encoding='utf-8')))
    ds = json.load(open(DS, encoding='utf-8'))
    org = json.load(open(ORG, encoding='utf-8'))
    labels = {m['sourceLabel']: m for m in org['mappings']}

    # group listings into offerings: code+section, split by course name when the PDF
    # prints one code+section for different courses (사회봉사1~4 share GEN22692).
    groups = collections.OrderedDict()
    for k, L in off.items():
        names = list(dict.fromkeys(l['name'] for l in L))
        # (also when an edition prints only one of them for a section, so it is never matched
        # to another 사회봉사 course of the same code+section)
        if all(re.fullmatch(r'사회봉사\d', n) for n in names):
            for n in names:
                groups[(k, n)] = [l for l in L if l['name'] == n]
        else:
            groups[(k, None)] = L

    existing = {f"{c['courseCode']}-{c['section']}": c for c in ds['courses']}
    existing_by_id = {c['sourceId']: c for c in ds['courses']}
    added, changed, owners, seen = [], [], [], set()
    stats = collections.Counter()
    fullwidth = [k for k, L in off.items() if any(l['time'] and l['time'] != nfkc(l['time']) for l in L)]
    for (k, split), L in groups.items():
        o = offering(L, edition)
        status, reason = o['status'], o['reason']
        c = existing_course(existing, existing_by_id, k, split)
        if c is not None:
            seen.add(c['sourceId'])
            stats[('existing', status, reason)] += 1
            if edition != '2026-08':
                if status == 'unrecognized':
                    o = settle_conflict(L, c, edition) or o
                if refresh(c, o):
                    changed.append(c['sourceId'])
            elif status == 'unrecognized' and c['scheduleStatus'] == 'scheduled':
                c['scheduleStatus'] = 'unrecognized'
                c['schedules'] = []
                c['remarks'] += f" | 시각 보류: {reason}" + (f" (같은 강좌의 다른 공식 목록: {o['other_note']})" if o['other_note'] else '')
                changed.append(c['sourceId'])
            continue
        stats[('new', status, reason)] += 1
        prim = o['prim']
        code, sec = prim['code'], prim['sec']
        sid = source_id(f"{code}-{sec}", split)
        added.append({
            'sourceId': sid, 'campus': 'main', 'academicYear': 2026, 'semester': '2',
            'courseCode': code, 'section': sec, 'courseName': join(prim['raw'][3]), 'professor': o['professor'],
            'classification': prim['cls'], 'credits': float(prim['cr']), 'departments': [],
            'departmentCredits': {}, 'departmentClassifications': {},
            'sourceSchedule': o['sourceSchedule'],
            'sourceClassroom': o['room'], 'remarks': o['remarks'],
            'period': {'startDate': '2026-09-01', 'endDate': '2026-12-18'},
            'scheduleStatus': status, 'schedules': o['schedules'],
        })
        units = []
        lo, hi = ed['dept']
        for l in L:
            if lo <= l['page'] <= hi and l['heading'] in labels and l['heading'] not in [u['sourceLabel'] for u in units]:
                m = labels[l['heading']]
                units.append({
                    'college': m['college'], 'department': m['department'], 'sourceLabel': m['sourceLabel'],
                    'sourceUrl': ed['url'],
                    'evidence': f"Official {ed['name']} PDF page {l['page']} (printed {printed(l['page'])}), academic table heading <{l['heading']}> precedes the exact code+section row; college relationship explicit printed309/310 organization table.",
                    'sourceFile': ed['file'], 'isOfferingUnit': False,
                })
        if units:
            owners.append({'sourceId': sid, 'units': units})

    missing = []
    if edition != '2026-08':
        mark = f" | {ed['name']}({ed['url']})에는 이 분반이 없음: 이전 편람 값 유지(폐강 여부는 판단하지 않음)"
        for c in ds['courses']:
            if c['sourceId'] not in seen:
                missing.append(c['sourceId'])
                if mark not in c['remarks']:
                    c['remarks'] += mark

    ids = [c['sourceId'] for c in ds['courses']] + [c['sourceId'] for c in added]
    assert len(ids) == len(set(ids))
    ds['courses'].extend(added)
    org['courseOwners'].extend(owners)
    json.dump(ds, open(DS, 'w', encoding='utf-8'), ensure_ascii=False, indent=2); open(DS, 'a', encoding='utf-8').write('\n')
    json.dump(org, open(ORG, 'w', encoding='utf-8'), ensure_ascii=False, indent=2); open(ORG, 'a', encoding='utf-8').write('\n')
    print(json.dumps({'changed': changed, 'missing': missing, 'fullwidth': fullwidth}, ensure_ascii=False))
    for k, v in sorted(stats.items(), key=str): print(v, k)
    print('added', len(added), 'changed', len(changed), 'missing', len(missing), 'owners', len(owners), 'total', len(ds['courses']))


if __name__ == '__main__':
    {'extract': extract, 'apply': apply}[sys.argv[1]](*sys.argv[2:])
