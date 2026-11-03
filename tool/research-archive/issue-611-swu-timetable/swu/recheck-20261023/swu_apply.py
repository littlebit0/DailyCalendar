# 2026-10-23 공식 조회에서 바뀐 강의실만 반영: CLASS 원문 강의실 줄 i -> 교시 조각 i (기존 자산 규칙과 같음)
import json, sys, os
ASSET, RAW = sys.argv[1], sys.argv[2]
d = json.load(open(ASSET, encoding='utf-8'))
rows = json.load(open(os.path.join(RAW, 'list-CCR00101-31211-all.json'), encoding='utf-8'))['root']['openSubList']['row']
rows = [r for r in rows if r['REF_KEY'] == 'CCS_OPEN_SUB 00000000000000334961']
new = rows[-1]  # 기존 자산도 같은 조회의 마지막 행을 저장함
c = next(c for c in d['courses'] if c['sourceId'] == 'swu-2026-2-00000000000000334961')
cls = new['CLASS']
times, rooms = cls.split(' / ', 1)
rooms = [r for r in rooms.split('\r\n') if r]
slots = times.split('/')
assert slots == ['화2', '수3'] and len(rooms) == 2, (slots, rooms)
snap = c['sourceSnapshotSchedules']
assert [s['weekday'] for s in snap] == [2, 3]
bytime = {}
for s, room in zip(snap, rooms):
    s['classroom'] = room
    bytime[(s['startMinute'], s['endMinute'])] = room
for s in c['schedules']:
    s['classroom'] = bytime[(s['startMinute'], s['endMinute'])]
c['sourceSchedule'] = cls
c['sourceClassroom'] = cls.split(' / ', 1)[1]
for sel in c['publicEducationBySelection']:
    e = sel['education']
    for k in list(e):
        if k in new: e[k] = new[k]
open(ASSET, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=2) + '\n')
print(c['sourceSchedule'].encode('unicode_escape').decode(), len(c['schedules']), sorted({(s['weekday'], s['classroom']) for s in c['schedules']}))
