# -*- coding: utf-8 -*-
from pathlib import Path
import json,copy,hashlib,re,datetime as dt,collections
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
BASE=ROOT/'work/university-research/catalog-c/cnu-full-context-review-packet-v19-20261009/cnu-unknown-2026-2.native-topic-research-v19-20261009.json';D=ROOT/'work/university-research/catalog-c/cnu-full-context-review-packet-v19-20261009/cnu-daedeok-2026-2.existing-unchanged-v19.json'
SCREEN=ROOT/'work/university-research/catalog-c/cnu-ordinary-reservation-v2-20261008/source-semantic-screen.json'
TRI=ROOT/'work/university-research/catalog-c/cnu-ordinary-reservation-v3-20261009/existing-source-semantic-triage.json'
CAL=ROOT/'work/university-research/catalog-f/cnu-2026-2-exchange-guide-selected-education.json'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=json.loads(BASE.read_text());new=copy.deepcopy(old);screens={r['courseId']:r for r in json.loads(SCREEN.read_text())['decisions']};tri={r['courseId']:r for r in json.loads(TRI.read_text())['decisions']}
REVIEW={'1308-7004-00': 'In-class drawing demonstrations, individual corrective feedback and all15 material exercises; no private lesson or field allocation. NativeWed16:30–18 andFri15–16:30교209A preserved.', '1309-1001-00': 'Shared timed human-model painting with teacher circulating among student works; short5/10/20/40minute drawing poses are exercise duration, not student class allocation. EntireTue09–13미0307 and all15 shared model/painting/critique topics retained.', '1309-3013-00': 'All students bring laptops for shared Adobe demonstrations/exercises, individually checked inside class. Exhibition/competition/portfolio are future applications, not offsite class. NativeWed09:30–11:30미0208 retained.', '1309-4002-00': 'Explicit shared lecture30/discussion40/individual presentation30; one-to-one critiques are feedback on works inside overall class. Full15 creation/peer critique and no separately assigned attendance. NativeThu09–13미0310 retained.', '1310-4007-00': 'Whole studio creation, public presentation and mutual critique with individual work feedback, no separately allocated private lesson. NativeMon09–13미0219 and all15 source preserved.', '1310-4010-00': 'Ordinary lectures/discussions/material study and creation.2023HongKongBasel artworks are historical artworks viewed, not2026travel or semester mismatch. NativeThu14–18미0219 unchanged.', '1311-3011-00': 'Shared stone-sculpture tools and coordinate-system exercises, individual project feedback not student time allocation. NativeMon14–18미0117 and all15 field values intact.', '1311-3012-00': 'Shared professional human-model sculpture, safety/observational/casting/critique exercises and on-campus exhibition. Different materials are individual artistic choices, no alternate student time. NativeTue14–18미0117 preserved.', '1311-4026-00': 'Studio creation and group feedback/presentations; intensive production describes degree of effort, not shorter semester. All15 nativeTue14–18미0118 unchanged.', '1314-3011-00': 'Slip-casting manufacturing exercises use first-semester CAD results and current2term fabrication. One-to-one tailored feedback on individual products does not change shared timetable. Two identical headers/30weeklyrows preserve duplication without duplicated appointments. NativeMon12–13 plusTue15–16/16–17예디자3208 retained.', '1313-3031-00': 'Two-teacher shared design project/PBL/presentation class; individual critiques within team project do not assign private attendance. NativeTue12–13/15–16/16–17예디자3308 and exact prerequisites retained.', '1313-4007-00': 'Explicit bothteachers participate in weekly class and feedback; AI-created video is project output, not lectureVOD. All15 joint design/video demonstrations/presentations and whole professor fields retained. NativeWed12–13/15–16/16–17예디자3309 preserved.', '1332-3013-00': 'All15 veterinary internalmedicine THEORY and clinical knowledge topics, PowerPoint/video teaching MATERIALS, team teaching. Two topics perweek changes content sequencing, not own Tue/Wed11–13동물315 hour allocation. No clinical patient placement.', '1332-3022-00': 'Fixed group diagnostic laboratory exercises with5–10students and case-based discussion, not individual clinical placement/rotation. Full15 blood/smear/urine lab topics and ownThu17–19동물315 retained.', '1332-3022-01': 'Same diagnostic lab shared fixed group coursework, independent source section ownThu15–17동물315; no invented clinical assignment or group time split.', '1101-1001-00': 'Explicit face-to-face principle, remote only futureCOVID situation. Literature genre/history/interpretation all15 topics, cybercampus only shares materials. NativeWed10–12자2215 andFri14–15자2215 retained.', '1101-2002-01': 'Ordinary literature lecture/quiz/PBL/presentations; stage3–4 Zoom only conditional future restriction, no actual individual day replacement. Source reading/analysis topics not attendance mode. OwnMon10–12자2209/Thu14–15자2201 preserved.', '1341-2014-00': 'Reading education theory and digital INDIRECT field exploration, no actual external visit. Full15 reading strategies/assessment/lesson plan presentations ordinary. OwnTue13–15자2306/Thu09–10자2201 preserved.', '1341-4007-00': 'Media-language theory, digital practice and classroom flipped/cooperative pedagogy; field-based describes pedagogy application, no actual travel/placement or lecture-recording allocation. Full15 media/curriculum/criticism topics ordinary. NativeTue09–11자2306/Fri09–11자2201 retained.', '1342-1004-00': 'Every15week shared PBL/project/AI grammar learning, prereading is printed text not lectureVOD. Uploaded lecture videos only hypothetical unavoidable remote change. All15 ordinary grammar topics, nativeWed14–17자2211 and eligibility/rules preserved.'}
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
changed={r['sourceId'] for r in proofs};assert len(changed)==20
original={c['sourceId']:c for c in old['courses']};assert all(c==original[c['sourceId']] for c in new['courses'] if c['sourceId'] not in changed)
new.update({'researchOnly':True,'productionIntegrationEnabled':False,'completionClaim':False,'actualModelValidationPending':True})
(OUT/'cnu-unknown-2026-2.native-topic-research-v20-20261009.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(OUT/'cnu-daedeok-2026-2.existing-unchanged-v20.json').write_bytes(D.read_bytes())
held=[c for c in old['courses'] if not c['schedules']]
census={'held':len(held),'derivedSourceExplanationCounts':dict(collections.Counter(c['sourceEducation']['derivedBlockingExplanation'] for c in held)),'nativeClocksPresent':sum(bool(c['sourceEducation']['actualDisplayedClocks']) for c in held),'nativeClocksAbsent':sum(not c['sourceEducation']['actualDisplayedClocks'] for c in held),'screenReasonCombinationCounts':[{'reasons':list(k),'count':v} for k,v in collections.Counter(tuple(screens[c['sourceEducation']['courseId']]['screenReasons']) for c in held).items()],'rows':[{'sourceId':c['sourceId'],'courseId':c['sourceEducation']['courseId'],'nativeClockRows':c['sourceEducation']['actualDisplayedClocks'],'sourceExplanation':c['sourceEducation']['derivedBlockingExplanation'],'screenReasons':screens[c['sourceEducation']['courseId']]['screenReasons'],'professorEmpty':not bool(c['professor']),'campus':c['campus']} for c in held]}
(OUT/'all2104-current-held-reason-census.json').write_text(json.dumps(census,ensure_ascii=False,indent=2)+'\n')
audit={'currentWhole':3888,'priorScheduled':1784,'priorDates':44185,'newCourses':20,'newDates':sum(len(r['literalDatedMeetings']) for r in proofs),'candidateScheduled':sum(bool(c['schedules']) for c in new['courses'])+1,'candidateDates':sum(len(c['schedules']) for c in new['courses'])+15,'other3868CoursesDeepUnchanged':True,'sourceSnapshot':'2026-10-08','sourceInputsSHA256':inputs,'ownTermStart':START.isoformat(),'ownTermEnd':END.isoformat(),'reservationExclusions':sorted(CLOSED),'proofs':proofs,'scope':'Next50fullheaderand765weeklyrows;20ordinaryapproved;otherheldandpendingsourceallocatedseparately','campusPhysicalConfirmed':False,'sdkUsed':False,'productChanged':False,'actualModelValidationPending':True,'completionClaim':False,'impossibleClaim':False}
(OUT/'independent-native-topic-clock-proof.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print({k:v for k,v in audit.items() if k in ['currentWhole','priorScheduled','priorDates','newCourses','newDates','candidateScheduled','candidateDates']})
