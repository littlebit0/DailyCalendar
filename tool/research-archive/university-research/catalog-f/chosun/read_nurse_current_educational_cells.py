import pdfplumber,re,json,hashlib
from pathlib import Path
R=Path('work/university-research/catalog-f/chosun');url='https://nurse.chosun.ac.kr/bbs/nurse/694/168052/download.do';b=Path('/private/tmp/chosun-nurse-current-pdf-response').read_bytes()
with pdfplumber.open('/private/tmp/chosun-nurse-current-pdf-response') as p:
 page=p.pages[0];table=page.find_tables()[0];data=table.extract();head=table.rows[0].cells
 clocks=[]
 for i,t in enumerate(data[0]):
  if t and re.search(r'\d\d:\d\d',t):
   times=re.search(r'(\d\d):(\d\d)~(\d\d):(\d\d)',t);box=head[i];clocks.append({'nativeHeader':t,'x0':box[0],'x1':box[2],'startMinute':int(times[1])*60+int(times[2]),'endMinute':int(times[3])*60+int(times[4])})
 rows=[];day=None;grade=None
 for ri,values in enumerate(data[1:],1):
  if values[0]:day=values[0]
  if values[1] and re.fullmatch('[1-4]',values[1]):grade=int(values[1])
  for ci,text in enumerate(values):
   if not text or not re.search(r'\(\d{2}\)',text):continue
   clean=re.sub(r'\s+',' ',text).strip();m=re.fullmatch(r'(.*?)\((\d{2})\)\s*([가-힣]{2,5}|000)\s+(.+)',clean)
   if not m:continue
   box=table.rows[ri].cells[ci];assert box
   start=next((c for c in clocks if abs(c['x0']-box[0])<.2),None);end=next((c for c in clocks if abs(c['x1']-box[2])<.2),None)
   reasons=[]
   if grade not in [1,2]:reasons.append('upperGradeClinicalIntensiveDatesUnverified')
   if not start or not end:reasons.append('nativeCellEdgesNotExactHourHeaders')
   if any(k in clean for k in ['실습','실기','시뮬','집담회']):reasons.append('practicumRotationOperatingDatesUnverified')
   teacher=m[3];room=m[4].strip()
   if teacher=='본관':teacher='';room='본관 '+room
   if teacher in ['', '000']:reasons.append('nativeProfessorUnassigned')
   if not re.fullmatch(r'(?:(?:본관|의대1호관|2호관)\s+)?\d{3,4}',room):reasons.append('notSingleExactNativeRoom')
   rows.append({'sourceId':url+f'#page=1&row={ri}&column={ci}','nativeTableRow':ri,'nativeTableColumn':ci,'bbox':list(box),'nativeCellText':text,'courseName':m[1].strip(),'section':m[2],'professor':teacher,'classroom':room,'weekday':'월화수목금'.index(day)+1,'grade':grade,'firstHeader':start,'lastHeader':end,'heldReasons':reasons})
 (R/'chosun-nurse-current-education-source-20261008.json').write_text(json.dumps({'sourceUrl':url,'sourceSHA256':hashlib.sha256(b).hexdigest(),'nativeHeader':'2026학년도 2학기 간호학과 주간 시간표 (시행용) 2026.09.7 수정본','nativeHourHeaders':clocks,'educationRows':rows,'sourceExtraContactsOrCountsSaved':False},ensure_ascii=False,indent=2)+'\n')
 print('rawsingleeducationrows',len(rows),'eligible',sum(not r['heldReasons'] for r in rows));print([(r['courseName'],r['section'],r['weekday'],r['firstHeader']['startMinute'] if r['firstHeader'] else None,r['lastHeader']['endMinute'] if r['lastHeader'] else None) for r in rows if not r['heldReasons']])
