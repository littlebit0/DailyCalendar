import json,copy,datetime as dt,hashlib,re,collections
from pathlib import Path
from parse_mirae_education_groups import parse
p=Path(__file__).parent
old=Path('work/university-research/catalog-w/yonsei')
legend=Path('work/university-research/root-yonsei-mirae-legend-20261009.json')
l=json.loads(legend.read_text())
assert l['scope']=='<미래캠퍼스>' and l['currentSemester']=='2026-2' and l['sinchonGeneralization'] is False
assert '월1 → 월요일 1교시 강의 / (월1) → 월요일 1교시 실습' in l['literal']
(p/'current-mirae-official-legend.json').write_bytes(legend.read_bytes())
(p/'current-native-clock-proof-v1.json').write_bytes((old/'current-native-clock-proof-v1.json').read_bytes())
review=json.loads((p/'prior-mirae-parenthesis-structural-review.json').read_text())
byid={r['sourceId']:r for r in review['reviewRows']}
closedDates={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
dates=[];day=dt.date(2026,9,1)
while day<=dt.date(2026,12,7):
 if day.isoformat() not in closedDates and not dt.date(2026,10,20)<=day<=dt.date(2026,10,26):dates.append(day)
 day+=dt.timedelta(days=1)
updates=[];manifest=[];priorScheduled=0;totalScheduled=0;priorFrames=0;totalFrames=0
for campus in ['sinchon','international','mirae','unknown']:
 f=old/f'yonsei-{campus}-2026-2.published-partial-v1.json'
 data=json.loads(f.read_text());out=copy.deepcopy(data)
 (p/f'baseline-yonsei-{campus}-v1.json').write_bytes(f.read_bytes())
 for c,before in zip(out['courses'],data['courses']):
  if before['schedules']:
   priorScheduled+=1;priorFrames+=len(before['schedules'])
  if campus=='mirae' and c['sourceId'] in byid and 'nativeSlots' in byid[c['sourceId']]:
   assert not c['schedules']
   native=c['sourceEducation'][0]
   assert native['sysinstDivCd']=='H2' and native['campsDivNm']=='미래' and native['rmvlcYn']=='0' and native['lessnSessnDivNm']=='학기' and native['subjtClNm'].strip()=='대면강의'
   slots=parse(c['sourceSchedule'],c['sourceClassroom'])
   meetings=[]
   for date in dates:
    for slot in slots:
     if slot['weekday']==date.isoweekday():
      meetings.append({k:v for k,v in slot.items() if k not in ['nativePeriod','nativeGroupKind']}|{'date':date.isoformat()})
   c['schedules']=meetings;c['scheduleStatus']='scheduled'
   note=c['remarks'].split('\n일정 보류:')[0]+'\n2026-10-09 현재 공식 미래캠퍼스 안내에서 괄호 교시는 실습으로 확인했습니다. 강의·실습 원문 시각과 대응 강의실 및 별도 실습분반을 보존한 정규 예약입니다. 실제 출석·개별 시험·보충수업은 미확인입니다.'
   if 'PRE-CLASS' in (native.get('atntnMattrDesc') or ''):
    note+=' 원문 FC 안내는 동영상 사전학습 후 수업참여 조건이며 정규 출석을 대체한다는 의미로 해석하지 않았습니다.'
   c['remarks']=note;c['departmentRemarks']={department:note for department in c['departments']}
   c['reservationEvidenceV2']={'legendScope':'미래캠퍼스','legendCurrentSemester':'2026-2','legendSha256':hashlib.sha256(legend.read_bytes()).hexdigest(),'nativeSlots':slots,'originalSourceAcquisitionDate':'2026-10-07','currentWholeCourseFreshnessVerified':False,'actualAttendanceConfirmed':False}
   updates.append({'sourceId':c['sourceId'],'nativeSlots':slots,'meetings':len(meetings),'educationAliases':len(c['sourceEducation'])})
  elif before['schedules']:assert c==before
  totalScheduled+=bool(c['schedules']);totalFrames+=len(c['schedules'])
 if campus=='mirae':out['reservationResearchRevision']='v2-mirae-official-parenthesis-legend-20261009'
 target=p/f'yonsei-{campus}-2026-2.published-partial-v2-20261009.json'
 target.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
 manifest.append({'campus':campus,'file':target.name,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'courses':len(out['courses']),'scheduled':sum(bool(c['schedules']) for c in out['courses']),'meetings':sum(len(c['schedules']) for c in out['courses'])})
assert len(updates)==324 and priorScheduled==2396 and priorFrames==83863
receipt={'researchOnly':True,'completionClaim':False,'wholeOperatingVerified':False,'wholeMetadata':4710,'nativeOriginalUnique':4926,'closedOriginal':216,'oldScheduledDeepPreserved':2396,'oldFrames':83863,'newEligible':len(updates),'newFrames':totalFrames-priorFrames,'totalScheduled':totalScheduled,'totalFrames':totalFrames,'remainingMiraeParenthesisHeld':38,'sourceLegendVerified':True,'currentWholeCourseFreshnessVerified':False,'manifest':manifest,'newNativeProofs':updates}
(p/'candidate-audit-v2.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n')
print({k:v for k,v in receipt.items() if k not in ['manifest','newNativeProofs']})
