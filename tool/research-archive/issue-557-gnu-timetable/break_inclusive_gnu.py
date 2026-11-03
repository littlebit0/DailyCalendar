import json,glob,sys,collections
# 일반 교시표: n교시 시작 = 480+60n, 끝 = 시작+50. 새 슬롯 = 다음 교시 시작까지(60분).
def conv(s,e):
    if (s-480)%60==0 and (e-530)%60==0 and 480<=s<=1140 and e>s: return s,e+10
    if s==1140 and e==1285: return s,1290   # 산업경영학과 금11~13교시: 45분+5분
    return s,e   # 산업경영 토요일 공지 시계 구간 등 원문 시계 구간은 유지
st=collections.Counter(); changed=set(); merged=set(); rep={}
for f in sorted(glob.glob('assets/timetable/gnu-*-2026-2.json')):
    d=json.load(open(f,encoding='utf-8'))
    for c in d['courses']:
        sc=c.get('schedules')
        if not sc: continue
        st['before']+=len(sc)
        new=[]
        for m in sc:
            m=dict(m); s,e=conv(m['startMinute'],m['endMinute'])
            if (s,e)!=(m['startMinute'],m['endMinute']): changed.add(c['sourceId'])
            m['startMinute'],m['endMinute']=s,e; new.append(m)
        out=[]
        by=collections.OrderedDict()
        for m in new: by.setdefault(m['date'],[]).append(m)
        for dt,l in by.items():
            l.sort(key=lambda m:m['startMinute'])
            cur=[]
            for m in l:
                p=cur[-1] if cur else None
                if p and p['classroom']==m['classroom'] and p.get('deliveryMode')==m.get('deliveryMode') and p['weekday']==m['weekday'] and m['startMinute']-p['endMinute']<60:
                    p['endMinute']=max(p['endMinute'],m['endMinute']); merged.add(c['sourceId']); st['mergedSeg']+=1
                else: cur.append(m)
            out+=cur
        c['schedules']=out; st['after']+=len(out)
    if '--write' in sys.argv:
        open(f,'w',encoding='utf-8').write(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
print(dict(st),'changedCourses',len(changed),'mergedCourses',len(merged))
