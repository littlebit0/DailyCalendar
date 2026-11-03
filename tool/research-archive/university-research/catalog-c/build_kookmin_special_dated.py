"""Explicit official week anchors plus actual teaching weekday; research candidate only."""
import json,datetime
from pathlib import Path
P=Path(__file__).resolve().parent
rows=json.loads((P/'kookmin-current-college-scope.json').read_text())['records']
anchor8=datetime.date(2026,10,20);anchor15=datetime.date(2026,12,8)
assert (anchor15-anchor8).days==7*7
first=anchor8-datetime.timedelta(weeks=7)
assert first==datetime.date(2026,9,1)
results=[]
for code,sec,day,omit,asyncweeks,unresolved in [('0368203','01','THURSDAY',[4,8,15],[],[]),('1131900','01','WEDNESDAY',[8,15],[],[]),('0716902','02','FRIDAY',[],[4,6],[]),('0716902','03','FRIDAY',[],[],[4,6])]:
 r=next(r for r in rows if r['subjectId']==code and r['classSequence']==sec)
 assert r['closed'] is False
 slots=r['schedule']['lectureTimes'];assert slots and all(z['dayOfWeek']==day for z in slots)
 merged=[]
 for z in slots:
  start=z['start']['hour']*60+z['start']['minute'];end=z['end']['hour']*60+z['end']['minute'];room=z.get('classRoomName') or ''
  if merged and merged[-1]['endMinute']==start and merged[-1]['room']==room:merged[-1]['endMinute']=end
  else:merged.append({'startMinute':start,'endMinute':end,'room':room})
 meetings=[]
 for week in range(1,16):
  if week in omit or week in asyncweeks or week in unresolved:continue
  d=first+datetime.timedelta(weeks=week-1,days={'THURSDAY':2,'WEDNESDAY':1,'FRIDAY':3}[day])
  assert d.isoweekday()=={'THURSDAY':4,'WEDNESDAY':3,'FRIDAY':5}[day]
  for z in merged:
   live=code=='0716902' and week==14
   meetings.append({'date':d.isoformat(),'weekday':d.isoweekday(),'startMinute':z['startMinute'],'endMinute':z['endMinute'],'room':'' if live else z['room'],'catalogRoom':z['room'],'deliveryMode':'liveOnline' if live else 'onsite','officialWeek':week})
 results.append({'courseKey':r['id'],'subjectId':code,'section':sec,'title':r['subjectNm'],'meetingDateMethod':'official explicit week8+week15 calendar anchors; actual weekday from current catalog, subtraction in 7-day teaching weeks corroborates published Sep1 semester start','anchorEvidence':{'source':'https://www.kookmin.ac.kr/user/scGuid/scSchedule/index.do','week8':['2026-10-20','2026-10-26'],'week15':['2026-12-08','2026-12-14'],'semesterStart':'2026-09-01'},'planEvidence':'kookmin-special-public-plans-education.json','noClassWeeks':omit,'noTimedMeetingWeeks':asyncweeks,'unresolvedWeeks':unresolved,'allAttendanceWeeksVerified':not unresolved,'unresolvedReason':'03분반4/6주차 공휴일의 대면/보강/사전녹화 방식 미게시' if unresolved else None,'semesterWeeksConsidered':15,'weeklyRecurrenceAllowed':False,'dateMeetings':meetings,'distinctDates':sorted(set(z['date'] for z in meetings)),'completionClaim':False})
for x in results:
 if x['subjectId']=='0716902':
  x['week14DeliveryEvidence']='화상 줌 실시간' if x['section']=='02' else '화상 ZOOM 강의'
  if x['section']=='02':x['noTimedMeetingEvidence']=[{'week':4,'text':'사전녹화 강의 (추석)'},{'week':6,'text':'사전녹화 강의 (한글날)'}]
published=json.loads((P/'kookmin-current-weekly-operating-rows.json').read_text())
for x in results:
 plan=next(r for r in published if r['subjectId']==x['subjectId'] and r['section']==x['section'])
 byweek={r['week']:r['dates'][0] for r in plan['weeklyRows'] if len(r['dates'])==1}
 assert plan['current2026-2Header'] and len(byweek)==15
 for meeting in x['dateMeetings']:
  assert byweek[meeting['officialWeek']]==meeting['date']
 x['meetingDateMethod']='actual printed current public plan week-row dates; independently crosschecked against official calendar anchors and actual catalog weekday'
 x['directPrintedDateEvidence']='kookmin-current-weekly-operating-rows.json'
 x['allCandidateDatesMatchDirectPrintedDates']=True
assert [len(x['distinctDates']) for x in results]==[12,13,13,13]
assert results[0]['distinctDates'][-1]=='2026-12-03' and results[1]['distinctDates'][-1]=='2026-12-02'
(P/'kookmin-special-dated-meeting-candidates.json').write_text(json.dumps(results,ensure_ascii=False,indent=2));print([(r['subjectId'],len(r['distinctDates']),r['distinctDates'][-1]) for r in results])
