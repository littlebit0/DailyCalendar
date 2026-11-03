"""Current original native clocks and official own term: conservative reservations."""
import copy,datetime as dt,hashlib,json,re
from pathlib import Path
OUT=Path(__file__).resolve().parent
SOURCE=OUT.parents[1]/'catalog-f'
audit=json.loads((OUT/'current-recovery-audit.json').read_text());assert audit['finished']
base=json.loads((OUT/'baseline-cnu-unknown-2026-2.json').read_text());candidate=copy.deepcopy(base)
screen=json.loads((OUT/'cnu-native-cache-screen.json').read_text());shortlist={d['courseId']:d for d in screen['decisions'] if d['ordinaryReviewShortlistOnly']};fresh={r['courseId']:r for r in audit['results']}
special=re.compile(r'집중|비실시간|비대면|실시간|온라인|원격|녹화|동영상|블[렌랜]디드|하이브리드|현장|실습|실험|실기|개별|독립|캡스톤|임상|프로젝트|인턴|군사|휴강|보강|대체|자율|별도|학회|견학|blended|flipped|asynchronous|online|remote|internship|field\s*trip|intensive|recorded|MOOC',re.I)
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09','2026-12-08','2026-12-09','2026-12-10','2026-12-11'}
start=dt.date(2026,9,1);end=dt.date(2026,12,18)
notes='학교 자체 2026-2 수업기간과 현재 공식 공개 요일·실제 시작/끝 시각·강의실의 정규 주간 예약 계획입니다. 실제 출석·개별 휴강·시험 시각을 확정한 정보가 아닙니다. 개별 날짜 미게시만으로 정규 예약을 통째로 보류하지 않았습니다. 학교 정기휴업일과 12/8~11 보충기간, 공휴일은 보수적으로 예약을 제외하며 개별 보강·시험을 추정하지 않습니다. 공시 가상강의(보조강의)는 그 자체로 비동기 출석이라는 뜻이 아닙니다. 캠퍼스는 개별 강좌 물리 위치를 확인하지 못해 unknown으로 보존합니다. 원문 수강 대상·선수조건·학년·교육구분·학점·교수·시각·실 및 전체 교육필드를 보존합니다.'
proofs=[];held=[]
for course in candidate['courses']:
 cid=course['sourceEducation']['courseId']
 if cid not in shortlist:continue
 result=fresh[cid];reasons=[]
 if result.get('held'):held.append({'courseId':cid,'reasons':[result['reason']]});continue
 if result['publicEducationalCatalogChangedFields']:reasons.append('CurrentPublicNativeEducationChanged')
 file=OUT/'current-education'/f'{cid}.json';plan=json.loads(file.read_text())
 for header in plan['header']:
  if header.get('OPEN_SHTM_CD_NM')!='2학기':reasons.append('CurrentSemesterConflict')
  if str(header.get('LSN_OPER_UNTACT_YN',0)) not in ['0','None','']:reasons.append('CurrentSelectedRemote')
  if any(header.get(k) not in [None,0,'0',''] for k in ['LSN_MTHD_SCENE','LSN_MTHD_PRAC','LSN_MTHD_FLIP']):reasons.append('CurrentSpecialOperatingHours')
  if header.get('TLSN_ANNM') and re.sub(r'\s','',header['TLSN_ANNM'])!=re.sub(r'\s','',course['sourceSchedule']):reasons.append('CurrentClockRoomConflict')
 if any(str(w.get('CLS_METHOD_FIELD',0))=='1' for w in plan['weeks']):reasons.append('CurrentFieldTeachingWeeks')
 text=' '.join(str(v) for h in plan['header'] for k,v in h.items() if k in ['LSN_OPER_MTHD','LSN_OPER_MTHD_UNTACT','LSN_MTHD_ETC'])+' '+' '.join(str(v) for w in plan['weeks'] for v in w.values() if isinstance(v,str))
 if special.search(text):reasons.append('CurrentOperatingOrWeeklySpecialSignal')
 if reasons:held.append({'courseId':cid,'reasons':sorted(set(reasons))});continue
 clocks=course['sourceEducation']['actualDisplayedClocks'];assert clocks and all(s['location'] and 0<=s['startMinute']<s['endMinute']<=1440 for s in clocks)
 meetings=[]
 for slot in clocks:
  day=start
  while day<=end:
   if day.isoweekday()==slot['weekday'] and day.isoformat() not in closed:meetings.append({'date':day.isoformat(),'weekday':slot['weekday'],'startMinute':slot['startMinute'],'endMinute':slot['endMinute'],'classroom':slot['location']})
   day+=dt.timedelta(days=1)
 assert meetings
 course['schedules']=meetings;course['scheduleStatus']='scheduled';course['period']={'startDate':start.isoformat(),'endDate':end.isoformat()}
 facts=[]
 labels={'PRE_LRN_CN':'선수학습','LSN_SMRY':'교과 안내','SBJT_SMRY':'교과 개요','LSN_RULE':'수업 규칙','ATTEND_RULE':'출석 조건'}
 for h in plan['header']:
  facts.extend(labels[k]+': '+str(h[k]) for k in labels if h.get(k))
 course['currentPublicPlanEducation']={'header':plan['header'],'weeks':plan['weeks'],'sourceResponseSHA256':plan['sourceResponseSHA256'],'tokenOnlyEducationalRedaction':True}
 for dep,text in course['departmentRemarks'].items():course['departmentRemarks'][dep]=text.replace('수업 운영 정보를 확인하고 있습니다. 자동 시간표 추가는 아직 지원하지 않습니다.',notes)+'\n'+'\n'.join(dict.fromkeys(facts))
 course['reservationEvidence']={'kind':'officialCurrentOrdinaryWeeklyReservation','actualAttendanceConfirmed':False,'ownTermProof':'work/university-research/catalog-f/cnu-2026-2-exchange-guide-selected-education.json','nativePhysicalCampusUnconfirmed':True,'currentPlanEducationFile':str(file),'currentPlanResponseSHA256':plan['sourceResponseSHA256']}
 proofs.append({'sourceId':course['sourceId'],'courseId':cid,'nativeClockRows':clocks,'sourcePlanFile':str(file),'sourcePlanFileSHA256':hashlib.sha256(file.read_bytes()).hexdigest(),'currentPlanResponseSHA256':plan['sourceResponseSHA256'],'publicEducationChangedFields':result['publicEducationalCatalogChangedFields'],'campus':'unknown','meetings':len(meetings),'ordinaryReservationOnly':True,'actualAttendanceConfirmed':False})
added={p['sourceId'] for p in proofs}
for old,new in zip(base['courses'],candidate['courses']):
 if old['sourceId'] not in added:assert old==new
 else:
  copied=copy.deepcopy(new);copied.pop('reservationEvidence');copied.pop('currentPublicPlanEducation');
  for k in ['schedules','scheduleStatus','period','departmentRemarks']:
   if k in old:copied[k]=old[k]
   else:copied.pop(k,None)
  assert copied==old
candidate.update({'completionClaim':False,'wholeOperatingReviewComplete':False,'researchOnly':True,'actualAttendanceConfirmed':False})
name='cnu-unknown-2026-2.ordinary-reservation-research-v1-20261008.json';data=(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n').encode();(OUT/name).write_bytes(data)
report={'completionClaim':False,'productionEdited':False,'sdkUsed':False,'actualModelValidationPending':True,'candidateFile':name,'candidateSHA256':hashlib.sha256(data).hexdigest(),'wholeCourses':len(base['courses']),'existingScheduled':sum(bool(c['schedules']) for c in base['courses']),'existingObjectsDeepUnchanged':True,'newOrdinary':len(proofs),'scheduled':sum(bool(c['schedules']) for c in candidate['courses']),'meetings':sum(len(c['schedules']) for c in candidate['courses']),'proofs':proofs,'heldAfterCurrentRecovery':held,'excludedReservationDates':sorted(closed)}
(OUT/'candidate-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in report.items() if k not in ['proofs','heldAfterCurrentRecovery']})
