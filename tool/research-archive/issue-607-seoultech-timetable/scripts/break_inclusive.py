#!/usr/bin/env python3
"""Seoultech: 50분 수업 구간 끝에 10분 쉬는 시간을 더해 60분 슬롯으로 저장 (날짜 있는 시계 시각은 유지)."""
import json,sys
p=sys.argv[1]
raw=open(p,encoding='utf-8').read()
d=json.loads(raw)
before=after=changed=merged=0
for c in d['courses']:
    out=[];ch=False
    for s in c['schedules']:
        before+=1
        if 'date' not in s:
            assert (s['startMinute']-480)%60==0 and (s['endMinute']-s['startMinute'])%60==50
            s['endMinute']+=10; ch=True
        out.append(s)
    m=[]
    for s in sorted(out,key=lambda s:(s.get('date') or '',s['weekday'],s['startMinute'])):
        q=m[-1] if m else None
        if q and 'date' not in s and 'date' not in q and q['weekday']==s['weekday'] and q['classroom']==s['classroom'] and q.get('deliveryMode')==s.get('deliveryMode') and s['startMinute']-q['endMinute']<60:
            q['endMinute']=max(q['endMinute'],s['endMinute']); merged+=1; ch=True
        else: m.append(s)
    if len(m)!=len(c['schedules']): c['schedules']=m
    else: c['schedules']=out
    after+=len(c['schedules']); changed+=ch
print(dict(before=before,after=after,changed=changed,mergedSegments=merged))
open(p,'w',encoding='utf-8').write(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
