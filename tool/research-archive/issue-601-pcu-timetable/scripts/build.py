"""Complete pcu-main-2026-2 from the official 2026-2 강의시간편람 PDF (notice 37507).

Existing rows keep their values; rows the earlier extraction skipped are added.
Schedule status follows only what the official listings state directly.
"""
import json, re, sys, collections
sys.path.insert(0, 'scripts')
from classify import decide, listing_slots
from timeconv import slots_std, slots_shared, meetings, nfkc

WT = sys.argv[1]
DS = f'{WT}/assets/timetable/pcu-main-2026-2.json'
ORG = f'{WT}/assets/timetable/organizations/pcu.json'
NOTICE = 'https://hakgwa.pcu.ac.kr/ce/article/depart_ce_notice/37507'
off = json.load(open('official.json'))
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
added, changed, owners = [], [], []
stats = collections.Counter()
fullwidth = [k for k, L in off.items() if any(l['time'] and l['time'] != nfkc(l['time']) for l in L)]
for (k, split), L in groups.items():
    status, reason, timed = decide(L)
    prim = L[0]
    others = [l for l in L[1:] if (l['time'], l['room']) != (prim['time'], prim['room'])]
    other_note = '; '.join(f"{where(l)} {join(l['raw'][8]) if l['room'] is None else (l['time'] or '빈칸') + ' ' + (l['room'] or '빈칸')}" for l in others[:4])
    if k in existing and split is None:
        c = existing[k]
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
    sid = f"pcu/main/2026-2/{code}-{sec}" + (f"/{split}" if split else '')
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
json.dump({'stats': {' / '.join(k) if isinstance(k, tuple) else k: v for k, v in stats.items()}, 'changed': changed, 'added': len(added), 'owners': len(owners), 'fullwidth': fullwidth},
          open('build-report.json', 'w'), ensure_ascii=False, indent=1)
for k, v in sorted(stats.items(), key=str): print(v, k)
print('added', len(added), 'changed', len(changed), 'owners', len(owners), 'total', len(ds['courses']))
