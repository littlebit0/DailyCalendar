"""Current mixed source physical reservation only; actual generic remote delivery remains held."""
import collections,copy,datetime as dt,hashlib,json,re
from pathlib import Path
from prepare_kunsan_review import parse_numeric_clock
P=Path(__file__).parent
oldAudit=json.loads((P/'kunsan-published-regular-1111-numeric-partial-v2-next-audit-20261008.json').read_text());audit=copy.deepcopy(oldAudit);audit['datasets']=[];audit['promoted']=[]
blocked={(r['courseCode'],r['section']):r['reasons'] for r in json.loads((P/'kunsan-current-whole-operating-date-checkpoint-next-20261008.json').read_text())['individualBlocked']}
HOLIDAYS={'2026-09-24','2026-09-25','2026-10-05','2026-10-09'};MAKEUP={'2026-12-07':1,'2026-12-08':5,'2026-12-09':5,'2026-12-10':4};total=0
for entry in oldAudit['datasets']:
 old=json.loads((P/entry['file']).read_text());d=copy.deepcopy(old)
 for c in d['courses']:
  if c['courseCode']=='111250' and c['section']=='01':
   c['departmentRemarks']={k:v.replace('의 원문자 교시 실제 시각은 미확인','의 원문자 및11교시이후 실제 시각은 미확인') for k,v in c['departmentRemarks'].items()};c['remarks']=c['remarks'].replace('의 원문자 교시 실제 시각은 미확인','의 원문자 및11교시이후 실제 시각은 미확인')
  if c['scheduleStatus']!='unrecognized' or c['sourceTeachingMethods']!=['혼합'] or blocked.get((c['courseCode'],c['section']))!=['원격·혼합 운영의 실제 동시 출석 방식 미확인']:continue
  blocks=[];held=[];cursor=0
  for m in re.finditer(r'([^\[\]]+)\[([^\[\]]+)\]',c['sourceSchedule']):
   assert not c['sourceSchedule'][cursor:m.start()].strip();cursor=m.end()
   if m[2]=='원격강의':held.append({'sourceScheduleLiteral':m[1].strip().strip(',')+' ['+m[2]+']'});continue
   assert m[2]!='실시간강의'
   for b in parse_numeric_clock(m[1].strip().strip(',')+' ['+m[2]+']'):blocks.append({'weekday':b['weekday'],'startMinute':b['originalStartMinute'],'endMinute':b['endMinute'],'classroom':b['classroom']})
  assert not c['sourceSchedule'][cursor:].strip()
  if not blocks:continue
  assert held and c['campus']=='unknown';meetings=[];day=dt.date(2026,8,31)
  while day<=dt.date(2026,12,10):
   date=day.isoformat()
   if date not in HOLIDAYS and not '2026-10-19'<=date<='2026-10-23' and (date in MAKEUP or date<='2026-12-06'):
    src=MAKEUP.get(date,day.isoweekday())
    for b in blocks:
     if b['weekday']==src:meetings.append({**b,'weekday':day.isoweekday(),'date':date,'deliveryMode':'inPerson'})
   day+=dt.timedelta(days=1)
  assert meetings
  txt='부분 시간표: 학교 원표의 혼합수업 중 물리 강의실과 정수1~10교시가 직접 명시된 교실 예약만 반영했습니다. '+', '.join(h['sourceScheduleLiteral'] for h in held)+'의 원격 부분은 실시간/동영상·실제 출석 방식이 미확인이라 일정화하지 않았습니다. 미반영 원격 부분을 휴강으로 확정하거나 원교시 전체를 강제 실시간 또는 동영상 수업으로 바꾸지 않았습니다. 이 과목 전체 수업이 모두 반영된 것은 아니며 실제 원격 운영은 학교의 수업계획서를 확인하세요.'
  txt+=' 학교의 이번 학기는8월31일~12월17일입니다. 반영된 정규 수업·지정 보강 예약 범위는12월10일까지이며, 중간·기말 시험 일정은 정규 교시로 별도 생성하지 않았습니다.12월10일을 이 과목의 실제 조기 종강으로 의미하지 않습니다.'
  c['departmentRemarks']={k:v+'\n'+txt for k,v in c['departmentRemarks'].items()};c['remarks']+='\n'+txt
  c.update(scheduleStatus='scheduled',schedules=meetings,period={'startDate':'2026-08-31','endDate':'2026-12-17'})
  c['sourceEducation'].update(projection='publishedRegularTimetableMixedPhysicalPartial',unresolvedSourceRemoteScope=held,verifiedLiteralPhysicalBlocks=blocks,partialWholeClassConfirmed=False,officialSemesterPeriod={'startDate':'2026-08-31','endDate':'2026-12-17'},generatedOrdinaryMakeupDateScopeEnd='2026-12-10')
  audit['promoted'].append({'sourceId':c['sourceId'],'codeAndSection':c['courseCode']+'-'+c['section'],'sourceSchedule':c['sourceSchedule'],'verifiedLiteralPhysicalBlocks':blocks,'unresolvedSourceRemoteScope':held,'datedMeetingCount':len(meetings)})
 d['productionProjectionPermitted']='validated1124PublishedReservationsIncludes311NumericAnd13MixedPhysicalPartialOnly'
 d['sourceOriginalCounts']=d['counts'];d['counts']=dict(collections.Counter(c['scheduleStatus'] for c in d['courses']));d['campusCounts']={entry['campus']:len(d['courses'])}
 name=entry['file'].replace('1111-numeric-partial-v2-next','1124-mixed-physical-partial-v3-next');f=P/name;assert not f.exists();f.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');audit['datasets'].append({**entry,'file':name,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()});total+=sum(len(c['schedules'])for c in d['courses'])
assert len(audit['promoted'])==13
audit.pop('datedMeetingsAndAllNativeEducationUnchanged',None);audit.pop('sourceOther1407CoursesUnchanged',None)
audit.update(previousAudit='kunsan-published-regular-1111-numeric-partial-v2-next-audit-20261008.json',publishedReservations=1124,includesPartial311=True,includesMixedPhysicalPartial13=True,held=496,datedMeetingCount=total,sourceChangesOnly='13newpartialmeetingsets;111250-01noteclarifiesheldnumeric11withoutdateschange;remaining1704courseobjectsunchanged',limits='Only literal physical reservation of source mixed course;generic 원격강의 held without force live/VOD. Fullnative census/cancellation warning retained. No whole-class attendance claim.')
f=P/'kunsan-published-regular-1124-mixed-physical-partial-v3-next-audit-20261008.json';assert not f.exists();f.write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in audit.items()if k!='promoted'})
