"""Source-only Jeju v3. Exact printed blended attendance; no online appointments."""
import ast,collections,copy,json,re
from pathlib import Path
R=Path(__file__).parent
P=R.parent/'ordinary-room-program-followup-v2-20261009'
clock=json.loads((R.parent/'jeju-current-source-proof-v1.json').read_text())['clockMinutes']
# Reuse existing immutable current-clock parser/date semantics without executing builder.
tree=ast.parse((P/'build_candidate.py').read_text())
ns={'re':re,'CLOCK':clock,'dt':__import__('datetime')}
exec(compile(ast.Module(body=[x for x in tree.body if isinstance(x,ast.FunctionDef)],type_ignores=[]),'<frozen-v2-functions>','exec'),ns)
added=[];reviews=[];counts={}
for campus in ['ara','sara','unknown']:
 old=json.loads((P/f'jeju-{campus}-2026-2.reservation-planned-v2.json').read_text());data=copy.deepcopy(old)
 for c in data['courses']:
  if c['schedules']:continue
  n=c['metadata']['originalEducationalFields'];raw=n['rawTimeAndRoom'];reason=c['metadata']['heldReason'];spans=[];why='unchanged-source-gap';kind=''
  if reason=='blended-attendance-period-review':
   assert raw.startswith('블렌디드강좌')
   spans,why,grammar=ns['parse'](raw.removeprefix('블렌디드강좌').strip());kind='printed-blended-weekly-attendance'
   # Unknown S/time/empty/multiple-room grammar remains whole-held in this revision.
  elif reason=='원본 강의실·교시 대응 미확인' and re.fullmatch(r'\[\]\s*(?:[월화수목금]\d+[AB]?\s*)+',raw):
   kind='ordinary-published-empty-classroom';why=''
   for day,period in re.findall(r'([월화수목금])(\d+[AB]?)',raw):
    if period not in clock:why='unpublished-clock';break
    start,end=clock[period];spans.append(dict(weekday='월화수목금'.index(day)+1,startMinute=start,endMinute=end,classroom=''))
  if not kind:continue
  review=dict(sourceId=c['sourceId'],kind=kind,originalEducationalFields=n,previousHeldReason=reason,reviewReason=why,spans=spans if not why else [])
  reviews.append(review)
  if why:continue
  c['schedules']=ns['dates'](spans);c['scheduleStatus']='scheduled'
  c['sourceClassroom']=' / '.join(dict.fromkeys(s['classroom'] for s in spans))
  c['metadata'].update(v3PreviousHeldReason=reason,heldReason='',v3SourceScope=kind,sourcePeriodSpans=spans,previousV2ResearchRemarks=c['remarks'])
  c['remarks']=c['remarks'].replace(' 예약 보류: '+reason,'')
  if kind=='printed-blended-weekly-attendance':
   c['remarks']+=' 현행 수강편람의 블렌디드 시간표 설명에 따라 원문 교시·실의 매주 출석수업 부분만 공개 예약으로 표시합니다. 온라인 부분 시각·방식은 생성하지 않으며 개별 변경·실제 출석은 미확인입니다. 원문 혼합 운영은 유지하며 예약 방식은 사용자 선택을 유지합니다.'
  else:c['remarks']+=' 원문 강의실은 미게시로 빈값을 유지합니다. 알려진 자체 교시·요일의 일반 예약이며 임의 강의실·학점/실습시수 환산은 하지 않습니다. 개별 실습·변경 운영은 미확인입니다.'
  review['dates']=len(c['schedules']);added.append(review)
 data['researchRevision']='blended-physical-and-blank-room-v3'
 (R/f'jeju-{campus}-2026-2.reservation-planned-v3.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 counts[campus]=dict(native=len(data['courses']),scheduled=sum(bool(c['schedules']) for c in data['courses']),dates=sum(len(c['schedules']) for c in data['courses']))
audit=dict(researchOnly=True,completionClaim=False,counts=counts,addedCount=len(added),addedDates=sum(x['dates'] for x in added),addedByKind=dict(collections.Counter(x['kind'] for x in added)),added=added,reviews=reviews,previousWholeScheduledPreserved=1691,previousDatesPreserved=62917,currentWholeClosuresVerified=False,actualAttendanceVerified=False,deliveryModeOverrides=0,campusChanges=0)
(R/'audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in audit.items() if k not in ['added','reviews']},ensure_ascii=False))
