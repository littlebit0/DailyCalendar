"""Only literal ordinary numeric source slots; preserve unresolved circled glyphs without conversion."""
import copy,datetime as dt,hashlib,json,re
from pathlib import Path
from prepare_kunsan_review import parse_numeric_clock
P=Path(__file__).parent
DAYS='월화수목금토일'
HOLIDAYS={'2026-09-24','2026-09-25','2026-10-05','2026-10-09'}
MAKEUP={'2026-12-07':1,'2026-12-08':5,'2026-12-09':5,'2026-12-10':4}
def numeric_partial(raw):
 blocks=[];held=[];cursor=0
 for match in re.finditer(r'([^\[\]]+)\[([^\[\]]+)\]',raw):
  assert not raw[cursor:match.start()].strip()
  for part in match[1].strip().strip(',').split(','):
   m=re.fullmatch(r'([월화수목금토일])\s*([\d①-⑳\s]+)',part.strip());assert m
   tokens=m[2].split();nums=[]
   for t in tokens:
    if t.isascii() and t.isdigit() and 1<=int(t)<=10:nums.append(t)
    else:held.append({'sourceWeekday':DAYS.index(m[1])+1,'sourcePeriodLiteral':t,'sourceClassroom':match[2]})
   if nums:
    assert DAYS.index(m[1])+1<6
    for b in parse_numeric_clock(m[1]+' '+' '.join(nums)+' ['+match[2]+']'):
     blocks.append({'weekday':b['weekday'],'startMinute':b['originalStartMinute'],'endMinute':b['endMinute'],'classroom':b['classroom']})
  cursor=match.end()
 assert not raw[cursor:].strip();return blocks,held
old=json.loads((P/'kunsan-unknown-2026-2.published-regular-800-v3-next-20261008.json').read_text());new=copy.deepcopy(old)
blocked={(r['courseCode'],r['section']):r['reasons'] for r in old['individualBlocked']};promoted=[]
for c in new['courses']:
 if blocked.get((c['courseCode'],c['section']))!=['원문 원문자 교시(① 등)의 실제 시각 미확인']:continue
 blocks,held=numeric_partial(c['sourceSchedule'])
 if not blocks:continue
 assert c['sourceTeachingMethods']==['대면'] and c['campus'] in ['unknown','saemangeum']
 meetings=[];day=dt.date(2026,8,31)
 while day<=dt.date(2026,12,10):
  date=day.isoformat()
  if date not in HOLIDAYS and not '2026-10-19'<=date<='2026-10-23' and (date in MAKEUP or date<='2026-12-06'):
   src=MAKEUP.get(date,day.isoweekday())
   for b in blocks:
    if b['weekday']==src:meetings.append({**b,'weekday':day.isoweekday(),'date':date,'deliveryMode':'inPerson'})
  day+=dt.timedelta(days=1)
 assert meetings
 txt='부분 시간표: 원문에 직접 쓰인 정수1~10교시의 정규 공시 예약만 반영했습니다. '+', '.join(f'{DAYS[h["sourceWeekday"]-1]}{h["sourcePeriodLiteral"]} [{h["sourceClassroom"]}]' for h in held)+'의 원문자 교시 실제 시각은 미확인으로 반영하지 않았습니다. 원문자를 정수교시로 바꾸거나 누락 수업을 휴강으로 확정하지 않았습니다. 이 과목 전체 수업이 모두 반영된 것은 아니므로 해당 부분은 학교의 실제 시간표를 확인하세요.'
 c['departmentRemarks']={k:v+'\n'+txt for k,v in c['departmentRemarks'].items()};c['remarks']+='\n'+txt
 c.update(scheduleStatus='scheduled',schedules=meetings,period={'startDate':'2026-08-31','endDate':'2026-12-10'})
 c['sourceEducation'].update(projection='publishedRegularTimetablePartial',unresolvedSourcePeriodScope=held,verifiedLiteralNumericBlocks=blocks,partialWholeClassConfirmed=False)
 promoted.append({'sourceId':c['sourceId'],'codeAndSection':c['courseCode']+'-'+c['section'],'sourceSchedule':c['sourceSchedule'],'verifiedLiteralNumericBlocks':blocks,'unresolvedSourcePeriodScope':held,'datedMeetingCount':len(meetings)})
assert len(promoted)==311
new['productionProjectionPermitted']='validated1111PublishedReservationsIncludes311PartialOnly'
datasets=[]
for campus in ['unknown','saemangeum']:
 d=copy.deepcopy(new);d['campus']=campus;d['campusName']='위치 미확인' if campus=='unknown' else '새만금캠퍼스';d['courses']=[c for c in new['courses'] if c['campus']==campus]
 f=P/f'kunsan-{campus}-2026-2.published-regular-1111-numeric-partial-next-20261008.json';assert not f.exists();f.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');datasets.append({'file':f.name,'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'courseCount':len(d['courses']),'campus':campus})
audit={'datasets':datasets,'whole':1718,'publishedReservations':1111,'includesPartial311':True,'held':509,'explicitUntimed':98,'datedMeetingCount':sum(len(c['schedules']) for c in new['courses']),'previousAudit':'kunsan-published-regular-800-v3-next-audit-20261008.json','promoted':promoted,'finalActiveScopeVerified':False,'productionRegistered':False,'completionClaim':False,'sourceOther1407CoursesUnchanged':True,'limits':'No circled-clock mapping. Only literal numeric ordinary slots retained; original unresolved weekday/glyph/room visible in class notes. Original800 frozen;311 partial reservations not whole-class approval.'}
for a,b in zip(old['courses'],new['courses']):
 if a['sourceId'] not in {r['sourceId'] for r in promoted}:assert a==b
f=P/'kunsan-published-regular-1111-numeric-partial-next-audit-20261008.json';assert not f.exists();f.write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in audit.items() if k!='promoted'})
