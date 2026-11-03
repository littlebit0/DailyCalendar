import pdfplumber,json,pathlib,re
p=pathlib.Path('work/full-timetable-audit-20261012/limited-c-public-sources');out=[]
with pdfplumber.open(p/'iccu-2026fall-guide.pdf')as doc:
 for i in range(54,67):
  page=doc.pages[i];text=page.extract_text()or'';book=i-9
  tables=[]
  for ti,table in enumerate(page.find_tables()):
   rows=table.extract()
   if not rows:continue
   headers=[re.sub(r'\s+','',c or'')for c in rows[0]]
   if '교과목코드'not in headers:continue
   for ri,row in enumerate(rows[1:],1):
    cells=table.rows[ri].cells; vals=list(row)
    if headers[-1]in('강의실','교시')and vals[-1]is None and cells[-2]:
     x0,y0,x1,y1=cells[-2];vals[-1]=page.crop((x1+0.5,y0,555,y1)).extract_text()or''
    data=dict(zip(headers,vals));code=re.sub(r'\s+','',data.get('교과목코드')or'')
    if not re.fullmatch(r'[A-Z0-9]{4,8}',code):continue
    out.append({'pdfPage':i+1,'printedPage':book,'table':ti,'row':ri,'nativeCells':vals,'headers':headers,'metadata':data,'rowBox':next((list(c)for c in cells if c),None)})
(p/'iccu-native-offering-rows.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print('native rows',len(out))
