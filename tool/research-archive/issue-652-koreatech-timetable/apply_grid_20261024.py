# 한기대 교시표(1교시 09:00, 교시당 60분, A/B 각 30분)로 확정 가능한 강좌만 scheduled로 바꾼다.
import json, re, collections, datetime
P='/Users/kimhwi/Documents/Codex/DailyCalendar/work/wt/u-koreatech-tt/assets/timetable/koreatech-unknown-2026-2.json'
d=json.load(open(P,encoding='utf8'))
WD={'월':1,'화':2,'수':3,'목':4,'금':5,'토':6,'일':7}
tok=re.compile(r'^([월화수목금토일])?(\d{1,2})([AB])(?:~(\d{1,2})([AB]))?$')
SKIP={datetime.date.fromisoformat(x) for x in ['2026-09-24','2026-09-25','2026-10-05','2026-10-09','2026-11-02']}
dates=collections.defaultdict(list); x=datetime.date(2026,8,31)
while x<=datetime.date(2026,12,6):
    if x not in SKIP: dates[x.isoweekday()].append(x)
    x+=datetime.timedelta(days=1)
def blocks(s):
    out=[];day=None
    for p in s.split(','):
        m=tok.match(p.strip())
        if not m: return None
        day=m.group(1) or day
        a=(int(m.group(2))-1)*2+(m.group(3)=='B')
        b=a if not m.group(4) else (int(m.group(4))-1)*2+(m.group(5)=='B')
        if day is None or b<a or b>25: return None   # 13B(=22:00)까지만 공식 표에 있음
        out.append([WD[day],540+a*30,540+(b+1)*30])
    out.sort(); m=[]
    for w,s0,e in out:
        if m and m[-1][0]==w and m[-1][2]>=s0: m[-1][2]=max(m[-1][2],e)
        else: m.append([w,s0,e])
    return m
NOTE=' 교시 시각: 1교시 09:00 시작·교시당 60분(A·B 각 30분)을 학사운영에 관한 규칙 제53조(50분+휴식 10분)와 메카트로닉스공학부·산업경영학부 공식 시간표의 1A~13B=09:00~22:00 표기에 맞춰 적용했고, 강의실은 공개되지 않아 비워 두었습니다.'
HELD='현재 메카트로닉스 개별 강의실·시각 대응 미확인'
n=collections.Counter()
for c in d['courses']:
    if c['scheduleStatus']!='unrecognized' or c['metadata']['heldReason']!=HELD: continue
    b=blocks(c['sourceSchedule'] or '')
    if b is None: n['hold-unparsable']+=1; continue
    o=c['metadata']['originalEducationalFields']
    hours=(o.get('lectureHours') or 0)+(o.get('practiceHours') or 0)
    if sum(e-s for _,s,e in b)/60!=hours: n['hold-hours']+=1; print('hours',c['courseCode'],c['section'],c['sourceSchedule'],hours); continue
    ms=[dict(date=dt.isoformat(),weekday=w,startMinute=s,endMinute=e,classroom='') for w,s,e in b for dt in dates[w]]
    ms.sort(key=lambda m:(m['date'],m['startMinute']))
    c['scheduleStatus']='scheduled'; c['schedules']=ms
    c['remarks']=c['remarks'].replace(' 예약 보류: '+HELD,'')+NOTE
    c['metadata']['heldReason']=''; c['metadata']['clockScope']='Current2026-2undergraduate-grid-1A-13B-0900-2200'
    n['confirmed']+=1
print(n)
open(P,'w',encoding='utf8').write(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print(collections.Counter(c['scheduleStatus'] for c in d['courses']))
