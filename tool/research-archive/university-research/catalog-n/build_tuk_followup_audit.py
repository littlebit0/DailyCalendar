# coding: utf-8
"""Compose evidence handoff; current whole coverage deliberately remains false."""
import json
from pathlib import Path
P = Path(__file__).resolve().parent
remote = json.loads((P/'tuk-remote-delivery-current-candidates.json').read_text())
base = 'https://www.tukorea.ac.kr'
result = {
 'researchOnly':True, 'completionClaim':False, 'productionReady':False,
 'captureDate':'2026-10-07',
 'ordinaryAndFusion': {
  'publishedSourceDate':'2026-07-15', 'sourceRows':2242,
  'currentPublicClosedKeys':36, 'closedKeysExcludedFromSnapshot':35,
  'closedKeyAbsentFromJuly':['ASE30009','51'], 'remainingUnique':1431,
  'countsWithinSnapshot':{'scheduled':1349,'unrecognized':65,'unscheduled':17},
  'candidateFile':'tuk-research-safe-snapshot-candidates.json',
  'scopeBlocks':['Whole current offering and clock/room publication missing',
                'Actual whole-campus assignment incomplete',
                'Separate company curricula offering identities missing'],
  'cannotRepresentAllGapsAsOnlyIndividual38':True,
 },
 'latestComputerPublication': {
  'noticeUrl':base+'/bbs/ce/201/152619/artclView.do?layout=unknown',
  'publicationDate':'2026-08-27',
  'downloadUrl':base+'/bbs/ce/201/50552/download.do',
  'status':200,'pdfBytes':68666,'pages':1,
  'actualHeader':'2026-2학기 컴퓨터공학부 강의시간표',
  'actualSchema':'weekday/grade/CE-SW A-B grid, course/instructor/room',
  'missingFields':['courseCode','actualNumericSection','credits','classification'],
  'normalParserRejection':'Wrong TUK year/term or ambiguous PDF table',
  'reason':'Different grid, not complete15-column offering table; no forced name-to-code merge',
 },
 'officialLatestConfirmation': {
  'sourceUrl':base+'/bbs/ce/201/152619/artclView.do?layout=unknown',
  'actualPublishedQuote':'장소나 시간의 변경이 있을 수 있으니 개강 직전 필히 통합정보시스템에서 확인 바랍니다.',
  'actualPublishedPath':'통합정보시스템 - 학사행정 - 교과수업 - 강의시간표관리 - 시간표출력 (학과별/과목별)',
  'actualPublishedLink':'https://ksc.tukorea.ac.kr/sso/login_stand.jsp',
  'explicitCompanyLoginSource':'https://contract.tukorea.ac.kr/bbs/contract/607/49880/download.do',
  'explicitCompanyLoginQuote':'과목별 교수님 및 강의실 정보는 [통합정보시스템]에 로그인하여 [수강신청 내역] 또는 [시간표]에서 확인.',
  'limit':'Specific latest confirmation and individual professor/room route requires login. Not a claim every school datum is inaccessible; login not attempted.',
 },
 'companyCollege': {
  'publicPdfCount':8, 'requestEvidence':'tuk-company-attachment-requests.json',
  'publishedFields':['courseName','weekdayGrid','clock','perDayCampus'],
  'missingFields':['offeringCode','section','credits','classification','individualProfessor','currentRoom'],
  'officialSeparateCurriculumEvidence':'currentguide printed34',
  'notSyntheticOrJoinedByName':True,
 },
 'industryFusionDepartment': {
  'noticeUrl':base+'/bbs/ic/625/152521/artclView.do?layout=unknown',
  'downloadUrl':base+'/bbs/ic/625/50743/download.do',
  'currentRows':15, 'actualClockCreditsClassificationRoomPublished':True,
  'missingFields':['offeringCode','section'], 'syntheticIds':False,
 },
 'newDeliveryGaps': {
  'remote26':{
   'actualSourceField':'수업진행구분 원격중심',
   'courseKeys':[[r['courseCode'],r['section']] for r in remote['rows']],
   'blockingReason':'Remote-centered does not specify synchronous/asynchronous or attendance weeks',
  },
  'blended1': {
   'courseCode':'AFT21002','section':'51',
   'sourceUrl':base+'/bbs/ce/201/49831/download.do',
   'pdfPage':29,'printedPage':26,'visualVerified':True,
   'actualSeparateCell':'블렌디드 수업 (이론수업 동영상)',
   'actualClocks':'월7~8 15:30~17:20 / 토13~14 20:50~22:30',
   'blockingReason':'Which session is theory-video versus onsite is not published',
   'notPropagatedToAFT31001':'Its separate remark is SW대학 소속 신청 불가',
  },
  'zoom1': {
   'courseCode':'AFT21004','section':'51',
   'pdfPage':29,'printedPage':26,'visualVerified':True,
   'actualMergedCell':'실리콘밸리 전문가 특강 줌으로 진행',
   'cellOnlySpans':['AFT21003','AFT21004'], 'perMeetingDeliveryMode':'liveOnline',
  },
 },
 'campusEvidence': {
  'officialMapUrl':'https://tukorea.ac.kr/sites/contract/contents/files/2026_contract.pdf',
  'pdfPage':2,'visualVerified':True,
  'firstCampusBuildingLegend':['기술혁신파크(TIP생활관)','중앙도서관',
   '공학관A동','공학관B동','공학관C동','공학관D동','공학관E동','공학관G동','공학관P동',
   '산학융합본부','시흥비즈니스센터','체육관'],
  'limit':'Legend improves actual building evidence, not proof main means first-campus for every offering. 교수연구실 has no physical building. Eight company PDFs separately state1캠/2캠 byday.',
 },
 'termEvidence': {
  'sourceUrl':base+'/bbs/ce/201/49831/download.do',
  'actualStart':'2026-09-01', 'finalExams':['2026-12-08','2026-12-21'],
  'makeupWeek':['2026-12-15','2026-12-22'], 'winterVacationStarts':'2026-12-23',
  'explicitTermEnd':'2026-12-22, explicit 종강일 in militaryleave restriction',
  'limit':'Original term/exam/makeup markers preserved; no invented specific makeup or field attendance.',
 },
 'closureLiveRecheck':'tuk-current-closure-crosscheck.json',
 'noProductionChange':True,
}
(P/'tuk-followup-current-scope-operation-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
print('followup audit saved')
