import requests,pathlib,json,hashlib,pdfplumber,concurrent.futures
P=pathlib.Path(__file__).parent
jobs=[('deu-summer-guide','https://www.kosin.ac.kr/kr/?pCode=haksa&pg=2&mode=fdn&idx=45359&num=1'),('deu-summer-offerings','https://www.kosin.ac.kr/kr/?pCode=haksa&pg=2&mode=fdn&idx=45359&num=2'),('dju-summer-native-guide','https://www.hanseo.ac.kr/boardCnts/fileDown.do?fileSeq=50219ca5fff706101c2dbc467e966881')]
def f(x):
 n,u=x
 try:
  r=requests.get(u,timeout=25);p=P/(n+'.pdf');p.write_bytes(r.content)
  if r.content.startswith(b'%PDF'):
   with pdfplumber.open(p)as doc:t='\n'.join(a.extract_text()or''for a in doc.pages)
   (P/(n+'.txt')).write_text(t)
  else:t=r.text[:300]
  return dict(name=n,url=u,httpStatus=r.status_code,sha256=hashlib.sha256(r.content).hexdigest(),text=t)
 except Exception as e:return dict(name=n,url=u,error=str(e))
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as e:r=list(e.map(f,jobs))
a=json.loads((P/'source-ledger.json').read_text());a.extend(r);(P/'source-ledger.json').write_text(json.dumps(a,ensure_ascii=False,indent=2));print(json.dumps(r,ensure_ascii=False,indent=2))
