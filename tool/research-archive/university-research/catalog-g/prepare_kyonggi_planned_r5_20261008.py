"""Extend only actual native daytime9 periods using current official school table."""
import json,pathlib,hashlib,re,datetime as dt,copy
R=pathlib.Path(__file__).resolve().parent
base=json.loads((R/'kyonggi-suwon-2026-2.planned-audited-20261008-r4.json').read_text())
draft={c['actualRegistrationNumber']:c for c in json.loads((R/'kyonggi-source-clock-candidate-draft-20261008.json').read_text())['rows']}
clocks={str(n):(480+n*60,530+n*60) for n in range(1,10)}
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09','2026-11-08'}
new=[];held=[]
for c in base['courses']:
 if c['metadata']['decision']!='periodClockNotPublished':continue
 n=c['metadata']['actualRegistrationNumber'];rows=draft[n]['nativeTimeRows'];weekly=[]
 if any(t['period']=='블렌디드' for t in rows):held.append(n);continue
 for t in rows:
  assert t['weekday'] in '월화수목금토일' and len(t['weekday'])==1
  tokens=re.sub('^주','',t['period']).split();assert tokens and all(token in clocks for token in tokens)
  assert '9' in tokens
  groups=[]
  for token in tokens:
   start,end=clocks[token]
   if groups and int(token)==groups[-1][2]+1:groups[-1][1]=end;groups[-1][2]=int(token)
   else:groups.append([start,end,int(token)])
  for start,end,_ in groups:weekly.append({'weekday':'월화수목금토일'.index(t['weekday'])+1,'startMinute':start,'endMinute':end,'classroom':t['classroom']})
 meetings=[]
 for slot in weekly:
  date=dt.date(2026,9,1)
  while date<=dt.date(2026,12,14):
   if date.isoweekday()==slot['weekday'] and date.isoformat() not in closed:meetings.append(dict(slot,date=date.isoformat()))
   date+=dt.timedelta(days=1)
 assert meetings;c['schedules']=meetings;c['scheduleStatus']='scheduled'
 c['metadata']['decision']='postedRegularClockIncludingOfficialDaytime9'
 c['metadata']['currentOfficialClockEvidence']={'sourceUrl':'https://www.kyonggi.ac.kr/www/contents.do?key=8430','pageLastModified':'2023-03-29','readDate':'2026-10-08','scope':'수원캠퍼스(주간)60분제','actualPeriod9':{'startMinute':1020,'endMinute':1070},'actualNativeRowsPreserved':True,'parsedCurrentPostedWeeklyMeetings':weekly}
 c['remarks']=c['remarks'].replace('공개 교시 시각표 범위 밖의 교시 포함. 실제 시각 확인 전 반복 미생성.','현재 학교 강의시간 안내에서 수원주간9교시17:00~17:50 확인. 원공시 주간 교시와 원강의실로 예정일 반영.')
 new.append({'registrationNumber':n,'courseCode':c['courseCode'],'weeklyMeetings':weekly,'dateCount':len(meetings)})
assert len(new)==39 and set(held)=={'1492','1493','1494'}
fn='kyonggi-suwon-2026-2.planned-audited-20261008-r5.json';p=R/fn;assert not p.exists()
b=(json.dumps(base,ensure_ascii=False,indent=2)+'\n').encode();p.write_bytes(b)
m={'researchOnly':True,'completionClaim':False,'file':fn,'sha256':hashlib.sha256(b).hexdigest(),'sourceRows':1640,'scheduledCount':sum(bool(c['schedules']) for c in base['courses']),'dateCount':sum(len(c['schedules']) for c in base['courses']),'additionalCurrentOfficialClock39':new,'remainingClockUnrecognizedBlended':held,'currentOfficialClockEvidence':'kyonggi-current-official-clock-20261008.json','all1640OriginalEducationPreserved':True,'unchangedPreviousR4Courses':1601,'actualAttendanceConfirmed':False,'wholeUniversitySupportComplete':False,'intensiveWholeEndDateUnconfirmed':True,'sourceScope':'Suwon daytime public timetable only'}
(R/'kyonggi-planned-audited-20261008-r5-sha-manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n');print(m['sha256'],m['scheduledCount'],m['dateCount'])
