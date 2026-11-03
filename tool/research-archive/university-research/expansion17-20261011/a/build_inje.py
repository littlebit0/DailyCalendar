import openpyxl,pathlib,re,json,hashlib
P=pathlib.Path(__file__).parent;w=openpyxl.load_workbook(P/'inje-globalbiz.xlsx',data_only=True);s=w['2026-2학기 글로벌경영학과 시간표 (3안)']
assert s['A1'].value=='2026-2학기 글로벌경영학과 & 글로벌MBA학과 시간표';assert s['A3'].value=='2026.09.06일 기준'
# Each explicit grid period is printed; merged cells determine exact duration.
minutes={}
for r in range(6,17):
 values=re.findall(r'(\d+):(\d+)',s.cell(r,2).value or '')
 if len(values)==2:minutes[r]=tuple(int(h)*60+int(m) for h,m in values)
cols={3:1,4:1,5:1,7:2,8:2,9:2,11:3,12:3,13:3,15:4,16:4,17:4,19:5,20:5}
records={};held=[]
for row in range(6,17):
 for col,weekday in cols.items():
  c=s.cell(row,col)
  if not isinstance(c.value,str) or c.value.strip() in ['', '`']:continue
  raw=c.value;merged=next((r for r in s.merged_cells.ranges if r.min_row==row and r.min_col==col),None)
  last=merged.max_row if merged else row
  if row not in minutes or last not in minutes:held.append({'cell':c.coordinate,'reason':'missing native clock','raw':raw});continue
  teacher=re.search(r'\(([^)]+)\)',raw);room=re.findall(r'\b([DE]\d{3})\b',raw);sec=re.search(r'(\d+)분반',raw)
  if teacher is None or not room:held.append({'cell':c.coordinate,'reason':'native teacher or room missing','raw':raw});continue
  name=re.sub(r'\s+',' ',raw[:teacher.start()]).strip();teacher=teacher[1];section=sec[1] if sec else ''
  # The revised notice explicitly says D215 -> D217: retain new D217.
  classroom=room[-1] if 'Classroom change' in raw else room[0]
  identity=(name,teacher,section);key=json.dumps(identity,ensure_ascii=False)
  if key not in records:
   records[key]={'sourceId':'inje/gimhae/2026/2/'+hashlib.sha256(key.encode()).hexdigest()[:24],'universityId':'inje','campus':'gimhae','campusName':'김해캠퍼스','academicYear':2026,'semester':'2','courseCode':'','courseName':name,'section':section,'professor':teacher,'schedules':[],'departments':['글로벌경영학과'],'departmentCredits':{},'departmentClassifications':{'글로벌경영학과':''},'departmentRemarks':{'글로벌경영학과':'학점·이수구분·과목코드 원문 미표기'},'sourceCells':[], 'sourceSchedule':'', 'sourceClassroom':'', 'period':{'startDate':'2026-09-01','endDate':'2026-12-21'}}
  records[key]['sourceSchedule'] += (' / ' if records[key]['sourceSchedule'] else '') + '월화수목금토일'[weekday-1]+' '+s.cell(row,2).value.split('~')[0].strip()+'~'+s.cell(last,2).value.split('~')[-1].strip(); records[key]['sourceClassroom'] += (' / ' if records[key]['sourceClassroom'] else '') + classroom
  records[key]['schedules'].append({'weekday':weekday,'startMinute':minutes[row][0],'endMinute':minutes[last][1],'classroom':classroom});records[key]['sourceCells'].append(c.coordinate)
url='https://globalbiz.inje.ac.kr/globalbiz/community/notice.do?articleNo=76188&mode=view'
out={'schemaVersion':1,'universityId':'inje','campus':'gimhae','campusName':'김해캠퍼스','academicYear':2026,'semester':'2','sourceUrl':url,'publishedDate':'2026-09-06','sourceSha256':hashlib.sha256((P/'inje-globalbiz.xlsx').read_bytes()).hexdigest(),'sourceRowCount':len(records),'courses':list(records.values()),'heldRows':held,'periodEvidence':{'start':'2026-09-01','end':'2026-12-21','sourceUrl':'https://www.inje.ac.kr/kor/setRoute/B_Page.asp?pCode=IF010010000&viewType=vy&setYear=2026','basis':'9/1 개강,12/15~21기말고사,12/22동계방학'}}
(P/'inje-gimhae-2026-2.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(len(records),sum(len(c['schedules']) for c in records.values()),held)
