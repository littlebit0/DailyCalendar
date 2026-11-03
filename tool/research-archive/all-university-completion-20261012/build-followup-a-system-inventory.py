import json,pathlib,hashlib
from openpyxl import load_workbook
P=pathlib.Path(__file__).parent; S=P/'root-followup-a-sources'; out=[]
def add(s,g,n,url,f,**extra):out.append(dict(university=s,officialGroup=g,name=n,sourceUrl=url,sourceFile=str(f.resolve()),**extra))
url='https://www.gnu.ac.kr/common/nttFileDownload.do?fileKey=fdff857f3d609fa62e447677f8842d29';f=S/'gnu-2026-track-md.xlsx';w=load_workbook(f,data_only=True)
for sheet in w:
 rows=[list(r) for r in sheet.values]
 for m in sheet.merged_cells.ranges:
  value=sheet.cell(m.min_row,m.min_col).value
  for ri in range(m.min_row-1,m.max_row):
   for ci in range(m.min_col-1,m.max_col):rows[ri][ci]=value
 for i,r in enumerate(rows[2:],3):
  if not isinstance(r[0],(int,float)):continue
  if sheet.title=='트랙제':add('gnu','트랙제',r[3],url,f,college=r[1],operatingDepartment=r[2],sheet=sheet.title,row=i,semester='2026-1')
  else:add('gnu','마이크로디그리',r[2],url,f,operatingDepartment=r[3],participatingDepartments=r[4],field=r[1],sheet=sheet.title,row=i,semester='2026-1')
for s,k,url in [('daegu','daegu-major-systems','https://www1.daegu.ac.kr/page/130'),('donga','donga-systems','https://dbf.donga.ac.kr/kor/CMS/Contents/Contents.do?mCode=MN147')]:
 f=S/(k+'-tables.json');tb=json.loads(f.read_text())
 if s=='daegu':
  for i,r in enumerate(tb[0][2:],3):add(s,'연계융복합전공',r[0],url,f,participatingDepartments=r[1],originalTable=0,row=i)
  for i,r in enumerate(tb[1][2:],3):add(s,'창의융복합전공',r[0],url,f,participatingDepartments=r[1],originalTable=1,row=i)
  for i,r in enumerate(tb[2][2:],3):
   for j in [0,3]:add(s,'마이크로전공',r[j+1],url,f,operatingDepartment=r[j+2],originalTable=2,row=i)
 else:
  for i,r in enumerate(tb[1][1:],2):add(s,'융합전공Ⅱ',r[0],url,f,participatingDepartments=r[1],originalTable=1,row=i,recruitmentStopped2026='2026년부터 모집하지 않음' in r[0])
(P/'followup-a-official-system-inventory.json').write_text(json.dumps({'final':False,'wholeCompletion':False,'entries':out,'notes':['Exact published program inventories only. Does not create offered courses or infer current timetable membership from course-title similarity. GNU merged source cells explicitly propagated within spreadsheet declared merge ranges. Chosun guide still pending full structured transcription; source PDF acquired.']},ensure_ascii=False,indent=2))
print('inventory',len(out))
