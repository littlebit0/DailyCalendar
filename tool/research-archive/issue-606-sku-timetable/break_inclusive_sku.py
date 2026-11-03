import json,sys
# 학사내규 제6조: 1~9교시 50분+휴식10분(슬롯60), 21~26교시 75분+휴식15분(슬롯90). 연속 교시는 같은 날·강의실이면 합친다.
SLOT={50:60,75:90}
stats={'before':0,'after':0,'changed':0,'merged':0}
for f in ['sku-main','sku-unknown']:
    p=f'assets/timetable/{f}-2026-2.json'
    raw=open(p,encoding='utf-8').read()
    d=json.loads(raw)
    for c in d['courses']:
        s=c['schedules']; stats['before']+=len(s)
        if not s: continue
        new=[]
        for m in s:
            dur=m['endMinute']-m['startMinute']
            m=dict(m); m['endMinute']=m['startMinute']+SLOT[dur]; new.append(m)
        new.sort(key=lambda m:(m['date'],m['startMinute']))
        out=[]
        for m in new:
            l=out[-1] if out else None
            if l and l['date']==m['date'] and l['classroom']==m['classroom'] and l['weekday']==m['weekday'] and m['startMinute']-l['endMinute']<60:
                l['endMinute']=max(l['endMinute'],m['endMinute'])
            else: out.append(m)
        orig=[(m['date'],m['startMinute']) for m in s]
        # 원래 순서 유지(원문 순서: 날짜 우선 정렬 여부 확인용)
        c['schedules']=out; stats['after']+=len(out); stats['changed']+=1
        if len(out)<len(s): stats['merged']+=1
    open(p,'w',encoding='utf-8').write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print(stats)
