# 쉬는 시간 포함 슬롯(50분->60분, 75분->90분) + 같은 날·같은 강의실 연속 구간 합치기
import json,sys,collections
SLOT={50:60,75:90}
def convert(path):
    d=json.load(open(path,encoding='utf-8'))
    before=after=changed=merged=0
    for c in d['courses']:
        sch=c.get('schedules') or []
        if not sch: continue
        before+=len(sch)
        groups=collections.OrderedDict()
        for s in sch: groups.setdefault((s['date'],s['weekday'],s['classroom']),[]).append(s)
        out=[]; m=False
        for (dt,wd,room),g in groups.items():
            g.sort(key=lambda s:s['startMinute'])
            cur=None
            for s in g:
                unit=s.get('sourceMinuteUnit')
                end=s['startMinute']+SLOT[unit] if unit in SLOT else s['endMinute']
                if cur and s['startMinute']-cur['endMinute']<60:
                    cur['endMinute']=max(cur['endMinute'],end); m=True
                else:
                    cur=dict(s); cur['endMinute']=end; out.append(cur)
        out.sort(key=lambda s:(s['date'],s['startMinute']))
        c['schedules']=out; after+=len(out); changed+=1; merged+=m
    open(path,'w',encoding='utf-8').write(json.dumps(d,indent=2,ensure_ascii=False)+"\n")
    return dict(before=before,after=after,changedCourses=changed,mergedCourses=merged)
for p in sys.argv[1:]: print(p,convert(p))
