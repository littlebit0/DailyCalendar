from pathlib import Path
import sys,json,hashlib,re,struct,zlib,zipfile,collections
sys.path.insert(0,'/private/tmp/daily-catalog-xls-read')
import xlrd,openpyxl
from xlrd.compdoc import CompDoc
ROOT=Path(__file__).parent;G=ROOT.parent.parent/'catalog-g'
clock=re.compile(r'(?<!\d)(?:[01]?\d|2[0-3])\s*[:：]\s*[0-5]\d(?!\d)')
files=list((G/'cue2026-2-final-files').glob('*.xls*'))+[G/'cnue2026-2-0826.xlsx'];out=[]
for f in files:
 item={'sourceFile':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'sheets':[],'clockCells':[],'comments':[]}
 if f.suffix=='.xlsx':
  w=openpyxl.load_workbook(f,data_only=False);z=zipfile.ZipFile(f);item['embeddedMediaMembers']=[n for n in z.namelist() if n.startswith('xl/media/')];item['drawingXmlMembers']=[n for n in z.namelist() if n.startswith('xl/drawings/') and n.endswith('.xml')]
  for sh in w:
   item['sheets'].append({'title':sh.title,'state':sh.sheet_state,'rows':sh.max_row,'columns':sh.max_column,'mergedRanges':[str(r) for r in sh.merged_cells.ranges]})
   for row in sh:
    for c in row:
     if c.comment:item['comments'].append({'sheet':sh.title,'cell':c.coordinate,'clockTokens':clock.findall(c.comment.text),'commentTextStored':False})
     if isinstance(c.value,str) and clock.search(c.value):item['clockCells'].append({'sheet':sh.title,'cell':c.coordinate,'tokens':clock.findall(c.value),'context':c.value if not re.search(r'@|\d{2,3}[- ]\d{3,4}[- ]\d{4}',c.value) else '[contact context excluded]'})
 else:
  w=xlrd.open_workbook(f,formatting_info=True);d=CompDoc(f.read_bytes());b=d.get_named_stream('Workbook') or d.get_named_stream('Book');pos=0;counts=collections.Counter()
  while pos+4<=len(b):
   tag,n=struct.unpack_from('<HH',b,pos);pos+=4;counts[tag]+=1;pos+=n
  item['objectRecordCounts']={hex(t):counts[t] for t in [0x5d,0xec,0xeb,0x1b6,0x1c]};item['objectRecordLabels']={'0x5d':'OBJ','0xec':'MSODRAWING','0xeb':'MSODRAWINGGROUP','0x1b6':'TXO','0x1c':'NOTE'}
  for sh in w.sheets():
   item['sheets'].append({'title':sh.name,'state':sh.visibility,'rows':sh.nrows,'columns':sh.ncols,'mergedRanges':sh.merged_cells})
   for (r,c),note in sh.cell_note_map.items():item['comments'].append({'sheet':sh.name,'cell':xlrd.formula.cellname(r,c),'clockTokens':clock.findall(note.text),'commentTextStored':False})
   for r in range(sh.nrows):
    for c in range(sh.ncols):
     v=sh.cell_value(r,c)
     if isinstance(v,str) and clock.search(v):item['clockCells'].append({'sheet':sh.name,'cell':xlrd.formula.cellname(r,c),'tokens':clock.findall(v),'context':v if not re.search(r'@|\d{2,3}[- ]\d{3,4}[- ]\d{4}',v) else '[contact context excluded]'})
 out.append(item)
# Current undergraduate source HWP record inventory: paragraphs, table tags, embedded-picture controls.
for f in [G/'cue2026-2-final-guide.hwp',G/'cje2026-2-final0904.hwp']:
 d=CompDoc(f.read_bytes());counts=collections.Counter();tokens=[];sections=0
 for sn in range(30):
  b=d.get_named_stream('BodyText/Section'+str(sn))
  if b is None:break
  sections+=1;b=zlib.decompress(b,-15);pos=0
  while pos+4<=len(b):
   n=struct.unpack_from('<I',b,pos)[0];pos+=4;tag=n&1023;size=n>>20
   if size==4095:size=struct.unpack_from('<I',b,pos)[0];pos+=4
   p=b[pos:pos+size];pos+=size;counts[tag]+=1
   if tag==67:
    t=p.decode('utf-16le',errors='replace');tokens+=clock.findall(t)
 out.append({'sourceFile':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'sections':sections,'tableRecordCount':counts[77],'pictureRecordCount':counts[85],'paragraphRecordCount':counts[67],'allParagraphClockTokens':tokens,'rawParagraphOrContactTextStored':False})
a={'researchDate':'2026-10-09','researchOnly':True,'completionClaim':False,'sourceFrozenFilesUnchanged':True,'sources':out,'scope':'All actualcurrent workbook sheets, hidden sheets, mergedranges, comments, object/image presence; HWP all body sections/table/picture record inventory. No source timestamps or exam/registration windows inferred as ordinary lecture periods.'}
(ROOT/'current-source-structural-education-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n');print(json.dumps([{k:v for k,v in r.items() if k not in ['sheets']} for r in out],ensure_ascii=False,indent=2))
