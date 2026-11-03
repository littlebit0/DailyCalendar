# 남서울대 시간표: 교시 슬롯(수업+쉬는 시간)으로 끝 시각을 늘리고 연속 구간을 합친다.
# 1~9교시 09:00~ 60분 슬롯(50+10), 10~14교시 18:00~ 50분 슬롯(45+5). 현재 자료는 1~9교시만 있다.
import json,sys,collections
p=sys.argv[1]
d=json.load(open(p))
starts=[540+60*i for i in range(9)]+[1080+50*i for i in range(5)]
slot={s:(60 if s<1080 else 50) for s in starts}
before=after=changed=merged=0
for c in d['courses']:
    s=c['schedules']; before+=len(s)
    if not s: continue
    out=[]
    for x in sorted(s,key=lambda x:(x['date'],x['classroom'],x['startMinute'])):
        assert x['startMinute'] in slot, x
        x=dict(x); x['endMinute']=x['startMinute']+slot[x['startMinute']]
        l=out[-1] if out else None
        if l and l['date']==x['date'] and l['classroom']==x['classroom'] and l.get('sourceProfessor')==x.get('sourceProfessor') and x['startMinute']-l['endMinute']<60:
            l['endMinute']=max(l['endMinute'],x['endMinute'])
        else: out.append(x)
    # 원래 순서(날짜, 시작) 유지
    out.sort(key=lambda x:(x['date'],x['startMinute'],x['classroom']))
    if len(out)<len(s): merged+=1
    changed+=1
    c['schedules']=out; after+=len(out)
json.dump(d,open(p,'w'),ensure_ascii=False,indent=2); open(p,'a').write('\n')
print(json.dumps(dict(before=before,after=after,changedCourses=changed,mergedCourses=merged)))
