import pathlib,re,json,zipfile,xml.etree.ElementTree as E,hashlib
p=pathlib.Path(__file__).parent
urls={
'ulsan-biology.html':'https://biology.ulsan.ac.kr/biology/1424?action=view&no=279963',
'ulsan-ie.html':'https://ie.ulsan.ac.kr/ie/893?action=view&no=279687',
'ulsan-nutri.html':'https://nutri.ulsan.ac.kr/nutri/1537?action=view&no=280507',
'ulsan-ie-guide.pdf':'https://ie.ulsan.ac.kr/boardDownload.do?no=344243',
'ulsan-robot-course.html':'https://ie.ulsan.ac.kr/ie/893?action=view&no=279733',
'ulsan-robot-plan.hwp':'https://ie.ulsan.ac.kr/boardDownload.do?no=344276',
'ulsan-robot-summary.hwp':'https://ie.ulsan.ac.kr/boardDownload.do?no=344275',
'ulsan-robot-poster.jpg':'https://ncms.ulsan.ac.kr/upload/256/images/000009/20260721144046474_GFAGRGEO.jpg',
'ulsan-intelligent-robot.html':'https://ie.ulsan.ac.kr/ie/893?action=view&no=279734',
'ulsan-intelligent-plan.hwp':'https://ie.ulsan.ac.kr/boardDownload.do?no=344280',
'ulsan-intelligent-poster.jpg':'https://ncms.ulsan.ac.kr/upload/256/images/000009/20260721144321366_B3S31XWQ.jpg',
'ut-electronic.html':'https://www.ut.ac.kr/cop/bbs/BBSMSTR_000000001188/selectBoardArticle.do?bbsId=BBSMSTR_000000001188&nttId=1122314',
'ut-electronic-planned.xlsx':'https://www.ut.ac.kr/cmm/fms/FileDown.do?atchFileId=FILE_000000000289197&fileSn=2',
'ut-electronic-list.html':'https://www.ut.ac.kr/cop/bbs/BBSMSTR_000000001188/selectBoardList.do',
'ut-electronic-july.html':'https://www.ut.ac.kr/cop/bbs/BBSMSTR_000000001188/selectBoardArticle.do?bbsId=BBSMSTR_000000001188&nttId=1123480',
'ut-chemical-list.html':'https://www.ut.ac.kr/cop/bbs/BBSMSTR_000000000277/selectBoardList.do',
'ut-ce.html':'https://aicc.ut.ac.kr/ce.do',
'ut-ce-timetables.html':'https://aicc.ut.ac.kr/cop/bbs/BBSMSTR_000000000350/selectBoardList.do',
'ut-nursing-guide-notice.html':'https://www.ut.ac.kr/cop/bbs/BBSMSTR_000000000592/selectBoardArticle.do?nttId=1122507',
'ut-nursing-2026-2-guide.pdf':'https://www.ut.ac.kr/cmm/fms/FileDown.do?atchFileId=FILE_000000000289456&fileSn=0',
'nsu-nursing-main.html':'https://nursing.nsu.ac.kr/',
'nsu-department-js.html':'https://nursing.nsu.ac.kr/res/service/lib/department1.js?V=0055',
'unist-yclee.html':'https://sites.google.com/view/yclee/'}
receipt=[{'file':n,'sourceUrl':u,'bytes':(p/n).stat().st_size,'sha256':hashlib.sha256((p/n).read_bytes()).hexdigest()}for n,u in urls.items()]
(p/'receipt.json').write_text(json.dumps({'acquiredDate':'2026-10-12','sources':receipt},ensure_ascii=False,indent=2)+'\n')
z=zipfile.ZipFile(p/'ut-electronic-planned.xlsx');ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'};ss=[''.join(x.itertext())for x in E.fromstring(z.read('xl/sharedStrings.xml')).findall('s:si',ns)]
rows=[];grade=None
for row in E.fromstring(z.read('xl/worksheets/sheet1.xml')).findall('.//s:row',ns):
 cells={}
 for c in row.findall('s:c',ns):
  v=c.find('s:v',ns)
  if v is not None:cells[c.attrib['r']]=ss[int(v.text)]if c.attrib.get('t')=='s'else v.text
 r=int(row.attrib['r'])
 if r<4:continue
 if 'A'+str(r)in cells:grade=cells['A'+str(r)]
 if 'D'+str(r)not in cells:continue
 rows.append({'university':'ut','sourceId':f'ut-electronics-1122314-FILE289197-2-sheet1-row{r}','sourceLocator':f'worksheet1!D{r}','title':cells['D'+str(r)],'department':'전자공학과','sourceGrade':grade,'nativeClassification':cells.get('C'+str(r)),'credits':float(cells['E'+str(r)]),'theoryHours':cells.get('F'+str(r)),'practicalHours':cells.get('G'+str(r)),'nativeTrack':cells.get('K'+str(r)),'sourceYear':2026,'sourceSemester':2,'code':None,'section':None,'schedules':[],'scheduleStatus':'held','sourceUrl':urls['ut-electronic-planned.xlsx'],'reason':'공식 문서 명시 개설예정. 실제 코드/분반/교수/요일/시각 없음; 학과 공지에도 3·4학년 트랙 교과목 변경 가능. 시수는 절대 수업시각이 아님.'})
(p/'ut-electronics-planned-held.json').write_text(json.dumps({'final':True,'integrationEligible':False,'scope':'planned catalog only','rows':rows},ensure_ascii=False,indent=2)+'\n')
held=[{'university':'ulsan','sourceId':'ulsan-279733-plan344276','title':'로봇명사와의만남','code':None,'section':None,'sourceYear':2026,'sourceSemester':2,'credits':2,'sourceDepartment':'대학공통','sourceProfessor':'김성민','nativeMeeting':'금2,3','sourceRoom':'5호관310호','sourceRoomEvidence':urls['ulsan-robot-poster.jpg'],'sourceUrl':urls['ulsan-robot-plan.hwp'],'sourceLocators':['수업계획서 기본정보 년도-학기/과목번호-분반/담당교수/과목유형','포스터 수업시간/강의실'],'schedules':[],'reason':'계획서(안)+모집포스터의 금2,3은 일치. 원문 과목번호-분반은 -; 원자료기관의 현재 절대시각표 또는 이 강좌 HH:mm 미확인. 메타버스 수업은 강의실 모여 단체시청. 운영확정 및 native identity/시각 확인 전 held.'},
{'university':'ulsan','sourceId':'ulsan-279734-plan344280','title':'지능형로봇의이해','code':None,'section':None,'sourceYear':2026,'sourceSemester':2,'credits':2,'sourceDepartment':'대학공통','sourceProfessor':'김성민(이경창)','nativeMeeting':'계획서(안): 금7,8 / 모집포스터: 금2,3','sourceRoom':'5호관310호','sourceRoomEvidence':urls['ulsan-intelligent-poster.jpg'],'sourceUrl':urls['ulsan-intelligent-plan.hwp'],'schedules':[],'reason':'교시 원문 충돌, 코드-분반 -, 절대시각 미확인. 최신 운영/정정 원문 확인 전 어느 시간을 임의 채택하지 않음.'},
{'university':'unist','sourceId':'unist-yclee-teaching-2026f-cse304','title':'Introduction to Data Mining','code':'CSE304','section':None,'sourceProfessor':'Yeon-Chang Lee','sourceYear':2026,'sourceSemester':2,'sourceScope':'Undergraduate Courses','sourceUrl':urls['unist-yclee.html'],'sourceLocator':'Teaching / Undergraduate Courses / CSE304 Introduction to Data Mining (2026F)','schedules':[],'reason':'교수 본인 공개 교육 페이지에는 2026F 학부 강좌 코드·제목만 있고 분반/요일/시각/강의실/실제 강좌계획 링크 없음. 수업시각을 추정하지 않음.'}]
(p/'additional-held-source-items.json').write_text(json.dumps({'final':True,'integrationEligible':False,'rows':held},ensure_ascii=False,indent=2)+'\n')
ledger={'final':True,'sourceCompletion':False,'newScheduledCandidates':0,'productChanges':False,'testsBuildInstall':False,'schools':[
{'university':'ulsan','preservedBaseline':23,'newRoutes':[urls[k]for k in urls if k.startswith('ulsan-')],'findings':'생명/산업경영/식영은 수강정책. 산업경영 추가 학점교류 교양2개 원문 계획서·포스터 확보; 단1개 교시 충돌. 대학원 시간표/고사 시각/타대학 교류 첨부의 타대학 clock 제외. 학부전체는 기존인증경계 재시도 안 함.','heldItems':2,'nextEvidenceNeeded':'이2개 실제 개설/최종계획 native code/section와 절대 clock. 다른 학과 공개 최종 시간표 자료는 여전히 미확보. 조선해양2025고사 clock는2026강의공통 clock근거로 쓰지 않음.'},
{'university':'unist','preservedBaseline':2,'newRoutes':[urls['unist-yclee.html'],'https://sites.google.com/view/unist-dilab/'],'findings':'추가CSE304학부2026F코드·교수확인, 그 페이지와연결lab에는 시간표링크없음. 기존UNI111/CSE480및UAI/ITEL/디자인세미나/연간curriculum/신입생안내 재수집안함. SAP정보보안차단endpoint재시도나우회없음.','heldItems':1,'nextEvidenceNeeded':'CSE304공개syllabus/분반·시각·방 및 다른학부2026F최종 강좌 자료. 확보가능범위소진/지원불가능으로판정하지않음.'},
{'university':'nsu','preservedBaseline':97,'newRoutes':[urls['nsu-nursing-main.html']],'cachedRoutes':['work/university-research/catalog-e/nsu-current-20261008/department-scope-audit.json','work/university-research/catalog-e/nsu-current-20261008/notice-97427.json','work/university-research/catalog-e/nsu-current-20261008/notice-103700.json'],'findings':'간호현재홈페이지2026시간표=97427; 기존공식첨부2026-1학기시간표_20260130(최종).xlsx여서2학기로사용불가. 103700은2학기3학년중간고사만이며 정규수업시간으로변환불가. 대학원97928은범위외. 기존영어/응급/건축/스마트팜97및2026-2교시가이드 재수집안함.','heldItems':0,'nextEvidenceNeeded':'간호나타학과2026-2정규최종시간표 새공지; 2026간호표를2학기로이름변경금지. 학과자료실의 별도신규공개공지범위 미소진.'},
{'university':'ut','preservedBaseline':70,'newRoutes':[urls[k]for k in urls if k.startswith('ut-')],'findings':'전자학과5/29공식xlsx48개개설예정교과목,코드/시각없음;7/30안내의2학년분반1~6은각강좌실제분반매핑아니므로6배생성금지. 컴퓨터공학시간표게시판총0. 화공생물최근공지첫페이지현재정규시간표없음. 간호6/9가이드10쪽학년별2026-2실제수강과목/일부A-B분반·실습차후공지있으나날짜·요일·시간없음. 중앙로그인경계재시도없음.','plannedRows':48,'nextEvidenceNeeded':'전자최종개설실제코드/분반/요일/시각표,간호이론최종시간표와임상기간·확정실습분반,다른학과현재공개표. 부재가아니라이번bounded조회에서미확보.'}]}
(p/'route-ledger.json').write_text(json.dumps(ledger,ensure_ascii=False,indent=2)+'\n')
print('saved',len(receipt),'source receipts;',len(rows),'planned held;',len(held),'named held; scheduled0')
