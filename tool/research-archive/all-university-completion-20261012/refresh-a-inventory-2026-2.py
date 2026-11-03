# coding: utf-8
import pathlib,json
from openpyxl import load_workbook
P=pathlib.Path(__file__).parent;f=P/'followup-a-official-system-inventory.json';d=json.loads(f.read_text());(P/'root-followup-a-sources/inventory-2026-1-preserved.json').write_text(json.dumps(d,ensure_ascii=False,indent=2));d['entries']=[r for r in d['entries'] if r['university']!='gnu'];src=P/'root-followup-a-sources/gnu-2026-2-track-md.xlsx';w=load_workbook(src,data_only=True);url='https://www.gnu.ac.kr/common/nttFileDownload.do?fileKey=22c56a1df30407b8e5d085c13b62e43b'
for sh in w:
 rows=[list(x) for x in sh.values]
 for m in sh.merged_cells.ranges:
  for ri in range(m.min_row-1,m.max_row):
   for ci in range(m.min_col-1,m.max_col):rows[ri][ci]=sh.cell(m.min_row,m.min_col).value
 for row,r in enumerate(rows[2:],3):
  if not isinstance(r[0],(int,float)):continue
  extra={'college':r[1],'operatingDepartment':r[2]} if sh.title=='트랙제' else {'operatingDepartment':r[3],'participatingDepartments':r[4],'field':r[1]}
  d['entries'].append(dict(university='gnu',officialGroup=sh.title,name=r[3] if sh.title=='트랙제' else r[2],sourceUrl=url,sourceFile=str(src.resolve()),sheet=sh.title,row=row,semester='2026-2',**extra))
new=[]
for r in d['entries']:
 if r['university']!='chosun':new.append(r);continue
 r=dict(r);r['sourceUrl']='https://www4.chosun.ac.kr/bbs/cob/448/166982/download.do';r['sourceFile']=str((P/'root-followup-a-sources/chosun-2026-2-guide.pdf').resolve());r['semester']='2026-2';r['pdfPage']-=1
 if r['officialGroup']=='마이크로전공' and isinstance(r['originalNumber'],int):
  i=r['originalNumber']
  if i==2:continue
  r['originalNumber']=i-1;r['pdfPage']=36 if i-1<=8 else 37 if i-1<=47 else 38;r['sourceRangeExpanded']=25<=i-1<=45
 new.append(r)
new.append(dict(university='chosun',officialGroup='마이크로전공',name='독일어권특화글로컬무역',originalNumber=54,operatingDepartment='유럽언어문화학부(독일어문화학전공)',participatingDepartments='무역학과',sourceUrl='https://www4.chosun.ac.kr/bbs/cob/448/166982/download.do',sourceFile=str((P/'root-followup-a-sources/chosun-2026-2-guide.pdf').resolve()),pdfPage=38,semester='2026-2'))
d['entries']=new;d['notes'].append('Current GNU/Chosun2026-2 exact originals supersede2026-1 inventory; original inventory preserved. Chosun NHN SW 실무 no longer in published2026-2 list, 독일어권특화글로컬무역 added. No existing courses removed by this inventory change.');f.write_text(json.dumps(d,ensure_ascii=False,indent=2));print('current inventory',len(new),'GNU',sum(r['university']=='gnu' for r in new),'Chosun',sum(r['university']=='chosun' for r in new))
