import json,sys
tot_b=tot_a=changed=merged=0
for f in ['catholic-songsim','catholic-unknown']:
    p=f'assets/timetable/{f}-2026-2.json'
    raw=open(p,encoding='utf-8').read()
    d=json.loads(raw)
    for c in d['courses']:
        s=c['schedules']
        if not s: continue
        tot_b+=len(s); changed+=1
        for m in s:
            assert m['endMinute']%60==50 and m['startMinute']%60==0,(c['sourceId'],m)
            m['endMinute']+=10
        out=[]
        for m in sorted(s,key=lambda m:(m['date'],m['startMinute'])):
            if out and out[-1]['date']==m['date'] and out[-1]['classroom']==m['classroom'] and m['startMinute']-out[-1]['endMinute']<60:
                out[-1]['endMinute']=max(out[-1]['endMinute'],m['endMinute'])
            else: out.append(m)
        if len(out)<len(s): merged+=1
        # keep original order if it was already sorted
        c['schedules']=out; tot_a+=len(out)
    indent=2 if raw.startswith('{\n  "') else None
    json.dump(d,open(p,'w',encoding='utf-8'),ensure_ascii=False,indent=indent)
    open(p,'a').write('\n' if raw.endswith('\n') else '')
print(tot_b,tot_a,changed,merged)
