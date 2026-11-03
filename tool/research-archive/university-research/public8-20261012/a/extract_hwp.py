from pathlib import Path
import olefile,zlib,struct,re
P=Path('work/university-research/public8-20261012/a')
for p in P.glob('*.hwp'):
 o=olefile.OleFileIO(p);texts=[]
 for k in o.listdir():
  if k[0]=='BodyText':
   b=o.openstream(k).read()
   try:b=zlib.decompress(b,-15)
   except zlib.error:pass
   i=0
   while i+4<=len(b):
    h=struct.unpack_from('<I',b,i)[0];i+=4;tag=h&1023;size=h>>20
    if size==4095:size=struct.unpack_from('<I',b,i)[0];i+=4
    if tag==67:texts.append(b[i:i+size].decode('utf-16le',errors='replace'))
    i+=size
 p.with_suffix('.txt').write_text('\n'.join(texts))
