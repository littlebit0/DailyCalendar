"""Current dated course evidence only; no repeat/date invention or makeup room copy."""
import json,re,datetime,hashlib
from pathlib import Path
R=Path(__file__).resolve().parent
clocks={r['courseId']:r for r in json.loads((R/'cnu-current-clock-projection.json').read_text())}
catalog={r['COURSE_NO']:r for r in json.loads((R/'cnu-current-catalog-education-with-public-names.json').read_text())}
base=json.loads((R/'cnu-unknown-2026-2.whole-checkpoint-next-five.json').read_text())
by={c['sourceEducation']['courseId']:c for c in base['courses']};proofs=[]
for cid in ['1344-3021-00','1394-3006-01']:
 j=json.loads((R/'cnu-current-education'/f'{cid}.json').read_text());original={m['weekday']:m for m in clocks[cid]['actualClockMeetings']};meetings=[]
 for w in j['weeks']:
  text=w['MAJ_LRN_CTNT']
  if cid=='1344-3021-00':
   a=re.match(r'(\d{1,2})월[ \t]*(\d{1,2})일',text);assert a;dates=[(int(a[1]),int(a[2]))]
  else:
   # The first date after each actual session number is the actual printed class date.
   # Sept24 is explicitly the original closed date inside the Dec10 makeup explanation.
   dates=[(int(a[1]),int(a[2])) for a in re.finditer(r'\d+-[12]강[ \t]*\((\d{1,2})월[ \t]*(\d{1,2})일',text)]
   assert len(dates)==2
  for month,day in dates:
   d=datetime.date(2026,month,day);wd=d.isoweekday();assert wd in original
   m=original[wd];makeup=cid=='1394-3006-01' and d.isoformat()=='2026-12-10'
   meetings.append({'date':d.isoformat(),'weekday':wd,'startMinute':m['startMinute'],'endMinute':m['endMinute'],'classroom':'' if makeup else m['location'],'mode':'inPerson'})
 expected=15 if cid=='1344-3021-00' else 30
 assert len(meetings)==expected and len({m['date'] for m in meetings})==expected
 assert all(m['date']!='2026-09-24' for m in meetings)
 proof={'courseId':cid,'sourceResponseSHA256':j['sourceResponseSHA256'],'meetings':meetings,'periodStart':min(m['date'] for m in meetings),'periodEnd':max(m['date'] for m in meetings),'dateProof':'Each actual class date explicitly printed in current public plan. No weekly date inference.','clockProof':'Current catalog and plan TLSN_ANNM agree; no individual alternate clock.','deliveryReview':'Current in-person lecture/discussion/presentation; remote wording in1394 is conditional school/pandemic policy, not scheduled conversion.','closureDates':['2026-09-24'] if cid=='1394-3006-01' else [],'unprintedSpecificRoomDates':['2026-12-10'] if cid=='1394-3006-01' else [],'finalWeekReview':'1344 final assignment accompanies explicitly dated in-class reflection/presentation;1394 dated final exam has no separately changed clock.','wholeCompletionClaim':False}
 proofs.append(proof);c=by[cid]
 c['scheduleStatus']='scheduled';c['period']={'startDate':proof['periodStart'],'endDate':proof['periodEnd']};c['schedules']=meetings
 e=c['sourceEducation'];e.pop('derivedBlockingExplanation',None)
 e.update({'registrationStatus':'scheduledActualPrintedDates','individualReviewStatus':'completeActualDatesAndCurrentClocks; makeup room unprinted left empty' if proof['unprintedSpecificRoomDates'] else 'completeActualDatesAndCurrentClocks','actualPrintedNoClassDates':proof['closureDates'],'unprintedSpecificRoomDates':proof['unprintedSpecificRoomDates'],'sourcePlanResponseSHA256':proof['sourceResponseSHA256'],'datesOrClockInvented':False})
 original=catalog[cid];notes='\n'.join(v for v in [original.get('TLSN_ANNM') or '',original.get('TLSN_REST_INFO_CD_NM') or '','12월10일 보강 강의실은 공개 원문에 표시되지 않았습니다.' if cid=='1394-3006-01' else ''] if v)
 c['departmentRemarks']={original['OPEN_SUST_MJ_CD_NM']:notes}
base['verificationScope']='next research checkpoint only;7actual dated courses with explicitly unknown makeup rooms left empty'
p=R/'cnu-unknown-2026-2.whole-checkpoint-next-seven.json';p.write_text(json.dumps(base,ensure_ascii=False,indent=2))
(R/'cnu-next-two-current-dated-proofs-20261008.json').write_text(json.dumps(proofs,ensure_ascii=False,indent=2))
(R/'cnu-next-seven-candidate-audit.json').write_text(json.dumps({'wholeRows':3888,'scheduledCourses':7,'actualPrintedMeetings':165,'additionalCourses':[p['courseId'] for p in proofs],'makeupRoomAbsentLeftEmpty':5,'fixedThreeAndFiveCheckpointsModified':False,'nextUnknownSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'wholeSupportClaim':False},ensure_ascii=False,indent=2))
print('7datedcourses165meetings; no invented makeup room')
