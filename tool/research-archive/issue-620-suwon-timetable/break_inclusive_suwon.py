import json,collections,sys
p='assets/timetable/suwon-unknown-2026-2.json'
raw=open(p,encoding='utf-8').read()
d=json.loads(raw)
def fix(start,end):
    assert (start-570)%60==0 and (end-start+10)%60==0
    return start+(end-start+10)//60*60
changed=merged=before=after=0
for c in d['courses']:
    ch=False
    new=[]
    for s in c['schedules']:
        before+=1
        s['endMinute']=fix(s['startMinute'],s['endMinute']); ch=True
    # merge same date, room, gap<60
    by=collections.defaultdict(list)
    for s in c['schedules']: by[(s['date'],s['classroom'])].append(s)
    out=[]; m=False
    for s in c['schedules']:
        out.append(s)
    res=[]
    for s in sorted(c['schedules'],key=lambda s:(s['date'],s['classroom'],s['startMinute'])):
        if res and res[-1]['date']==s['date'] and res[-1]['classroom']==s['classroom'] and s['startMinute']-res[-1]['endMinute']<60:
            res[-1]['endMinute']=max(res[-1]['endMinute'],s['endMinute']); m=True
        else: res.append(s)
    if m:
        merged+=1
        # restore original order
        order={id(s):i for i,s in enumerate(c['schedules'])}
        res.sort(key=lambda s:order[id(s)])
        c['schedules']=res
    after+=len(c['schedules'])
    if ch: changed+=1
    for b in c['metadata']['nativeClockRoomBlocks']:
        b['endMinute']=fix(b['startMinute'],b['endMinute'])
indent=2 if raw.startswith('{\n  "') else None
open(p,'w',encoding='utf-8').write(json.dumps(d,ensure_ascii=False,indent=indent)+('\n' if raw.endswith('\n') else ''))
print(dict(before=before,after=after,changed=changed,merged=merged))
