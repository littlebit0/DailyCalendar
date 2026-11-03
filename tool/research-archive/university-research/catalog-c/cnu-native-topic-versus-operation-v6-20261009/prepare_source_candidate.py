# -*- coding: utf-8 -*-
from pathlib import Path
import json,copy,hashlib,re,datetime as dt,collections
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[3]
BASE=ROOT/'work/university-research/catalog-c/cnu-native-topic-versus-operation-v5-20261009/cnu-unknown-2026-2.native-topic-research-v5-20261009.json';D=ROOT/'assets/timetable/cnu-daedeok-2026-2.json'
SCREEN=ROOT/'work/university-research/catalog-c/cnu-ordinary-reservation-v2-20261008/source-semantic-screen.json'
TRI=ROOT/'work/university-research/catalog-c/cnu-ordinary-reservation-v3-20261009/existing-source-semantic-triage.json'
CAL=ROOT/'work/university-research/catalog-f/cnu-2026-2-exchange-guide-selected-education.json'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=json.loads(BASE.read_text());new=copy.deepcopy(old);screens={r['courseId']:r for r in json.loads(SCREEN.read_text())['decisions']};tri={r['courseId']:r for r in json.loads(TRI.read_text())['decisions']}
REVIEW={'1724-0003-00': 'Online political participation is a lecture topic; full body instructor-led classroomlectures/studentpresentations. No remote attendance allocation.', '1135-1006-00': 'The original literal 임상철도 사례 occurs under measurement/scales as a research case; preserve literal typo, do not relabel it as a clinical placement. Full theory/groupconceptproject source has no field attendance allocation.', '1220-3011-00': 'Hybrid separation process is an engineering academic topic, not hybrid class delivery. Explicit professor-led lecture/discussion; full15weeks and native HH/room retained.', '1250-3023-00': 'Online distribution is an agricultural distribution topic, not online class operation. Whole lectures/papercritique seminars preserve nativeTuesday9–12room.', '1247-4011-00': 'Industrial practical cases are lecture examples about thermodynamic engine mechanisms, not students visiting industrial sites. Main literal 대면 and whole100percentlectures; alternative merely lecture/discussion.', '1271-3023-00': 'Clinical laboratory values and clinical pharmacy services are academic interpretation topics, not clinical attendance. Main80percentlectures20percentPBL/groupdiscussion; wholeweeks ordinaryteaching.', '1271-3024-00': 'Field-use examples and invited experts describe classroomintroductions and invited talks, not student fieldplacement. Full sourcelecture/presentation pedagogy without externalattendanceallocation.', '1311-7001-00': 'Concentration on transcendence or artisticcreation is art-history content, not intensiveclasssemester. Mainprofessorlecture and all15weekly academic paragraphs.', '1311-2018-00': 'External mesh processing means import/manipulation of3Dgeometry data inZBrush, not offcampus attendance. Full15weekly softwarelab/lecture, no alternate siteorclock.', '1313-3010-00': 'Outside experts are invited guestclassroomlecturers, not students visiting externalsites. Full theory/practice/speaker15weeks preserve two contiguous ownWednesday clockrows.', '1000-9005-03': 'Remoteeducation is week14 academic theory/design topic. Actualmainoperation onehourlecture plusonehourteamclassactivity. Sourceeducationgraduate-priority prerequisite retained visibly; native enrollment row itself is 학사과정 and remains unchanged.', '1000-9282-00': 'Remoteadulteducation methods are theorybeingstudied, not course delivery. Fullproject/discussion body and15weekstheorytopics; source doesnotallocate remoteattendance.', '1000-9586-01': 'Autonomousdriving law and lossofconcentration are AIeducation academic topics. Mainlecture/lab/discussion and15weeks no outside allocation.', '1344-3009-00': 'Concentrated project drafting/feedback is classactivity, not intensivesemester. Body says everyclass haslecture/teamdiscussion/PBL; no alternative periodorplace.', '1345-3014-00': 'Autonomous team tactics mean volleyballgameplay, not individually allocated attendance. Main explicitphysicaltheorythenphysicalpractice; exactTuesdaytheoryroom andFridaystadium native rows retained.', '1345-4006-00': 'Jump reinforcement drills and strengtheningexercises are athleticspractice topics, not makeupclasses. Main actualCNUstadium/gympractice; ownWednesdaystadium andThursdayroomprinted. No cancelled datesorunknownsite invented.', '1361-2021-00': 'Clinical features/symptoms are microbiology academic content. Fullsourcelecture/PBL scenarioanalysis creates infectioneducation projects, not clinicalsite visits; no REFremote contradiction unlike siblingnursingcourse.'}
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
changed={r['sourceId'] for r in proofs};assert len(changed)==17
original={c['sourceId']:c for c in old['courses']};assert all(c==original[c['sourceId']] for c in new['courses'] if c['sourceId'] not in changed)
new.update({'researchOnly':True,'productionIntegrationEnabled':False,'completionClaim':False,'actualModelValidationPending':True})
(OUT/'cnu-unknown-2026-2.native-topic-research-v6-20261009.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(OUT/'cnu-daedeok-2026-2.existing-unchanged-v6.json').write_bytes(D.read_bytes())
held=[c for c in old['courses'] if not c['schedules']]
census={'held':len(held),'derivedSourceExplanationCounts':dict(collections.Counter(c['sourceEducation']['derivedBlockingExplanation'] for c in held)),'nativeClocksPresent':sum(bool(c['sourceEducation']['actualDisplayedClocks']) for c in held),'nativeClocksAbsent':sum(not c['sourceEducation']['actualDisplayedClocks'] for c in held),'screenReasonCombinationCounts':[{'reasons':list(k),'count':v} for k,v in collections.Counter(tuple(screens[c['sourceEducation']['courseId']]['screenReasons']) for c in held).items()],'rows':[{'sourceId':c['sourceId'],'courseId':c['sourceEducation']['courseId'],'nativeClockRows':c['sourceEducation']['actualDisplayedClocks'],'sourceExplanation':c['sourceEducation']['derivedBlockingExplanation'],'screenReasons':screens[c['sourceEducation']['courseId']]['screenReasons'],'professorEmpty':not bool(c['professor']),'campus':c['campus']} for c in held]}
(OUT/'all2184-current-held-reason-census.json').write_text(json.dumps(census,ensure_ascii=False,indent=2)+'\n')
audit={'currentWhole':3888,'priorScheduled':1704,'priorDates':42409,'newCourses':17,'newDates':sum(len(r['literalDatedMeetings']) for r in proofs),'candidateScheduled':sum(bool(c['schedules']) for c in new['courses'])+1,'candidateDates':sum(len(c['schedules']) for c in new['courses'])+15,'other3871CoursesDeepUnchanged':True,'sourceSnapshot':'2026-10-08','sourceInputsSHA256':inputs,'ownTermStart':START.isoformat(),'ownTermEnd':END.isoformat(),'reservationExclusions':sorted(CLOSED),'proofs':proofs,'scope':'All2184 coarse reason census; first20 fullplans individually reviewed17 approved3actualcomplications held; other2167 held not approved','campusPhysicalConfirmed':False,'sdkUsed':False,'productChanged':False,'actualModelValidationPending':True,'completionClaim':False,'impossibleClaim':False}
(OUT/'independent-native-topic-clock-proof.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print({k:v for k,v in audit.items() if k in ['currentWhole','priorScheduled','priorDates','newCourses','newDates','candidateScheduled','candidateDates']})
