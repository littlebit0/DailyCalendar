"""Separate research candidate from immutable existing current native clock evidence."""
import copy,datetime as dt,hashlib,json
from pathlib import Path
OUT=Path(__file__).resolve().parent
PRIOR=OUT.parent/'cnu-ordinary-reservation-v2-20261008'
base_path=PRIOR/'cnu-unknown-2026-2.ordinary-reservation-research-v2-20261008.json'
base=json.loads(base_path.read_text());candidate=copy.deepcopy(base)
a=json.loads((OUT/'existing-source-semantic-triage.json').read_text());eligible={r['courseId']:r for r in a['decisions'] if r['preliminaryOrdinary']}
raw=json.loads((PRIOR/'current-public-native-educational-catalog.json').read_text());assert len(raw)==len({r['COURSE_NO'] for r in raw})
independent={r['COURSE_NO']:r for r in raw}
start=dt.date(2026,9,1);end=dt.date(2026,12,18)
closed=set(json.loads((PRIOR/'candidate-audit.json').read_text())['excludedReservationDates'])
proofs=[];held=[]
notes='현재 학교 공개 요일·실제 시각·강의실과 학교 자체 학기범위의 정규 주간 예약 계획입니다. 실제 개인 출석일·개별 시험/휴강/보강을 확정한 자료가 아닙니다. 원문에 대면이라는 단어가 없다는 이유만으로 일반 강의·실습 예약을 보류하지 않았습니다. 현재 원문은 2026-10-08 확보분이며 오늘의 재조회로 주장하지 않습니다. 개별 교수/수업 운영 변경은 추가 확인이 필요합니다. 공휴일과 학교 보충기간12/8~11은 기존 검증 기준대로 제외합니다. 사용자 수업모드를 강제하지 않으며 물리 캠퍼스는 unknown으로 보존합니다.'
for c in candidate['courses']:
 cid=c['sourceEducation']['courseId']
 if cid not in eligible:continue
 r=eligible[cid];source=independent[cid];reasons=[]
 for key,value in [('OPEN_SBJT_NO',c['courseCode']),('OPEN_DCLSS',c['section']),('SBJT_NM',c['courseName']),('LT_STAFF_NM',c['professor']),('TMTBL_INFO',c['sourceSchedule'])]:
  if (source.get(key) or '')!=value:reasons.append('IndependentNativeFieldConflict:'+key)
 slots=c['sourceEducation']['actualDisplayedClocks']
 for i,s in enumerate(slots):
  for t in slots[i+1:]:
   if s['weekday']==t['weekday'] and max(s['startMinute'],t['startMinute'])<min(s['endMinute'],t['endMinute']):reasons.append('NativeClockOverlapNeedsAllocationReview')
 if reasons:held.append({'courseId':cid,'reasons':sorted(set(reasons))});continue
 meetings=[]
 for slot in slots:
  day=start
  while day<=end:
   if day.isoweekday()==slot['weekday'] and day.isoformat() not in closed:
    meetings.append({'date':day.isoformat(),'weekday':slot['weekday'],'startMinute':slot['startMinute'],'endMinute':slot['endMinute'],'classroom':slot['location']})
   day+=dt.timedelta(days=1)
 assert len(meetings)==len({(m['date'],m['startMinute'],m['endMinute'],m['classroom']) for m in meetings})
 c['schedules']=meetings;c['scheduleStatus']='scheduled';c['period']={'startDate':start.isoformat(),'endDate':end.isoformat()}
 for dep,text in c['departmentRemarks'].items():c['departmentRemarks'][dep]=text.replace('수업 운영 정보를 확인하고 있습니다. 자동 시간표 추가는 아직 지원하지 않습니다.',notes)
 c['reservationEvidence']={'kind':'officialCurrentOrdinaryWeeklyReservation','actualAttendanceConfirmed':False,'ownTermProof':'work/university-research/catalog-f/cnu-2026-2-exchange-guide-selected-education.json','sourcePlanFile':r['sourcePlanFile'],'sourcePlanFileSHA256':r['sourcePlanSHA256'],'sourceResponseSHA256':r['sourceResponseSHA256'],'sourceVerifiedOn':r['sourceVerifiedOn'],'currentDayRequeryClaim':False,'ordinaryForegroundPhraseRequired':False,'physicalCampusUnconfirmed':True,'semanticTriageRevision':'v3','individualModeOverride':False}
 proofs.append({'courseId':cid,'sourceId':c['sourceId'],'sourcePlanFile':r['sourcePlanFile'],'sourcePlanSHA256':r['sourcePlanSHA256'],'nativeClocks':slots,'meetings':len(meetings),'mainOperatingStatements':r['mainOperatingStatements'],'independentNativeIdentityMatch':True,'actualAttendanceConfirmed':False})
new={p['sourceId'] for p in proofs}
for old,c in zip(base['courses'],candidate['courses']):
 if c['sourceId'] not in new:assert c==old
 else:
  z=copy.deepcopy(c);z.pop('reservationEvidence');
  for key in ['schedules','scheduleStatus','period','departmentRemarks']:
   if key in old:z[key]=old[key]
   else:z.pop(key,None)
  assert z==old
candidate.update({'completionClaim':False,'wholeOperatingReviewComplete':False,'researchOnly':True,'actualAttendanceConfirmed':False})
name='cnu-unknown-2026-2.ordinary-reservation-research-v3-20261009.json';(OUT/name).write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n')
report={'stage':'researchCandidateActualModelValidationPending','completionClaim':False,'SDKUsed':False,'productEdited':False,'baselinePath':str(base_path),'baselineSHA256':hashlib.sha256(base_path.read_bytes()).hexdigest(),'wholeUnknown':len(candidate['courses']),'priorUnknownScheduled':1427,'priorUnknownObjectsDeepPreserved':True,'newOrdinary':len(proofs),'unknownScheduled':sum(bool(c['schedules']) for c in candidate['courses']),'unknownMeetings':sum(len(c['schedules']) for c in candidate['courses']),'unchangedDaedeokPath':str(PRIOR/'cnu-daedeok-2026-2.existing-unchanged-20261008.json'),'wholeInstitutionCourses':3888,'wholeInstitutionScheduled':sum(bool(c['schedules']) for c in candidate['courses'])+1,'wholeInstitutionMeetings':sum(len(c['schedules']) for c in candidate['courses'])+15,'candidateFile':name,'candidateSHA256':hashlib.sha256((OUT/name).read_bytes()).hexdigest(),'closedDates':sorted(closed),'sourceHeaderWeekFilesRead':830,'priorHeldSingleForegroundPool':830,'proofs':proofs,'heldAfterJoin':held}
(OUT/'candidate-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in report.items() if k not in ['proofs','heldAfterJoin']});print('joinsheld',held)
