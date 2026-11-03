import pathlib,olefile,zlib,struct,requests,json,bs4,hashlib,re
P=pathlib.Path(__file__).parent
f=olefile.OleFileIO(P/'deu-native-class-rule.hwp');o=[]
for p in f.listdir():
 if p[0]!='BodyText':continue
 b=f.openstream(p).read()
 try:b=zlib.decompress(b,-15)
 except zlib.error:pass
 i=0
 while i+4<=len(b):
  h=struct.unpack_from('<I',b,i)[0];i+=4;t=h&1023;n=h>>20
  if n==4095:n=struct.unpack_from('<I',b,i)[0];i+=4
  if t==67:o.append(b[i:i+n].decode('utf-16le',errors='replace'))
  i+=n
text='\n'.join(o);(P/'deu-native-class-rule.txt').write_text(text);print(text)
rows=json.loads((P/'source-ledger.json').read_text())
for name,seq in [('deu-exchange-bnue','YXOAZTOT5D4AK6RBXTJIKK3A24'),('deu-summer-exchange','ZDMXT3BP53WPC')]:
 u='https://lms.pknu.ac.kr/ilos/co/file_list.acl';r=requests.post(u,data={'CONTENT_SEQ':seq,'encoding':'utf-8'},timeout=25);(P/(name+'-attachments.html')).write_bytes(r.content);print(name,r.status_code,r.text[:2500]);rows.append(dict(name=name+'-attachments',url=u,method='POST',nativeForm={'CONTENT_SEQ':seq,'encoding':'utf-8'},httpStatus=r.status_code,sha256=hashlib.sha256(r.content).hexdigest()))
(P/'source-ledger.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
