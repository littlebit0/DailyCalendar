# 광운 교시 슬롯 재생성: 수업 운영에 관한 규정 [4-3-32] 별표1 + 사용자 결정(쉬는 시간 포함).
# 0교시(08:00~09:00)는 별표1에 없고 학사안내 연강 표 + 사용자 결정 근거.
import json,re,collections,sys
F='assets/timetable/kwangwoon-unknown-2026-2.json'
d=json.load(open(F,encoding='utf-8'))
SLOT={0:(480,540),1:(540,630),2:(630,720),3:(720,810),4:(810,900),5:(900,990),6:(990,1080),
      7:(1080,1130),8:(1130,1180),9:(1180,1230),10:(1230,1280),11:(1280,1340)}
WD={'월':1,'화':2,'수':3,'목':4,'금':5,'토':6,'일':7}
before=after=merged=changed=0
for c in d['courses']:
    if c['scheduleStatus']!='scheduled': continue
    before+=len(c['schedules'])
    dates=collections.defaultdict(set)
    for s in c['schedules']: dates[s['weekday']].add(s['date'])
    out=[]
    for sg in c['sourceSchedule'].split(';'):
        m=re.match(r'\s*(\S) ([\d,]+) \[([^\]]*)\]\s*$',sg); assert m,(c['sourceId'],sg)
        ps=[int(x) for x in m.group(2).split(',')]; assert all(p in SLOT for p in ps),(c['sourceId'],sg)
        wd=WD[m.group(1)]; assert wd in dates
        for dt in dates[wd]:
            for p in ps: out.append((dt,wd,m.group(3))+SLOT[p])
    out.sort(key=lambda x:(x[0],x[2],x[3]))
    res=[]
    for dt,wd,room,s,e in out:
        if res and res[-1]['date']==dt and res[-1]['classroom']==room and s-res[-1]['endMinute']<60:
            res[-1]['endMinute']=max(res[-1]['endMinute'],e); continue
        res.append({'weekday':wd,'startMinute':s,'endMinute':e,'classroom':room,'date':dt})
    res.sort(key=lambda x:(x['date'],x['startMinute'],x['classroom']))
    after+=len(res); merged+=len(res)<len(c['schedules']); changed+=res!=c['schedules']; c['schedules']=res
print(dict(before=before,after=after,mergedCourses=merged,changedCourses=changed))
if len(sys.argv)>1: open(F,'w',encoding='utf-8').write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
