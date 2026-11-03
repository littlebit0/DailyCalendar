import json,sys,collections
# 제주대 수강편람 교시표: 50분제 매시 정각 시작(쉬는 10분), 75분제 90분 간격(쉬는 15분), 야간 45분+5분.
def slot_end(s,e):
    ln=e-s
    if ln==50 and s%60==0 and 540<=s<=1020: return s+60
    if ln==75 and s in (540,630,720,810,900,990): return s+90
    if ln==45 and s in (1110,1160,1210,1260,1310): return s+50
    raise SystemExit(f'unknown slot {s},{e}')
st=collections.Counter(); out={}
for n in ['ara','sara','unknown']:
    p=f'assets/timetable/jeju-{n}-2026-2.json'
    raw=open(p,encoding='utf-8').read()
    d=json.loads(raw)
    assert json.dumps(d,ensure_ascii=False,indent=2)+'\n'==raw
    for c in d['courses']:
        sch=c['schedules']; st['before']+=len(sch)
        if not sch: continue
        groups={}; order=[]
        for s in sch:
            k=(s['date'],s['weekday'],s['classroom'])
            if k not in groups: groups[k]=[]; order.append(k)
            groups[k].append((s['startMinute'],slot_end(s['startMinute'],s['endMinute'])))
        new=[]
        for k in order:
            ivs=sorted(set(groups[k])); cur=list(ivs[0])
            for a,b in ivs[1:]:
                if a-cur[1]<60: cur[1]=max(cur[1],b)
                else: new.append((k,tuple(cur))); cur=[a,b]
            new.append((k,tuple(cur)))
        c['schedules']=[{'weekday':k[1],'startMinute':a,'endMinute':b,'classroom':k[2],'date':k[0]} for k,(a,b) in new]
        st['after']+=len(new); st['changed']+=1
        if len(new)<len(sch) and len({(s['date']) for s in sch})*0+1 and len(new)<len(sch): st['merged']+=1
    open(p,'w',encoding='utf-8').write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print(dict(st))
