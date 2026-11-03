import sys,struct,zlib,json,pathlib
sys.path.insert(0,'/private/tmp/daily-catalog-xls-read')
from xlrd.compdoc import CompDoc
root=pathlib.Path('work/university-research/catalog-c/kmou-elecom-semester-makeup-v3-20261009')
def text(b):
 u=struct.unpack('<'+'H'*(len(b)//2),b[:len(b)//2*2]); out=[];i=0
 while i<len(u):
  c=u[i]
  if c<32:
   if c in (10,13,31):out.append(' ')
   if i+7<len(u) and u[i+7]==c and c not in (0,10,13,31):i+=8
   else:i+=1
  else:out.append(chr(c));i+=1
 return ''.join(out).encode('utf-16le', errors='surrogatepass').decode('utf-16le', errors='replace').strip()
for fn in ['kmou-makeup.hwp']:
 d=CompDoc((root/fn).read_bytes()); sections=[]
 for sn in range(10):
  raw=d.get_named_stream('BodyText/Section'+str(sn))
  if raw is None:break
  buf=zlib.decompress(raw,-15); pos=0; rs=[]
  while pos<len(buf):
   v=struct.unpack_from('<I',buf,pos)[0];pos+=4;tag=v&1023;level=(v>>10)&1023;size=v>>20
   if size==4095:size=struct.unpack_from('<I',buf,pos)[0];pos+=4
   b=buf[pos:pos+size];pos+=size
   rs.append((tag,level,b))
  tabs=[]; paragraphs=[]; current=None; cell=None
  for n,(tag,level,b) in enumerate(rs):
   if tag==77:
    current={'record':n,'level':level,'headerHex':b[:24].hex(),'cells':[]};tabs.append(current);cell=None
   elif tag==72 and len(b)==47 and current and level==current['level']:
    col,row,cs,rs_=struct.unpack_from('<HHHH',b,8)
    cell={'row':row,'column':col,'columnSpan':cs,'rowSpan':rs_,'paragraphs':[]};current['cells'].append(cell)
   elif tag==67:
    t=text(b)
    if cell and current and level==current['level']+1:cell['paragraphs'].append(t)
    else:paragraphs.append({'record':n,'level':level,'text':t});cell=None
  sections.append({'section':sn,'tables':tabs,'paragraphs':paragraphs})
 (root/(fn+'.tables.json')).write_text(json.dumps(sections,ensure_ascii=False,indent=2))
 print(fn,[(s['section'],len(s['tables']),sum(len(t['cells']) for t in s['tables']),len(s['paragraphs'])) for s in sections])
 for s in sections:
  for i,t in enumerate(s['tables'][:8]):print(s['section'],i,t['level'],[(c['row'],c['column'],' / '.join(c['paragraphs'])) for c in t['cells'][:10]])
