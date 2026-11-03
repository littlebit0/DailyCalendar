"""경기대 교시 슬롯을 쉬는 시간 포함으로 바꾸고 연속 구간을 합친다 (학사안내 key=8430).
60분제: 50분 수업+10분 휴식 -> +10분. 90분제(L): 75분+15분 -> +15분."""
import json, sys, collections
p = sys.argv[1]
d = json.load(open(p)); s0 = open(p).read()
before = after = changed = merged = 0
for c in d['courses']:
    sch = c['schedules']
    if not sch: continue
    add = 15 if 'L' in c['sourceSchedule'] else 10
    before += len(sch)
    by = collections.defaultdict(list)
    for s in sch: by[s['date']].append(dict(s, endMinute=s['endMinute'] + add))
    out = []
    for date in [s['date'] for s in sch if True]:
        pass
    seen = []
    for s in sch:
        if s['date'] not in seen: seen.append(s['date'])
    for date in seen:
        cur = None
        for s in sorted(by[date], key=lambda x: x['startMinute']):
            if cur and cur['classroom'] == s['classroom'] and s['startMinute'] - cur['endMinute'] < 60:
                cur['endMinute'] = max(cur['endMinute'], s['endMinute']); continue
            cur = s; out.append(cur)
    # 원래 순서(날짜 -> 시작) 유지가 아닌 기존 순서 유지: 기존 항목 순서에 맞춰 정렬
    order = {}
    for i, s in enumerate(sch): order.setdefault((s['date'], s['weekday']), i)
    out.sort(key=lambda s: (order[(s['date'], s['weekday'])], s['startMinute']))
    c['schedules'] = out
    after += len(out); changed += 1
    if len(out) < len(sch): merged += 1
json.dump(d, open(p, 'w'), indent=2, ensure_ascii=False)
if s0.endswith('\n'): open(p, 'a').write('\n')
print(dict(before=before, after=after, changed=changed, merged=merged))
