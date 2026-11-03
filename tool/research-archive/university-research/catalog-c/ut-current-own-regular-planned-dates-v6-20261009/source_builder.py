# coding: utf-8
import json,copy,hashlib,datetime,re
from pathlib import Path
b=Path('work/university-research/catalog-c/ut-current-own-regular-planned-dates-v6-20261009');b.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
priorpath=Path('work/university-research/catalog-c/ut-biotech-known-native-blank-room-v4-20261009/ut-unknown-2026-2.biotech-blankroom-v4.json');old=json.loads(priorpath.read_text());c=copy.deepcopy(old);assert len(c['courses'])==61 and sum(len(x['schedules']) for x in c['courses'])==395
bio=Path('work/university-research/catalog-c/ut-current-20261008/biotech-original-educational-grid.json');bg=json.loads(bio.read_text());elec=Path('work/university-research/catalog-c/ut-current-electri-exact-75-block-v2-20261009/independent-source-clock-column-and-grade-headers.json');eg=json.loads(elec.read_text());rule=Path('work/university-research/catalog-c/ut-current-own-regular-term-rule-proof-v5-20261009/independent-current-own-regular-term-rule-education-proof.json');rp=json.loads(rule.read_text());calendar=Path('work/university-research/catalog-c/ut-current-20261008/calendar-educational-dates.json');cal=json.loads(calendar.read_text());events=cal['events'];assert any(x['startDate']=='2026-10-20' and x['endDate']=='2026-10-26' and '중간' in x['subject'] for x in events);assert any(x['startDate']=='2026-12-08' and '보강' in x['subject'] for x in events)
late={1:'2026-11-02 2026-11-09 2026-11-16 2026-11-23 2026-11-30 2026-12-07'.split(),2:'2026-10-27 2026-11-03 2026-11-10 2026-11-17 2026-11-24 2026-12-01'.split(),3:'2026-10-28 2026-11-04 2026-11-11 2026-11-18 2026-11-25 2026-12-02'.split(),4:'2026-10-29 2026-11-05 2026-11-12 2026-11-19 2026-11-26 2026-12-03'.split(),5:'2026-10-30 2026-11-06 2026-11-13 2026-11-20 2026-11-27 2026-12-04'.split()}
oldbio='개강9/1부터 중간고사 권장기간 전10/19까지만 예약하고 공휴일을 제외했습니다. 이후 시험·보강·변경·폐강 전체 완전성 및 개인 실제 수강은 미확인입니다.'
oldele='9/1~10/19 범위의 공개 예약이며 중간고사 권장기간 이후·개별 실운영·최신 전체 폐강 및 변경은 미확인입니다.'
new='학교 현재 정규 주간 시간표와 현행 주당 강의 배정 규정을 근거로 9/1~10/19 및10/27~12/7의 공개 정규 예약 계획을 제공합니다. 중간고사 권장기간과 지정보강·기말 구간은 보수적으로 제외하며12/7은 게시 종강일이 아닌 지정보강 시작 전 경계입니다. 개별 집중이수 승인·시험·실제 출석·최신 변경·전체 폐강은 미확인입니다.'
proofs=[];archives=[]
for row in c['courses']:
 prior=next(x for x in old['courses'] if x['sourceId']==row['sourceId']);cell=row['sourceEducationCell'];is_bio=row['sourceId'].startswith('ut-document290587-')
 if is_bio:
  rr=cell['row'];cc=cell['column'];text=bg['values'][rr][cc];assert cell['text']==text;clock=bg['values'][rr][28];header=next(m for m in bg['merges'] if m[0]==2 and m[1]==3 and m[2]<=cc<m[3]);day=['월','화','수','목','금'].index(bg['values'][2][header[2]])+1;assert cell['publishedClockText']==clock;expected_old=oldbio
 else:
  cc=cell['nativeColumnIndex'];text=cell['educationalBlockText'];clock=eg['native75ClockColumn'][cell['native75Period']]['exactOriginalClockColumnText'].splitlines()[-1];day=(cc-4)//5+1;assert str(eg['nativeStudyColumnHeader'][cc])==cell['nativeStudyColumn'];expected_old=oldele
 hh=[int(x) for x in re.findall(r'\d+',clock)];start=hh[0]*60+hh[1];end=hh[2]*60+hh[3];assert all(m['weekday']==day and m['startMinute']==start and m['endMinute']==end and m['classroom']==row['sourceClassroom'] for m in prior['schedules'])
 ds=[(datetime.date(2026,10,27)+datetime.timedelta(days=i)).isoformat() for i in range(42) if (datetime.date(2026,10,27)+datetime.timedelta(days=i)).isoweekday()==day];assert ds==late[day]
 assert row['remarks'].count(expected_old)==1
 row['remarks']=row['remarks'].replace(expected_old,new);row['period']=dict(row['period'],endDate='2026-12-07');tmpl=copy.deepcopy(prior['schedules'][0]);added=[]
 for date in ds:
  m=copy.deepcopy(tmpl);m['date']=date;added.append(m)
 row['schedules'].extend(added)
 row['regularPlannedSemesterScope']={'kind':'ordinaryWeeklyPlan','sourceRuleProofSHA256':sha(rule),'excludedMidtermRecommendedRange':['2026-10-20','2026-10-26'],'excludedDesignatedMakeupRange':['2026-12-08','2026-12-14'],'excludedFinalRange':['2026-12-15','2026-12-21'],'endBoundaryDerivedBeforeMakeup':True,'publishedLastClassDateClaim':False,'individualIntensiveApprovalVerified':False,'individualLectureOrExamDateVerified':False,'actualAttendanceClaim':False}
 archives.append({'sourceId':row['sourceId'],'previousWholeResearchRemarks':prior['remarks'],'exactRemovedResearchScopePhrase':expected_old,'exactReplacementResearchScopePhrase':new})
 proofs.append({'sourceId':row['sourceId'],'originalWholeObject':prior,'ownNativePublishedClock':clock,'ownNativeEducationalText':text,'nativeWeekday':day,'expectedStartMinute':start,'expectedEndMinute':end,'originalClassroom':row['sourceClassroom'],'literalAddedDates':ds,'expectedAddedMeetings':added,'priorMeetingPrefixLength':len(prior['schedules']),'nativeEducationalMetadataExactlyPreserved':cell==prior['sourceEducationCell']})
 restored=copy.deepcopy(row);restored['remarks']=prior['remarks'];restored['period']=prior['period'];restored['schedules']=restored['schedules'][:len(prior['schedules'])];restored.pop('regularPlannedSemesterScope');assert restored==prior
c.update(candidateRevision='own-current-ordinary-later-planned-v6',researchOnly=True,productionIntegrationEnabled=False,completionClaim=False,wholeOperatingVerified=False)
assert sum(len(x['schedules']) for x in c['courses'])==761 and sum(len(x['literalAddedDates']) for x in proofs)==366
(b/'ut-unknown-2026-2.current-own-regular-planned-v6.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n');(b/'prior-v4-frozen-61-395-baseline.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');(b/'full-prior-research-note-external-archive.json').write_text(json.dumps(archives,ensure_ascii=False,indent=2)+'\n')
(b/'independent-own-source-clock-and-literal-added-dates-proof.json').write_text(json.dumps({'sourceOnly':True,'completionClaim':False,'beforeDocumentReferences':61,'beforeDates':395,'afterDocumentReferences':61,'afterDates':761,'additionalDates':366,'purePythonValidation':'PASS','sourceInputsSHA256':{'priorV4':sha(priorpath),'bioGrid':sha(bio),'electricalExactClockHeaders':sha(elec),'current2026RuleEducationalProof':sha(rule),'currentCalendar':sha(calendar)},'rulePrintedFactsAndInference':rp['inferenceSeparatedFromPrintedFacts'],'sourceLiteralWeeklyDatesByWeekday':late,'proofs':proofs,'excludedUnresolvedElectricMixedNightExpanded':False,'SDKUsed':False},ensure_ascii=False,indent=2)+'\n')
print(b)
