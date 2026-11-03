# -*- coding: utf-8 -*-
from pathlib import Path
import json,copy,hashlib,re,datetime as dt,collections
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
BASE=ROOT/'work/university-research/catalog-c/cnu-native-topic-versus-operation-v10-20261009/cnu-unknown-2026-2.native-topic-research-v10-20261009.json';D=ROOT/'assets/timetable/cnu-daedeok-2026-2.json'
SCREEN=ROOT/'work/university-research/catalog-c/cnu-ordinary-reservation-v2-20261008/source-semantic-screen.json'
TRI=ROOT/'work/university-research/catalog-c/cnu-ordinary-reservation-v3-20261009/existing-source-semantic-triage.json'
CAL=ROOT/'work/university-research/catalog-f/cnu-2026-2-exchange-guide-selected-education.json'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=json.loads(BASE.read_text());new=copy.deepcopy(old);screens={r['courseId']:r for r in json.loads(SCREEN.read_text())['decisions']};tri={r['courseId']:r for r in json.loads(TRI.read_text())['decisions']}
REVIEW={'1345-7007-00': 'Literal main currentuniversitygolfpracticefield at assignedtime;1person1bay is safety arrangement, not privatehourallocation. Videoanalysisteachingmaterial, YouTubeprereading, LSN_RULE conditional IF nonface-to-face not actualpublishedremotelecture date. Full15practices/noactualremoteallocation, preserveconditionalverbatim.', '1345-7007-01': 'Ownfullplan explicit campusgolfpracticeatsettime, individualbayfeedback withinregular groupclass. ConditionalIFremote rule hasnoactualmode/date allocation. OwnThu09–11 source preserved independently.', '1345-7007-02': 'Independent Tue09–11golfsection ownnativecode/prof/wholeheaderweeks; individualbay safety notprivateappointment, conditionalfuture nonface-to-face rule retainednooverride.', '1332-3001-00': 'Veterinary clinicalutilization is textbooklecture about eyeexamination/instruments, not actualpatientcare/clinicalplacement. Main100%lecture/all15lectureweeks, ownThu09–11동물315.', '1291-1008-00': 'Historicalphotographs/videos are audiovisualteachingmaterials. Individualfashiondesign assignment/presentation is academiccoursework, not personallyallocatedclassattendance. Whole15lecture/presentation/nativeMonThu clocks retained.', '1248-3007-00': 'PPT/referencebooks/video media used as lecturematerials, no recordedlecture replacement. Biologicalhazardsresearch themes notindividualresearchplacement. All15lectures/examlabels retained without examdate mapping.', '1349-2012-00': 'Hybridparameter inweek14 refers circuitmodel parameter, not mixedphysical/remoteoperation. WholePPT/tablet/cooperativeclass discussion, personaldevicesallowed but internetforbidden; ownnativeTueWedlecturetimes exact.', '1424-2003-00': 'DistinctnativeFriday19–22 samecircuitacademicmodel hybridparameter, not blendedattendance. Fulloriginalcurrentheader/weekdifferences retained; nativeend22:00 directnotperiodinference.'}
START=dt.date(2026,9,1);END=dt.date(2026,12,18)
CLOSED={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09','2026-12-08','2026-12-09','2026-12-10','2026-12-11'}
inputs={str(p.relative_to(ROOT)):sha(p) for p in [BASE,D,SCREEN,TRI,CAL]};proofs=[]
for c in new['courses']:
 cid=c['sourceEducation']['courseId']
 if cid not in REVIEW:continue
 assert not c['schedules'] and c['campus']=='unknown'
 native=c['sourceEducation']['originalEducationFields'];assert native['OPEN_YR']=='2026' and native['OBJ_CORS_CD_NM']=='학사과정' and native['CLOSE_YN']=='0'
 path=Path(tri[cid]['sourcePlanFile']);plan=json.loads(path.read_text());assert sha(path)==tri[cid]['sourcePlanSHA256'];inputs[str(path.relative_to(ROOT))]=sha(path)
 assert plan['verifiedOn']=='2026-10-08'
 for h in plan['header']:
  assert h['OPEN_SHTM_CD_NM']=='2학기'
  assert h.get('LSN_OPER_UNTACT_YN')=='0'
  if h.get('TLSN_ANNM'):assert re.sub(r'\s','',h['TLSN_ANNM'])==re.sub(r'\s','',c['sourceSchedule'])
 clocks=c['sourceEducation']['actualDisplayedClocks'];assert clocks and all(s['location'] and 0<=s['startMinute']<s['endMinute']<=1440 for s in clocks)
 for a in clocks:
  for b in clocks:
   if a!=b and a['weekday']==b['weekday']:assert a['endMinute']<=b['startMinute'] or b['endMinute']<=a['startMinute']
 meetings=[]
 for slot in clocks:
  day=START
  while day<=END:
   if day.isoweekday()==slot['weekday'] and day.isoformat() not in CLOSED:meetings.append({'date':day.isoformat(),'weekday':slot['weekday'],'startMinute':slot['startMinute'],'endMinute':slot['endMinute'],'classroom':slot['location']})
   day+=dt.timedelta(days=1)
 assert meetings
 c['schedules']=meetings;c['scheduleStatus']='scheduled';c['period']={'startDate':START.isoformat(),'endDate':END.isoformat()}
 note='학교 자체 현재2026-2 기간과 공시 정규 요일·시작/종료 시각·강의실에 따른 예약 계획입니다. 실제 개별 출석·운영·최신변경 완료는 아닙니다. 원문 교과주제/수업교재를 원격·현장·집중 운영으로 추정하지 않습니다. 캠퍼스는 원문unknown 유지하며 건물 약칭으로 도시를 정하지 않습니다. 기존 학교 휴일/12.8–11 보충기간 예약은 제외, 주차번호 시험은 개별 날짜로 변환하지 않습니다. 사용자 수업방식3종 선택은 유지합니다.'
 previous=copy.deepcopy(c['departmentRemarks'])
 c['previousResearchDepartmentRemarks']=previous
 warning='수업 운영 정보를 확인하고 있습니다. 자동 시간표 추가는 아직 지원하지 않습니다.'
 facts=[]
 for h in plan['header']:
  for field,label in [('PRE_LRN_CN','선수학습/수강조건'),('LSN_RULE','수업규칙'),('ATTEND_RULE','출석조건')]:
   if h.get(field):facts.append(label+': '+str(h[field]))
 c['departmentRemarks']={k:v.replace(warning,'')+'\n'+note+'\n'+'\n'.join(dict.fromkeys(facts)) for k,v in previous.items()}
 c['currentPublicPlanEducation']={'header':plan['header'],'weeks':plan['weeks'],'sourceResponseSHA256':plan['sourceResponseSHA256'],'tokenOnlyEducationalRedaction':True}
 c['reservationEvidence']={'kind':'officialCurrentOrdinaryWeeklyReservation','actualAttendanceConfirmed':False,'ownTermProof':str(CAL.relative_to(ROOT)),'nativePhysicalCampusUnconfirmed':True,'currentPlanEducationFile':str(path),'currentPlanResponseSHA256':plan['sourceResponseSHA256'],'semanticMeaning':REVIEW[cid]}
 proofs.append({'courseId':cid,'sourceId':c['sourceId'],'sourceSchedule':c['sourceSchedule'],'nativeClockRows':clocks,'literalDatedMeetings':meetings,'sourcePlanFile':str(path.relative_to(ROOT)),'sourcePlanSHA256':sha(path),'wholeCurrentOriginalEducationalPlan':plan,'oldScreen':screens[cid],'originalTriageSignals':tri[cid]['sourceSignals'],'semanticMeaning':REVIEW[cid],'originalCourse':next(x for x in old['courses'] if x['sourceId']==c['sourceId'])})
changed={r['sourceId'] for r in proofs};assert len(changed)==8
original={c['sourceId']:c for c in old['courses']};assert all(c==original[c['sourceId']] for c in new['courses'] if c['sourceId'] not in changed)
new.update({'researchOnly':True,'productionIntegrationEnabled':False,'completionClaim':False,'actualModelValidationPending':True})
(OUT/'cnu-unknown-2026-2.native-topic-research-v11-20261009.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(OUT/'cnu-daedeok-2026-2.existing-unchanged-v11.json').write_bytes(D.read_bytes())
held=[c for c in old['courses'] if not c['schedules']]
census={'held':len(held),'derivedSourceExplanationCounts':dict(collections.Counter(c['sourceEducation']['derivedBlockingExplanation'] for c in held)),'nativeClocksPresent':sum(bool(c['sourceEducation']['actualDisplayedClocks']) for c in held),'nativeClocksAbsent':sum(not c['sourceEducation']['actualDisplayedClocks'] for c in held),'screenReasonCombinationCounts':[{'reasons':list(k),'count':v} for k,v in collections.Counter(tuple(screens[c['sourceEducation']['courseId']]['screenReasons']) for c in held).items()],'rows':[{'sourceId':c['sourceId'],'courseId':c['sourceEducation']['courseId'],'nativeClockRows':c['sourceEducation']['actualDisplayedClocks'],'sourceExplanation':c['sourceEducation']['derivedBlockingExplanation'],'screenReasons':screens[c['sourceEducation']['courseId']]['screenReasons'],'professorEmpty':not bool(c['professor']),'campus':c['campus']} for c in held]}
(OUT/'all2142-current-held-reason-census.json').write_text(json.dumps(census,ensure_ascii=False,indent=2)+'\n')
audit={'currentWhole':3888,'priorScheduled':1746,'priorDates':43281,'newCourses':8,'newDates':sum(len(r['literalDatedMeetings']) for r in proofs),'candidateScheduled':sum(bool(c['schedules']) for c in new['courses'])+1,'candidateDates':sum(len(c['schedules']) for c in new['courses'])+15,'other3880CoursesDeepUnchanged':True,'sourceSnapshot':'2026-10-08','sourceInputsSHA256':inputs,'ownTermStart':START.isoformat(),'ownTermEnd':END.isoformat(),'reservationExclusions':sorted(CLOSED),'proofs':proofs,'scope':'All2142 held census; next8fullplans8ordinaryapproved;other2134heldunchanged','campusPhysicalConfirmed':False,'sdkUsed':False,'productChanged':False,'actualModelValidationPending':True,'completionClaim':False,'impossibleClaim':False}
(OUT/'independent-native-topic-clock-proof.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print({k:v for k,v in audit.items() if k in ['currentWhole','priorScheduled','priorDates','newCourses','newDates','candidateScheduled','candidateDates']})
