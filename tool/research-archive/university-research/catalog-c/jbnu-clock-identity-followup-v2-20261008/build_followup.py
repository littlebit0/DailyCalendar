"""Read existing education-only source snapshots; emit no product mutations."""
import json, hashlib, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
BASE=OUT.parent/'jbnu-current-20261008'
def dump(name,data):
 (OUT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def norm(s):return ''.join(c for c in s if c.isalnum()).casefold()
sources=sorted(BASE.glob('current-public-type*-education.json'))
rows=[r for p in sources for r in json.loads(p.read_text())['rows']]
assert len(rows)==3571
receipt=json.loads((BASE/'medical-document-educational-receipt.json').read_text())
comparison=[]
for sheet in receipt['sourceSheets']:
 for subject in sheet['subjects']:
  matches=[r for r in rows if r['YRSA']=='2026' and r['ELSM_DIVCDNM']=='학부' and r['MNG_SCSBJT_CDNM']=='의학과' and norm(r['SBJCT_NM'])==norm(subject['courseName'])]
  assert len(matches)==1
  row=matches[0]
  checks={'uniqueCurrentMedicalTitleCandidate':True,'creditsEqual':subject['credits']==row['ESTBL_PNT'],'gradeEqual':row['SCSBJT_SCYR_NTC_CN']==f"의 {sheet['grade']}",'professorEqual':subject['professor']==row['STAFFNM']}
  comparison.append({'documentLocator':{'document':'357005','sheet':sheet['sheet'],'summaryRow':subject['row']},'documentSubject':subject,'currentNativeCandidate':row,'checks':checks,'decision':'corroboratedMultiFieldCandidateNoOfficialPrintedJoin' if all(checks.values()) else 'holdProfessorConflictNoMerge','officialIdentityPrintedInDatedDocument':False,'officialSectionPrintedInDatedDocument':False,'productMutation':False})
assert len(comparison)==33
assert sum(x['checks']['professorEqual'] for x in comparison)==31
assert all(x['checks']['creditsEqual'] and x['checks']['gradeEqual'] for x in comparison)
dump('medical-native-identity-comparison.json',{'completionClaim':False,'permanentlyImpossible':False,'currentYear':2026,'currentSemester':2,'wholeNativeRows':3571,'datedDocumentSubjects':33,'uniqueTitleDepartmentYearCandidates':33,'gradeCreditsProfessorCorroboratedCandidates':31,'professorConflictCandidates':2,'officialPrintedDocumentNativeJoins':0,'newScheduledCourses':0,'newAppointments':0,'priorMedicalPreserved':{'objects':33,'scheduledCourses':18,'appointments':1098},'policy':'Do not title-only merge, inflate 3571+33 as unique offerings, copy native identity into unpublished document columns, or silently replace professor/room/period. This is a comparison receipt, not an identity rewrite. Document locator is internal. Current source rooms corroborate campus only for native rows, not an authorized rewrite of dated document unknown campus.','rows':comparison})
remote=[]
for title,prof,day in [('기초전자기학','송민호','수'),('반도체테스트알고리즘','이종열','화'),('마이크로프로세서응용및PCB설계','이종열','목')]:
 rr=[r for r in rows if r['SBJCT_NM']==title and r['DVCLS_NO']==1 and r['STAFFNM']==prof and r['MNG_SCSBJT_CDNM']=='반도체 소재/부품/장비']
 assert len(rr)==1
 remote.append({'printedTitle':title,'printedSection':'1','printedProfessor':prof,'printedPeriod':f'{day} 11,12,13교시','printedDelivery':'동영상 강의, 대면 시험','printedCredits':3,'printedClassification':'전공선택','printedEligibilityClassification':'융합전공 참여학생 전선, 그 외 일선','currentNativeCorroboration':rr[0],'officialCodePrintedInNotice':False,'regularLiveAppointmentEligible':False,'examExactDateTimeRoomPublished':False})
dump('current-recorded-operation-education.json',{'sourceUrl':'https://jsec.jbnu.ac.kr/bbs/jsec/4953/396175/artclView.do','publishedDate':'2026-07-14','title':'[반도체 소재/부품/장비] 2026학년도 2학기 개설교과목 및 수강신청 안내','educationalStatement':'전북대학교 LMS에서 동영상강의 수강','rows':remote,'decision':'Native 11–13 period is not proven synchronous attendance. Keep recorded delivery and undated physical exam evidence; do not create live weekly or invented exam reservations.','completionClaim':False})
dump('current-clock-and-term-education.json',{'completionClaim':False,'permanentlyImpossible':False,'newEligibleGeneralClockProof':0,'sources':[{'noticeUrl':'https://cte.jbnu.ac.kr/bbs/cte/530/396237/artclView.do','attachmentUrl':'https://cte.jbnu.ac.kr/bbs/cte/530/355494/download.do','attachmentSha256':sha(Path('/private/tmp/jbnu-cte-current-timetable.pdf')),'title':'(공지용)2026학년도 2학기 시간표(수정).pdf','page':1,'sourceStatement':'10교시는 18시 부터 시작','scope':'Current 2026-2 IT융합기전공학 undergraduate and separately marked graduate timetable; the printed statement is by nonpublic individually registered subsection.','proven':{'nativePeriod':10,'startTime':'18:00'},'unproven':['endTime','0A/0B','A/B numeric slot ends','75minute clock','central all-undergraduate applicability'],'generalClockExtensionAllowed':False},{'noticeUrl':'https://www.jbnu.ac.kr/web/Board/216731/detailView.do','attachmentTitle':'3. 전북대학교 국가근로 FAQ(학업시간표 추가 입력 정정).pdf','attachmentSha256':sha(Path('/private/tmp/jbnu-current-academic-clock-faq.pdf')),'pages':[2,3],'educationOnlyParaphrase':'실시간 강좌는 해당 시간 수강; 콘텐츠 강좌는 기간 내 자유 수강. 공식적인 시간표는 JUMP에서 확인. Numeric period clock is absent. Work schedules and personal fields are excluded.','numericClockPublished':False},{'noticeUrl':'https://www.kongju.ac.kr/bbs/KNU/2132/429256/artclView.do','attachmentUrl':'https://www.kongju.ac.kr/bbs/KNU/2132/654625/download.do','attachmentTitle':'2026학년도 2학기 전북대학교 수학안내.hwp','attachmentSha256':sha(Path('/private/tmp/jbnu-exchange-current.hwp')),'issuer':'전북대학교, published by official exchange partner Kongju','nativeEducationStatements':['수업기간: 2026. 9. 1.(화) ~ 12. 22.(화)','공휴일 및 행사기간의 수업 결손일은 수업기간 내 보강'],'numericClockPublished':False,'doNotInfer':['individual makeup dates','individual attendance','unprinted examination dates']},{'noticeUrl':'https://stat.jbnu.ac.kr/bbs/stat/834/396264/artclView.do','attachmentUrl':'https://stat.jbnu.ac.kr/bbs/stat/834/355176/download.do','attachmentTitle':'2026학년도 2학기 수강편람_(영문ver.).pdf','attachmentSha256':sha(Path('/private/tmp/jbnu-current-english-handbook.pdf')),'numericClockPublished':False,'scope':'English current guide checked for class time and 50/75 minute numeric clock. No applicable numeric mapping found.'}], 'excludedAsGeneralClockProof':['2012 handbook','2026-1 freshman starts','2026-2 business graduate 11A/B mapping','2026 summer employment course blocks','2026 summer schoolteacher training','other-university clock on JBNU-hosted exchange guide']})
dump('verification.json',{'kind':'readOnlySourceComparison','assertionsPassed':['3571 current native rows','33 unique year/UG/medical/title candidates','33 equal grade and credits','31 equal professor','2 professor conflicts retained','3 current explicit recorded operations','no title-only or native-code rewrite','zero new schedules'],'sdkUsed':False,'productEdited':False,'historicalFrozenEdited':False,'newScheduledCourses':0,'newAppointments':0,'completionClaim':False})
inputs=sources+[BASE/'medical-document-educational-receipt.json',BASE/'jbnu-unknown-medical-document-2026-2.published-partial-20261008.json']
dump('input-sha256.json',{str(p.relative_to(ROOT)):sha(p) for p in inputs})
print('assertions PASS: 3571 whole;33 candidates;31 multi-field;2 professor conflicts;3 recorded;0 new scheduled')
