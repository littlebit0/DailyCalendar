# coding: utf-8
import pathlib,json,re,hashlib
P=pathlib.Path(__file__).parent;tables=json.loads((P/'cbnu-admin-firstyear-2026-2-tables.json').read_text());table=tables[1];clock={};courses={}
for cell in table['cells']:
 t=cell['paragraphs']
 if cell['col']==1 and len(t)==4 and t[0].endswith('교시'):
  period=int(t[0][:-2]);hm=lambda s:int(s.split(':')[0])*60+int(s.split(':')[1]);clock[period]=(hm(t[1]),hm(t[3]))
for cell in table['cells']:
 t=cell['paragraphs']
 if len(t)!=5 or not re.fullmatch(r'\d{7}-\d{2}',t[1]):continue
 code,section=t[1].split('-');day,period=t[4].split();period=int(period)
 # Source column header directly distinguishes Wed50(col4) vs75(col5), actual cells all50.
 assert cell['col'] in [2,3,4,6,7], 'Other clock family requires separate evidence'
 assert day=={2:'월',3:'화',4:'수',6:'목',7:'금'}[cell['col']]
 key=(code,section);c=courses.setdefault(key,{'courseCode':code,'section':section,'courseName':t[0],'sourceTitleVariants':[],'professor':t[2],'sourceClassroom':t[3],'academicYear':2026,'semester':'2','credits':None,'classification':None,'queryDepartments':['행정학과'],'actualOfferingDepartment':None,'campus':None,'schedules':[],'sourceCells':[],'sourceUrl':'https://public.cbnu.ac.kr/post/2095?category_id=5&page=5','sourceAttachmentUrl':'https://public.cbnu.ac.kr/postact/download/3505','sourceFile':str((P/'cbnu-admin-firstyear-2026-2.hwp').resolve())})
 if t[0] not in c['sourceTitleVariants']:c['sourceTitleVariants'].append(t[0])
 start,end=clock[period];c['schedules'].append({'weekday':{'월':1,'화':2,'수':3,'목':4,'금':5}[day],'startMinute':start,'endMinute':end,'classroom':t[3],'sourcePeriod':period,'sourceClockFamily':'50분'})
 c['sourceCells'].append({'table':1,'row':cell['row'],'column':cell['col'],'paragraphs':t})
for c in courses.values():c['heldFields']=['campus별 공식N동 위치 증거 연결 미완료','credits/classification 원표 미제공; null유지','행정학과1학년 공식조회소속, 실제주관학과단정불가']
battery=json.loads((P/'cbnu-battery-2026-2-rows.json').read_text())['시간표'];held=[]
for row,r in enumerate(battery,1):
 if len(r)>2 and r[2]=='충북대학교':held.append({'row':row,'courseName':r[1],'courseCode':str(r[3]),'section':None,'classification':r[4],'credits':r[5],'professor':r[6],'sourceSchedule':r[8],'sourceClassroom':r[9],'sourceUrl':'https://coss-battery.cbnu.ac.kr/post/332','sourceAttachmentUrl':'https://coss-battery.cbnu.ac.kr/postact/download/187','reason':'원표 분반 없음. 0/10/11/12등 numericclock ownfamily 확인 필요. 임의01금지; 온라인표시를 주간실시간이라고 추측하지 않음.'})
packet={'final':True,'wholeCompletion':False,'sourceScope':'2026-2 행정학과1학년 공개시간표6강좌와 이차전지학점교류충북6원자료. 전학부전체 아님.','courses':list(courses.values()),'heldBatteryRecords':held,'clockSource':{'sourceFile':str((P/'cbnu-admin-firstyear-2026-2.hwp').resolve()),'headerTable':0,'clockTable':1,'sourceClock50':clock,'sourceControl':'수50column4;수75column5;요일및셀coordinates 일치 확인','renderingStatus':'LibreOffice incorrectly treated HWP binary as text; generated PDF/PNG is a failed diagnostic, NOT visual validation. Exact HWP table structure is primary evidence.'},'sourceSha256':hashlib.sha256((P/'cbnu-admin-firstyear-2026-2.hwp').read_bytes()).hexdigest(),'sdkTestBuildInstall':False}
(P/'cbnu-public-six-plus-six-source-packet.json').write_text(json.dumps(packet,ensure_ascii=False,indent=2));print('actualIdentityAndClockCourses',len(courses),'heldBattery',len(held))
