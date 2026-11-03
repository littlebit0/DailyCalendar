# 군산대 교시 슬롯에 뒤따르는 쉬는 시간 10분을 포함: 모든 구간 endMinute += 10.
# 원본은 연속 교시가 이미 한 구간(간격 10분 합침)이고, 간격 70분 이상 구간은 +10 뒤에도 60분 이상이라 합치지 않음.
import json,sys,collections
for f in ['kunsan-unknown','kunsan-saemangeum']:
    p=f'assets/timetable/{f}-2026-2.json'
    raw=open(p,encoding='utf-8').read()
    d=json.loads(raw)
    n=ch=0; segs=0
    for c in d['courses']:
        if c['schedules']: ch+=1
        for s in c['schedules']:
            assert s['startMinute']%60==10 and (s['endMinute']-s['startMinute'])%60==50
            s['endMinute']+=10; segs+=1
        by=collections.defaultdict(list)
        for s in c['schedules']: by[s['date']].append(s)
        for v in by.values():
            v.sort(key=lambda s:s['startMinute'])
            for a,b in zip(v,v[1:]):
                assert b['startMinute']-a['endMinute']>=60 or a['classroom']!=b['classroom'] or True
                if a['classroom']==b['classroom']: assert b['startMinute']-a['endMinute']>=60,(c['sourceId'])
    out=json.dumps(d,ensure_ascii=False,indent=2)+('\n' if raw.endswith('\n') else '')
    open(p,'w',encoding='utf-8').write(out)
    print(f,segs,ch)
