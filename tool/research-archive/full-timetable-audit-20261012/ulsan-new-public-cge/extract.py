import zipfile,xml.etree.ElementTree as ET,pathlib,json,hashlib,collections
D=pathlib.Path(__file__).parent;p=D/'general-course-openings.xlsx';z=zipfile.ZipFile(p)
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
ss=[]
if 'xl/sharedStrings.xml' in z.namelist():
 for si in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('s:si',ns):ss.append(''.join(t.text or '' for t in si.findall('.//s:t',ns)))
rows=[]
with z.open('xl/worksheets/sheet1.xml') as f:
 for event,e in ET.iterparse(f,events=['end']):
  if e.tag.endswith('}row'):
   cells={}
   for c in e.findall('s:c',ns):
    v=c.find('s:v',ns);value=v.text if v is not None else None
    if c.get('t')=='s' and value is not None:value=ss[int(value)]
    if c.get('t')=='inlineStr':value=''.join(t.text or '' for t in c.findall('.//s:t',ns))
    if value is not None:cells[''.join(x for x in c.get('r','') if x.isalpha())]=value
   if cells:rows.append({'row':int(e.get('r')),'cells':cells})
   e.clear()
header=rows[0];education=[r for r in rows[1:] if r['cells'].get('A')=='2026' and r['cells'].get('B')=='2']
(D/'native-education-rows.json').write_text(json.dumps({'sourceUrl':'https://cge.ulsan.ac.kr/boardDownload.do?no=344571','noticeUrl':'https://cge.ulsan.ac.kr/cge/2759?action=view&no=280045','sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'header':header,'rows':education,'nonEmptyOtherRows':[r for r in rows[1:] if r not in education]},ensure_ascii=False,indent=2))
print('nonempty',len(rows),'education',len(education),'columns',header,'classifications',dict(collections.Counter(r['cells'].get('E') for r in education)),'owners',dict(collections.Counter(r['cells'].get('D') for r in education)))
print('tail',education[-4:])
