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
texts=[]
for entry in entries:
 if entry[0]=='PrvText':texts.append(stream(entry).decode('utf-16le',errors='replace'))
 if entry[0].startswith('Section'):
  data=stream(entry)
  if compressed:data=zlib.decompress(data,-15)
  offset=0
  while offset+4<=len(data):
   record=u32(data[offset:offset+4]);offset+=4;tag=record&1023;length=record>>20
   if length==4095:length=u32(data[offset:offset+4]);offset+=4
   payload=data[offset:offset+length];offset+=length
   if tag==67:texts.append(payload.decode('utf-16le',errors='replace'))
output=p.with_suffix('.txt');output.write_text('\n'.join(texts));print(output)
