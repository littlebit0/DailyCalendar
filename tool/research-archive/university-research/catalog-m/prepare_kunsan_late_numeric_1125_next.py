"""One source late block: only explicit numeric9/10, numeric11 held without extrapolation."""
import copy,datetime as dt,hashlib,json
from pathlib import Path
P=Path(__file__).parent
prev=json.loads((P/'kunsan-published-regular-1124-mixed-physical-partial-v3-next-audit-20261008.json').read_text());a=copy.deepcopy(prev);a['datasets']=[];a['promoted']=[];count=0
for entry in prev['datasets']:
 d=json.loads((P/entry['file']).read_text())
 for c in d['courses']:
  if c['courseCode']!='116289' or c['section']!='01':continue
  assert c['sourceSchedule']=='금9 10 11 [예술관-5403]' and c['sourceTeachingMethods']==['대면'] and c['scheduleStatus']=='unrecognized'
  meetings=[];day=dt.date(2026,8,31)
  while day<=dt.date(2026,12,10):
   date=day.isoformat()
   if (day.isoweekday()==5 and date<='2026-12-06' and date not in {'2026-09-25','2026-10-09','2026-10-23'}) or date in {'2026-12-08','2026-12-09'}:
    meetings.append({'weekday':day.isoweekday(),'date':date,'startMinute':1030,'endMinute':1140,'classroom':'예술관-5403','deliveryMode':'inPerson'})
   day+=dt.timedelta(days=1)
  txt='부분 시간표: 현재 학교 시각표에서 직접 확인된 금9·10교시17:10~19:00의 교실 예약만 반영했습니다. 같은 원표의 금11교시 실제 시각은 현재 학부 공통시각표에 게시되지 않아 반영하지 않았습니다.11교시를19:10등으로 추정하거나 빠진 부분을 휴강으로 확정하지 않았습니다. 학교학기는8월31일~12월17일이며 반영된 정규·지정 보강 예약 범위는12월10일까지입니다.12월10일을 이 과목의 실제 조기 종강으로 의미하지 않으며 별도 시험 참석 시각을 만들지 않았습니다.'
  c['remarks']+='\n'+txt;c['departmentRemarks']={k:v+'\n'+txt for k,v in c['departmentRemarks'].items()}
  c.update(scheduleStatus='scheduled',schedules=meetings,period={'startDate':'2026-08-31','endDate':'2026-12-17'})
  c['sourceEducation'].update(projection='publishedRegularTimetableNumericLatePartial',unresolvedSourcePeriodScope=[{'sourceWeekday':5,'sourcePeriodLiteral':'11','sourceClassroom':'예술관-5403'}],verifiedLiteralNumericBlocks=[{'weekday':5,'startMinute':1030,'endMinute':1140,'classroom':'예술관-5403'}],officialSemesterPeriod={'startDate':'2026-08-31','endDate':'2026-12-17'},generatedOrdinaryMakeupDateScopeEnd='2026-12-10',courseEarlyEndConfirmed=False)
  a['promoted'].append({'sourceId':c['sourceId'],'codeAndSection':'116289-01','sourceSchedule':c['sourceSchedule'],'verifiedLiteralNumericBlocks':c['sourceEducation']['verifiedLiteralNumericBlocks'],'unresolvedSourcePeriodScope':c['sourceEducation']['unresolvedSourcePeriodScope'],'datedMeetingCount':len(meetings)})
 d['productionProjectionPermitted']='validated1125PublishedReservationsOnly';d['counts']={k:sum(c['scheduleStatus']==k for c in d['courses'])for k in ['scheduled','unrecognized','unscheduled']}
 name=entry['file'].replace('1124-mixed-physical-partial-v3-next','1125-late-numeric-partial-next');f=P/name;assert not f.exists();f.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');a['datasets'].append({**entry,'file':name,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()});count+=sum(len(c['schedules'])for c in d['courses'])
assert len(a['promoted'])==1
a.update(previousAudit='kunsan-published-regular-1124-mixed-physical-partial-v3-next-audit-20261008.json',publishedReservations=1125,held=495,datedMeetingCount=count,includesLateNumericPartial1=True,sourceChangesOnly='116289-01known9/10partialonly;other1717courseobjectsunchanged',limits='Literalnumeric9/10only;source11remainsunresolved. Existingnumeric/mixedpartialandfinalactivewarnings retained.')
f=P/'kunsan-published-regular-1125-late-numeric-partial-next-audit-20261008.json';assert not f.exists();f.write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print(a['datasets'],count)
