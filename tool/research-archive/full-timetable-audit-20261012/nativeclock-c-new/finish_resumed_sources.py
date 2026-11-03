import json,pathlib,hashlib,zipfile,xml.etree.ElementTree as E
p=pathlib.Path(__file__).parent;ns={'m':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
asset=json.load(open('assets/timetable/koreatech-unknown-2026-2.json'));by={(c['courseCode'],str(int(c['section']))):c for c in asset['courses']}
def read(fn):
 with zipfile.ZipFile(p/fn) as z:
  ss=[''.join(e.itertext()) for e in E.fromstring(z.read('xl/sharedStrings.xml')).findall('m:si',ns)]
  rows=[]
  for row in E.fromstring(z.read('xl/worksheets/sheet1.xml')).findall('.//m:row',ns):
   vals={}
   for c in row.findall('m:c',ns):
    v=c.find('m:v',ns);s=v.text if v is not None else ''.join(c.itertext());s=ss[int(s)] if c.get('t')=='s' else s
    if s:vals[c.get('r')]=s
   rows.append({'row':int(row.get('r')),'cells':vals})
  return rows
files=[('koreatech-coss-current48.xlsx','https://coss.koreatech.ac.kr/board/29/48'),('koreatech-coss-offerings.xlsx','https://www.tukorea.ac.kr/bbs/semiconductor/1464/50093/download.do')]
entries=[]
for fn,u in files:
 rows=read(fn);(p/(fn+'.rows.json')).write_text(json.dumps(rows,ensure_ascii=False,indent=2))
 for r in rows:
  n=r['row'];v=r['cells'];code=v.get(f'E{n}');sec=v.get(f'I{n}');school=v.get(f'C{n}')
  if not code or not sec or school!='한기대':continue
  old=by.get((code,sec));entries.append({'sourceUrl':u,'sourceFile':fn,'sheet':'sheet1','row':n,'courseCode':code,'section':sec,'courseName':v.get(f'D{n}'),'sourceMethod':v.get(f'G{n}'),'sourceSchedule':v.get(f'J{n}'),'professor':v.get(f'H{n}'),'remarks':v.get(f'K{n}'),'existingSourceId':old.get('sourceId') if old else None,'existingNativeSchedule':old.get('sourceSchedule') if old else None,'absoluteClockProvided':False,'integrationReady':False,'sourceStatus':'온라인' if v.get(f'G{n}')=='온라인' else 'offline native ordinals only','holdReason':'절대시각 없음; 현재 최종 아우누리 강의내용과 일정충돌 시 현재 원자료 보존. 원문 기준일7/16, 본문8/7 수정의 시간표개별 최신성 명시불가.'})
(p/'koreatech-current-coss-operating-evidence.json').write_text(json.dumps({'final':True,'universityId':'koreatech','academicYear':2026,'semester':'2','entries':entries,'wholeSchoolClockProvided':False,'allCoursesClaim':False},ensure_ascii=False,indent=2))
receipt=json.load(open(p/'receipt.json'))
for fn,u in files+[('koreatech-coss-exchange.pdf','https://www.tukorea.ac.kr/bbs/semiconductor/1464/50092/download.do'),('koreatech-coss29.html','https://coss.koreatech.ac.kr/board/article/29'),('koreatech-coss-index.html','https://coss.koreatech.ac.kr/')]:
 b=(p/fn).read_bytes();receipt.append({'file':fn,'url':u,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest(),'request':'normal unauthenticated GET','status':200})
receipt.append({'url':'https://home.sch.ac.kr/_custom/sch/_common/board/download.jsp?attach_no=20260727154754706066','request':'normal unauthenticated GET','status':403,'stopped':True,'noAlternateRequest':True})
(p/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2))
ledger=json.load(open(p/'route-ledger.json'));ledger['resumed']=True
ledger['universities'][0]['newCheckedSources'] += ['https://home.sch.ac.kr/advanced/05/02.jsp?article_no=20260727154754694077&mode=view','https://home.sch.ac.kr/_custom/sch/_common/board/download.jsp?attach_no=20260727154754706066']
ledger['universities'][0]['resumedResult']='7/27 SCH학사팀 백석2026-2교류: 전체강좌 조회는 기존BU홈페이지시간표를 가리킴. 첨부정상GET403으로 중단; 다른host/헤더/우회 요청안함.'
ledger['universities'][1]['newCheckedSources'] += [u for fn,u in files]+['https://coss.koreatech.ac.kr/board/article/29','https://www.tukorea.ac.kr/bbs/semiconductor/1464/152025/artclView.do','https://www.tukorea.ac.kr/bbs/semiconductor/1464/50092/download.do']
ledger['universities'][1]['resumedResult']='COSS대학자체공식8/7수정공지+7/16기준XLSX, 타교hostedKoreaTech발행교류PDF/XLSX 확보. 실제학부code/section/method/nativeordinals, 절대시각0. COS044/045/046 online 명시, COS101 수2,3,4 (existing0), COS041 source WE-Meet vs existingCOS042차이, 발행자료본학기9/1–12/18은학교전체기간으로확대금지. 각원문행보존.'
ledger['universities'][2]['resumedSearches']=['청주교육대학교 수업09:00~09:50','청주교육대학교 학사안내교시','청주교육대학교2026교시학부']
ledger['universities'][2]['resumedResult']='학교ERI CITEF2026프로그램 시각검색결과는학술대회clock라 제외(https://eri.cje.ac.kr/site/www/images/contents/CITEF2026_Program_kor.pdf); actualoriginaldownload안함. 학사지침검색은단국대편입생안내/교원대교류에청주교대명등장일뿐 CJEclock아님. 신규CJEcurrent학부clock0, 공개경로부존재증거아님.'
(p/'route-ledger.json').write_text(json.dumps(ledger,ensure_ascii=False,indent=2))
with (p/'HANDOFF.md').open('a') as f:f.write('''\n## 재개 후 추가 조사\n\n한국기술교육대 COSS 자체공식2026-2 8/7수정공지article29와 첨부/board/29/48(시트기준일7/16), TUK호스팅KoreaTech발행교류자료50092PDF/50093XLSX 추가확보. 모든실제원행을xlsx.rows.json에 보존. 원791와nativecode+section대조한 `koreatech-current-coss-operating-evidence.json`은 operating evidence만, clock 및 통합ready가 아니다. 공통HH없음. COS044/045/046온라인 명시; COS101신규 native水2,3,4 vs현재0;WE-Meet한sourceCOS041 vs현재COS042 차이최종데이터판단보류. 교류PDF기간9/1–12/18은사업단교류범위이므로학교전체기존기간덮어쓰기금지.\n\n백석현재학기SCH학사팀교류공지20260727154754694077은 기존BU전체시간표조회방식 안내, 첨부20260727154754706066은정상GET403. 즉시중단했으며 우회안함. 청주교대새검색은학술대회/CITEF/타교학사지침만대상밖 시각자료, 현재CJE학부clock 원문새확보0. 기존 실패문서·images전면재검토반복안함. 새 일반clock확보0이므로 미예약mass활성화금지.\n\n파일: receipt.json(성공원문8/403거절1), route-ledger.json(학교별구체새경로/이유/다음근거), 2XLSX.rows.json, nativecourse운영evidencepacket. 추정시각·대학원시각·청강일시로공통grid구성하지않음.\n''')
print('saved resumed source-only handoff',len(entries),'scoped rows')
