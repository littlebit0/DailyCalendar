# coding: utf-8
"""Selected official educational evidence from the scoped current-source pass."""
from pathlib import Path
import json
P=Path(__file__).parent
A={
 'checkedAt':'2026-10-08','productionReady':False,'completionClaim':False,
 'wholeNotRefetched':True,'loginOrPrivateAccountsUsed':False,
 'modeScope':{'explicitLive3':'kunsan-explicit-live-mode-audit-20261008.json','genericRemoteMixed43Unresolved':True},
 'JST136':{
  'sourceSheet':'kunsan-2026-2-attachment-5-rows.json/JST공유대학',
  'currentOfficialSource':'https://www.jst.ac.kr/ko/jst/news/view/2159',
  'publishedDate':'2026-08-28','currentSemesterStart':'2026-09-01',
  'sourceMeaning':'Current opening notice requires checking each plan for in-person practical dates. General video-attendance notice does not prove every actual JST course is untimed VOD.',
  'publishedAcademicLanding':'https://haksa.jst.ac.kr/',
  'postedNormalStart':'/JST/index.html','postedApp':'/JST/JST.xadl.js',
  'postedLoginForm':'Frame::Login.xfdl','formAlias':'./Frame/',
  'observedCompiledLogin':'https://haksa.jst.ac.kr/JST/Frame/Login.xfdl.js',
  'visibleCaptions':['LOGIN','SAVE ID','Forgot your Password?','------ 학교 선택 ----'],
  'anonymousCourseQueryLinkFound':False,'actualNormalPathRequiresLogin':True,
  'limits':'Observed official public boot/login only; not proof every public JST route is impossible. No private menu/data transaction tried, no login values/SSO/auth/bootstrap material stored.'},
 'clock':{
  'currentUndergraduateSource':'https://www.kunsan.ac.kr/index.kunsan?menuCd=DOM_000000103003000000&sso=ok',
  'actualUpdated':'2026-02-09','currentPostedOrdinaryRange':'period1-10 09:10-19:00',
  'circled521MappingStillUnverified':True,'numeric11PlusCurrentUGMappingStillUnverified':True,
  'rejectedScopeTransfer':[
   {'url':'https://www.kunsan.ac.kr/teaching/board/view.kunsan?boardId=BBS_0000220&dataSid=1363779&menuCd=DOM_000006705001000000','reason':'2026-1 graduate timetable, not2026-2 undergraduate exact clock proof.'},
   {'url':'https://www.kunsan.ac.kr/upload_data/board_data/CNT_ATCHDOWN/169042036601610.pdf','reason':'2023-2 graduate guide contains11-13 clock but wrongyear/degree; no current UG extrapolation.'}]},
 'latestClosure':{
  'publicTargetedSearches':['2026학년도2학기 폐강교과목','2026 9월 강의실변경','2026학년도2학기 최종시간표','2026 집중강의 스키'],
  'observations':'Only enrollment instructions, summer-seasonal closure or unrelated current notices appeared; no verified current regular final closure/room list in these results.',
  'notEvidenceImpossible':True,'existingBroaderScopeAudit':'kunsan-current-support-pending-audit-20261008.json',
  'packageSourceWarnsCurrentIntegratedSystemMustBeChecked':True},
 'next':'Published current UG circled/late legend or individually exact clock/attendance instructions; latest authenticated-system-only scope is separately unverified. Keep all metadata searchable without fabricated times.'}
if __name__=='__main__':
 (P/'kunsan-current-narrow-followup-20261008.json').write_text(json.dumps(A,ensure_ascii=False,indent=2)+'\n')
