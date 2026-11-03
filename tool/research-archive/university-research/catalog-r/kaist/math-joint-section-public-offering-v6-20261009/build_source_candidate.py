from pathlib import Path
import json,hashlib,copy,datetime
P=Path(__file__).parent
V5=P.parent/'math-current-public-offering-v5-20261009'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
save=lambda n,d:(P/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
prior=json.loads((V5/'kaist-main-2026-2.math-single-ug-planned-v5.json').read_text());save('prior-full-36-course-v5-baseline.json',prior)
joint=json.loads((V5/'joint-section-full-operating-followup-proof.json').read_text());cal=json.loads((V5/'reused-own-current-calendar-proof.json').read_text());save('reused-own-current-calendar-proof.json',cal)
# Exact source English professor cells manually transcribed from p2. Titles preserved in full frozen text, group proof and raw native rows.
eng={'101AB':'Ngoc Cuong NGUYEN','102AB':'Yong Jung KIM','102MN':'Gang Uk HWANG','102KL':'Mikyoung LIM','102CD':'Donghan KIM','102EF':'Wansu KIM','102IJ':'Sanghoon BAEK','102GH':'Jiewon PARK','109CD':'Minju LEE','109AB':'Jinhyun PARK','109EF':'Sang Geun HAHN','110AB':'Wooseok HA','201AB':'Donghwan KIM','201CD':'Jaeho HAAN','202AB':'Kyeongsik NAM'}
text=(V5/'actual-timetable-text.txt').read_text();out=copy.deepcopy(prior); out['researchRevision']='math-joint-source-only-v6'
proof={'sourcePDFSHA256':joint['sourcePDFSHA256'],'priorCandidateSHA256':sha(V5/'kaist-main-2026-2.math-single-ug-planned-v5.json'),'sourceV5ManifestSHA256':sha(V5/'SHA256SUMS'),'completeBilingualSourceText':text,'sourceWholeOperatingGroups':joint,'candidateScope':'30 published individual sections with known unconflicted own lectureHH;26 also knownFridayrecitationHH11dates;109EFpractice omission conflict held explicitly;202AB no recitation published, no none-ever claim','wholeUniversityClaim':False,'originalInputFolder':str(V5),'ownMainCalendarSHA256':sha(V5/'reused-own-current-calendar-proof.json'),'perSectionRows':[]}
mins=lambda h:sum(int(v)*k for v,k in zip(h.split(':'),(60,1)))
for g in joint['rows']:
 if g['lectureConflict']:continue
 for j,section in enumerate(g['sourceSpecificSectionLetters']):
  orig=copy.deepcopy(g);orig['nativeIndividualSection']=section;orig['nativeProfessorEN']=eng[g['nativeCode']+g['nativeSectionGroup']]
  orig['nativeWholeLectureCellsKRandEN']=[line for line in text.splitlines() if (g['nativeCode']+g['nativeSectionGroup']+' ') in line]
  ss=[];day=datetime.date(2026,8,31)
  while day<=datetime.date(2026,12,13):
   ds=day.isoformat();weekday=day.isoweekday()
   if weekday in ([1,3] if g['nativeDayPair']=='MW' else [2,4]) and ds not in cal['holidayExclusion'] and not '2026-10-19'<=ds<='2026-10-23':
    ss.append({'weekday':weekday,'startMinute':mins(g['lectureStart']),'endMinute':mins(g['lectureEnd']),'classroom':g['nativeClassroomKR'],'date':ds})
   day+=datetime.timedelta(days=1)
  includepractice=not g['practiceConflict'] and not g['noPracticePublished']
  if includepractice:
   a,b=('firstPracticeStart','firstPracticeEnd') if j==0 else ('secondPracticeStart','secondPracticeEnd')
   for ds in joint['ordinaryFridayPracticeDates']:ss.append({'weekday':5,'startMinute':mins(g[a]),'endMinute':mins(g[b]),'classroom':'','date':ds})
  ss.sort(key=lambda s:(s['date'],s['startMinute']))
  remarks='원문 공동강의 그룹 '+g['nativeCode']+g['nativeSectionGroup']+' 및 실제 분반 '+section+' 보존. 금요일 연습반은 원문 시각만 반영, 강의실·교수 미공개여서 빈 값 유지. 9/18 학생대제전 연습반휴강 제외. 전체 공식 과목코드·학점·이수구분·실제출석·폐강·시험·보강 미확인.'
  if g['practiceConflict']:remarks+=' 109E/F 연습반은 한글ACE/BDF와 영문AC/BD의 표기 충돌로 시간표 생성 보류; 원문 모두 보존.'
  if g['noPracticePublished']:remarks+=' 202AB 별도 연습반은 이 원문에 미표시; 모든 운영에 없다고 주장하지 않음.'
  c={'sourceId':f'kaist/main/2026-2/math-185_2/{g["nativeCode"]}/{section}','campus':'main','academicYear':2026,'semester':'2','courseCode':g['nativeCode'],'courseName':g['nativeTitleKR'],'section':section,'professor':g['nativeProfessorKR'],'classification':'','credits':None,'departmentCredits':{},'departments':['수리과학과'],'departmentClassifications':{},'sourceSchedule':f'{g["nativeCode"]}{g["nativeSectionGroup"]} {g["nativeDayPair"]} {g["lectureStart"]}~{g["lectureEnd"]}'+(f' / Friday {g[a]}~{g[b]} 연습반' if includepractice else ''),'sourceClassroom':g['nativeClassroomKR'],'scheduleStatus':'scheduled','schedules':ss,'period':{'startDate':'2026-08-31','endDate':'2026-12-18'},'remarks':remarks,'metadata':{'researchOnly':False,'completionClaim':False,'sourceUrl':'https://mathsci.kaist.ac.kr/ko/education/tt_files/185_2.pdf','publishedDate':'2026-09-30','sourceUpdatedDate':'2026-10-01','sourcePDFSHA256':joint['sourcePDFSHA256'],'sourceIdKind':'Internal native-short-code/actualindividualsection locator; no official completeID claim','originalEducationalFields':orig,'nativeShortCodePublished':True,'fullOfficialOfferingCodeUnverified':True,'nativeUGLabels':['학부','Under-graduate'],'actualAttendanceConfirmed':False,'currentActiveStatusVerified':False,'deliveryModeStatus':'unknown-user-choice','practiceOperatingStatus':'bilingual-conflict-held' if g['practiceConflict'] else ('unpublished' if g['noPracticePublished'] else 'published-clock-room-professor-unknown'),'partialOperatingComponentsHeld':bool(g['practiceConflict']),'practiceTeacherUnpublished':True,'practiceRoomUnpublished':True,'practiceRoomNotBorrowedFromLecture':True,'practiceClosureDate':'2026-09-18','ownCalendarSHA256':proof['ownMainCalendarSHA256'],'campusEvidence':'Same current mathmenu Daejeon291footer, v5frozen original; source Korean buildingname+English ownbuildingcode preserve','regularReservationEndDerivedFromNextFinalStart':True}}
  out['courses'].append(c);proof['perSectionRows'].append({'code':g['nativeCode'],'section':section,'sourceGroup':g['nativeSectionGroup'],'lectureCount':27,'practiceCount':11 if includepractice else 0,'heldPracticeConflict':bool(g['practiceConflict'])})
assert out['courses'][:36]==prior['courses']; assert len(out['courses'])==66
added=sum(len(c['schedules']) for c in out['courses'][36:]);assert added==1096
assert sum(len(c['schedules']) for c in out['courses'])==2036
save('kaist-main-2026-2.math-joint-ug-planned-v6.json',out);save('joint-native-whole-operating-proof.json',proof)
# Independent literal-date crosscheck, not builder day-loop.
mw='2026-08-31 2026-09-02 2026-09-07 2026-09-09 2026-09-14 2026-09-16 2026-09-21 2026-09-23 2026-09-28 2026-09-30 2026-10-07 2026-10-12 2026-10-14 2026-10-26 2026-10-28 2026-11-02 2026-11-04 2026-11-09 2026-11-11 2026-11-16 2026-11-18 2026-11-23 2026-11-25 2026-11-30 2026-12-02 2026-12-07 2026-12-09'.split()
tt='2026-09-01 2026-09-03 2026-09-08 2026-09-10 2026-09-15 2026-09-17 2026-09-22 2026-09-29 2026-10-01 2026-10-06 2026-10-08 2026-10-13 2026-10-15 2026-10-27 2026-10-29 2026-11-03 2026-11-05 2026-11-10 2026-11-12 2026-11-17 2026-11-19 2026-11-24 2026-11-26 2026-12-01 2026-12-03 2026-12-08 2026-12-10'.split()
fr='2026-09-04 2026-09-11 2026-10-02 2026-10-16 2026-10-30 2026-11-06 2026-11-13 2026-11-20 2026-11-27 2026-12-04 2026-12-11'.split()
for c in out['courses'][36:]:
 o=c['metadata']['originalEducationalFields']; assert [s['date'] for s in c['schedules'] if s['weekday']!=5]==(mw if o['nativeDayPair']=='MW' else tt)
 practice=[s for s in c['schedules'] if s['weekday']==5]
 if c['metadata']['practiceOperatingStatus']=='published-clock-room-professor-unknown':assert [s['date'] for s in practice]==fr;assert all(s['classroom']=='' for s in practice)
 else:assert not practice
save('independent-python-validation.json',{'result':'PASS','prior36WholeObjectsPreserved':True,'added30Sections':True,'addedLectureReservations':810,'addedPracticeReservations':286,'addedTotalReservations':1096,'totalCourses':66,'totalReservations':2036,'noPracticeOnOwnClosureSep18':True,'SDKExecuted':False,'wholeUniversitySupportClaim':False})
