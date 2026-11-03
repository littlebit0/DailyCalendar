import requests,pathlib,concurrent.futures,zipfile,json
from pypdf import PdfReader
P=pathlib.Path(__file__).parent
U={'sungkyul-fall-guide.pdf':'https://www.sungkyul.ac.kr/bbs/skukr/96/26953/download.do','sungkyul-fall-timetable.pdf':'https://www.sungkyul.ac.kr/bbs/skukr/96/26976/download.do','sangji-fall-guide.pdf':'https://sangji.ac.kr/cmm/fms/FileDown.do?atchFileId=FILE_000000110049Qx8&fileSn=0','sangji-fall-timetable.zip':'https://sangji.ac.kr/cmm/fms/FileDown.do?atchFileId=FILE_000000110049Qx8&fileSn=2','sangji-fall-closure.pdf':'https://sangji.ac.kr/cmm/fms/FileDown.do?atchFileId=FILE_000000112051Xb8&fileSn=0','hyupsung-spring-timetable.pdf':'https://portal.uhs.ac.kr/ctt/cust/fd?b=14&p=58681&fs=1'}
def f(x):
 n,u=x
 try:
  r=requests.get(u,timeout=40,headers={'User-Agent':'Mozilla/5.0','Referer':'https://sangji.ac.kr/'});(P/n).write_bytes(r.content)
  if n.endswith('.pdf'):
   pdf=PdfReader(P/n);(P/(n+'.txt')).write_text('\n'.join(x.extract_text(extraction_mode='layout') for x in pdf.pages));return n,r.status_code,len(r.content),len(pdf.pages)
  z=zipfile.ZipFile(P/n);names=z.namelist();root=P/n.replace('.zip','');root.mkdir(exist_ok=True)
  for member in names:
   # Only safe flat PDF leaf outputs, no executable or path extraction.
   if member.endswith('.pdf'):
    leaf=pathlib.Path(member).name
    try:leaf=leaf.encode('cp437').decode('cp949')
    except Exception:pass
    file=root/leaf;file.write_bytes(z.read(member));pdf=PdfReader(file);file.with_suffix('.txt').write_text('\n'.join(x.extract_text(extraction_mode='layout') for x in pdf.pages))
  return n,r.status_code,len(r.content),names
 except Exception as e:return n,str(e)
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as e:
 for x in e.map(f,U.items()): print(x)
