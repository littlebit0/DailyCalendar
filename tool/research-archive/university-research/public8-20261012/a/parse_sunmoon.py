"""Process only acquired official Sunmoon 2026-2 rows; no generated offerings."""
from pathlib import Path
from bs4 import BeautifulSoup
import json,re,hashlib,openpyxl,xlrd
P=Path(__file__).parent
PERIOD={'startDate':'2026-09-01','endDate':'2026-12-14'}
# The university's 2026-2 registration handbook explicitly publishes 0..13 clocks.
manual=Path('work/university-research/expansion17-20261011/b/sunmoon-mgt-fall-hwp-extracted.txt').read_text()
t=manual[manual.index('2. 수업편성시간'):];clocks=re.findall(r'(\d{2}:\d{2})\s*~(\d{2}:\d{2})',t)[:14]
if len(clocks)!=14:raise ValueError('Native clock table incomplete')
def minute(s):h,m=map(int,s.split(':'));return h*60+m
CLOCK={i:(minute(a),minute(b))for i,(a,b) in enumerate(clocks)}
rows=[]
def add(name,code,section,prof,credit,classification,department,schedule,url,original,remark='',timeless=False):
 blocks=[]
 if not timeless:
  for day,periods in re.findall(r'([월화수목금토일])\s*([0-9]+(?:[,.][0-9]+)*)',schedule):
   ps=list(map(int,re.split('[,.]',periods)));start,end=CLOCK[min(ps)][0],CLOCK[max(ps)][1]
   blocks.append({'weekday':'월화수목금토일'.index(day)+1,'startMinute':start,'endMinute':end,'classroom':''})
  if not blocks:raise ValueError('Native schedule missing')
 identity=json.dumps([name,code,section,prof,schedule],ensure_ascii=False)
 rows.append(dict(sourceId='sunmoon/unknown/2026/2/'+hashlib.sha256(identity.encode()).hexdigest()[:24],universityId='sunmoon',campus='unknown',campusName='캠퍼스 미구분',academicYear=2026,semester='2',courseCode=code,courseName=name,section=section,professor=prof,schedules=blocks,scheduleStatus='unscheduled' if timeless else 'scheduled',departments=[department],departmentCredits={department:credit}if credit is not None else{},departmentClassifications={department:classification},departmentRemarks={department:remark},sourceSchedule=schedule,sourceClassroom='',sourceUrl=url,sourceCells=original,period=PERIOD))
# Actual foreign-language amendment: first table CLOSED, second table current.
s=BeautifulSoup((P/'sunmoon-dla-fall.html').read_text(),'html.parser');tables=s.select('.bbsV_cont table')
closed=[]
for tr in tables[0].select('tr')[1:]:closed.append([c.get_text(' ',strip=True)for c in tr.select('td')])
for tr in tables[1].select('tr')[1:]:
 cells=[c.get_text(' ',strip=True)for c in tr.select('td')];c,code,name,section,time,prof=cells
 add(name,code,section,prof,None,c,'교양학부',time,'https://dla.sunmoon.ac.kr/dla/na/ntt/selectNttInfo.do?bbsId=1256&mi=41117&nttSn=1324974',cells,'컴퓨터공학부 전용반 → 전체 재학생 대상. 학점·강의실 원문 미표기')
# Official Sunmoon file mirrored by Kookmin future-mobility consortium.
p=next(P.glob('[[]선문대[]]*목록.xlsx'));ws=openpyxl.load_workbook(p,data_only=True).active
for r in list(ws.values)[3:7]:
 _,level,grade,name,code,uni,cl,hrs,room,credit,section,prof,mode,time,_,remark=r
 add(name,str(code),str(section),prof,float(credit),'','미래자동차융합전공',time,'https://www.kookmin.ac.kr/user/kmuNews/notice/4/12155/view.do',list(r),'; '.join(x for x in [mode,remark,'이수구분·강의실 원문 미표기']if x))
# University HUSS exact clock/date list + native syllabus. Blank code is unpublished.
xls=next((P/'sunmoon-huss-1').glob('*.xls'));sheet=xlrd.open_workbook(xls).sheet_by_index(0)
for i in range(2,sheet.nrows):
 r=sheet.row_values(i);_,cl,_,name,prof,dates,time,mode,remark=r
 if name=='데이터와 미디어 리터러시':code,section='920418','11'
 else:code,section='',''
 add(name,code,section,prof,3,cl,'HUSS 위험사회',time,'https://huss.kw.ac.kr/bulletin/notice.php?BoardMode=view&UID=293',r,mode+'; '+remark+(''if code else'; 과목코드·분반 원문 미표기'))
# Three explicitly asynchronous offerings remain timetable-less (not generated clocks).
x=next(p for p in (P/'sunmoon-huss-0').glob('*.xlsx')if '▒│░·' in p.name)
ws=openpyxl.load_workbook(x,data_only=True).active
for r in list(ws.values)[2:5]:
 _,uni,level,course,name,prof,credit,hours,section,mode,remark,*_=r
 add(name,'',str(section),prof,credit,'','HUSS 글로벌공생','비대면(동영상) 100','https://huss.kw.ac.kr/bulletin/notice.php?BoardMode=view&UID=293',list(r),mode+'; 과목코드 원문 미표기',timeless=True)
for row in rows:
 if row['departments']==['HUSS 글로벌공생']:
  row['periodEvidence']={'file':'sunmoon-huss-0.zip / 글로벌공생 학점교류 안내.hwp','literal':'2. 수업기간: 2026.9.1.(화) ~ 12.14.(월)'}
  row['rowEvidence']='글로벌공생 XLSX 본문1행2026-2, 데이터행3–5; 녹화100% 시각없음'
 elif row['departments']==['HUSS 위험사회']:
  row['periodEvidence']={'file':'sunmoon-huss-1.zip / 위험사회 교과목 목록.xls','literal':'26.9.1.(화) ~ 12.14.(월)'}
  row['rowEvidence']='위험사회 XLS 행3–4 정확시각+학기; PDF계획서1쪽 실제학점3 및 데이터리터러시920418-11'
 elif row['departments']==['미래자동차융합전공']:
  row['periodEvidence']={'file':'[선문대] 2026-2학기 미래자동차융합전공 학점교류 안내.hwp','literal':'2. 수업기간: 2026. 9. 1.(화) ~ 2026. 12. 14.(월)'}
  row['rowEvidence']='미래자동차 개설교과목 XLSX 26-2 시트 데이터행4–7, native표시 그대로'
 else:
  row['periodEvidence']={'file':'공식2026-2 수강안내 HWP 연간학사달력','literal':'9/1 개강, 12/8–14 기말고사, 12/15 동계방학'}
  row['rowEvidence']='공식1324974 공지 두번째표(수정사항)행2; 첫표 폐강과목3개제외'
raw_files=[P/'sunmoon-huss-1.zip',P/'sunmoon-huss-0.zip',P/'sunmoon-dla-fall.html',next(P.glob('[[]선문대[]]*목록.xlsx')),next(P.glob('[[]선문대[]]*안내.hwp')),Path('work/university-research/expansion17-20261011/b/sunmoon-mgt-fall.hwp')]
digests={p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in raw_files}
packet_digest=hashlib.sha256(json.dumps(digests,sort_keys=True,ensure_ascii=False).encode()).hexdigest()
data=dict(schemaVersion=1,universityId='sunmoon',campus='unknown',campusName='캠퍼스 미구분',academicYear=2026,semester='2',sourceUrl='https://huss.kw.ac.kr/bulletin/notice.php?BoardMode=view&UID=293',publishedDate='2026-07-13',publishedDateUnavailable=False,sourceSha256=packet_digest,sourceDigests=digests,sourceRowCount=len(rows),scope='공개 교양 변경1·미래자동차4·HUSS위험사회2·녹화전용3; 전체 목록 아님',courses=rows,excludedClosedCourses=closed,periodEvidence={'url':'https://www.kookmin.ac.kr/user/kmuNews/notice/4/12155/view.do','file':'[선문대] 2026-2학기 미래자동차융합전공 학점교류 안내.hwp','literal':'2. 수업기간: 2026. 9. 1.(화) ~ 2026. 12. 14.(월)'},clockEvidence={'url':'https://mgt.sunmoon.ac.kr/mgt/na/ntt/selectNttInfo.do?nttSn=1324468&bbsId=1155&mi=40673','literal':'60분 수업(50분 수업,10분 휴식)','clocks':clocks})
(P/'sunmoon-unknown-2026-2.json').write_text(json.dumps(data,ensure_ascii=False,indent=2));print(len(rows),'native courses',sum(bool(x['schedules'])for x in rows),'scheduled; ',len(closed),'closed excluded')
