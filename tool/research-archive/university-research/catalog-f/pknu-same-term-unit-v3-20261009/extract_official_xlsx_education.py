from pathlib import Path
import json,hashlib,openpyxl
p=Path(__file__).parent;source=p.parent/'pknu-full.xlsx';w=openpyxl.load_workbook(source,read_only=True,data_only=True);rows=[]
for sheet in w:
 for num,row in enumerate(sheet.iter_rows(min_row=3,values_only=True),3):
  if not row[3] or not row[4]:continue
  fields={'year':str(row[0]),'semester':str(row[1]),'title':row[2],'code':str(row[3]),'section':str(row[4]),'identity':row[5],'method':row[6],'creditScheme':row[35],'unit':str(row[45]) if row[45] is not None else None,'periods':list(row[46:51]),'rooms':list(row[51:56])}
  rows.append({'sheet':sheet.title,'row':num,'fields':fields,'unitCell':f'AT{num}','periodCellRange':f'AU{num}:AY{num}','roomCellRange':f'AZ{num}:BD{num}'})
a={'sourceUrl':'https://www.pknu.ac.kr/boardDownload.do?no=80552','noticeUrl':'https://www.pknu.ac.kr/main/163?action=view&no=725810&cd=10003','publicationDate':'2026-07-30','sourceSemester':'2026-2','sourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'freshIdenticalDownloadDate':'2026-10-08','title':'2026-2학기 개설교과목 현황(260730 9시 배포용)','columnLabels':{'AT1':'수업\n단위','AJ1':'학점\n체제','AU2:AY2':'강의교시1–5','AZ2:BD2':'강의실1–5'},'sourceCurrentUnitConfirmedOct9':False,'rows':rows,'privacy':'only whitelisted education columns; enrollment counts, identifiers/contact fields excluded'}
assert len(rows)==2835
(p/'official-semester-xlsx-education.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print('official rows',len(rows),'unit counts',dict(__import__('collections').Counter(r['fields']['unit'] for r in rows)))
