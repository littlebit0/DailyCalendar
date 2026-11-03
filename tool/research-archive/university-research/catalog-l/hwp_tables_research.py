"""Minimal read-only CFB/HWP text extraction for official research documents."""
import struct,zlib,sys
from pathlib import Path
p=Path(sys.argv[1]);b=p.read_bytes();assert b[:8]==bytes.fromhex('d0cf11e0a1b11ae1')
u32=lambda x:struct.unpack('<I',x)[0]
size=1<<struct.unpack_from('<H',b,30)[0]
sector=lambda sid:b[(sid+1)*size:(sid+2)*size]
difat=list(struct.unpack_from('<109I',b,76));fat=[]
for sid in difat:
 if sid<0xfffffffa:fat.extend(struct.unpack('<%dI'%(size//4),sector(sid)))
def chain(start,table,data):
 seen=set();out=b''
 while start<0xfffffffa:
  assert start not in seen;seen.add(start);out+=data(start);start=table[start]
 return out
entries=[]
for start in range(0,len(raw:=chain(u32(b[48:52]),fat,sector)),128):
 r=raw[start:start+128];n=struct.unpack_from('<H',r,64)[0]
 if n:
  entries.append((r[:n-2].decode('utf16'),r[66],u32(r[116:120]),struct.unpack_from('<Q',r,120)[0]))
root=next(x for x in entries if x[1]==5);minidata=chain(root[2],fat,sector)[:root[3]]
minifatraw=chain(u32(b[60:64]),fat,sector);minifat=list(struct.unpack('<%dI'%(len(minifatraw)//4),minifatraw))
def stream(entry):
 _,_,sid,n=entry
 return (chain(sid,minifat,lambda i:minidata[i*64:(i+1)*64]) if n<4096 else chain(sid,fat,sector))[:n]
header=stream(next(x for x in entries if x[0]=='FileHeader'));compressed=bool(u32(header[36:40])&1)
import json
records=[]
for entry in entries:
 if not entry[0].startswith('Section'):continue
 data=stream(entry)
 if compressed:data=zlib.decompress(data,-15)
 offset=0
 while offset+4<=len(data):
  record=u32(data[offset:offset+4]);offset+=4;tag=record&1023;level=(record>>10)&1023;length=record>>20
  if length==4095:length=u32(data[offset:offset+4]);offset+=4
  payload=data[offset:offset+length];offset+=length
  records.append((tag,level,payload))
def text_clean(payload):
 s=payload.decode('utf-16le',errors='replace');out=[];i=0
 while i<len(s):
  n=ord(s[i])
  if n in list(range(1,10))+[11,12]+list(range(14,24)):i+=8;continue
  if n==13:out.append('\n')
  elif n>=32 or n==10:out.append(s[i])
  i+=1
 return ''.join(out).strip()
tables=[];current=None;cell=None
for tag,level,payload in records:
 if tag==77:
  current={'index':len(tables),'recordLevel':level,'cells':[]};tables.append(current);cell=None
 elif tag==72 and current is not None and len(payload)>=34 and level==current['recordLevel']:
  col,row,cs,rs=struct.unpack_from('<4H',payload,8)
  cell={'col':col,'row':row,'colSpan':cs,'rowSpan':rs,'paragraphs':[]};current['cells'].append(cell)
 elif tag==67 and cell is not None:
  if level>current['recordLevel']:cell['paragraphs'].append(text_clean(payload))
  else:cell=None
output=p.with_name(p.stem+'-tables.json');output.write_text(json.dumps(tables,ensure_ascii=False,indent=2));print(output,len(tables))
