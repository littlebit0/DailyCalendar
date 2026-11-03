import pathlib,json,requests,bs4,hashlib,zipfile,io,pdfplumber
P=pathlib.Path(__file__).parent;rows=json.loads((P/'source-ledger.json').read_text())
for n in ['deu-exchange-bnue','deu-summer-exchange']:
 s=bs4.BeautifulSoup((P/(n+'-attachments.html')).read_text(),'html.parser');a=s.select_one('a[href]');u=requests.compat.urljoin('https://lms.pknu.ac.kr',a['href']);session=requests.Session();session.get('https://lms.pknu.ac.kr/ilos/community/notice_view_form.acl?ARTL_NUM='+('10018567' if n=='deu-exchange-bnue' else '9590111'),timeout=25);session.post('https://lms.pknu.ac.kr/ilos/co/file_list.acl',data={'CONTENT_SEQ':'YXOAZTOT5D4AK6RBXTJIKK3A24' if n=='deu-exchange-bnue' else 'ZDMXT3BP53WPC','encoding':'utf-8'},timeout=25);r=session.get(u,headers={'Referer':'https://lms.pknu.ac.kr/ilos/community/notice_view_form.acl?ARTL_NUM='+('10018567' if n=='deu-exchange-bnue' else '9590111')},timeout=30);ext='zip'if n.endswith('exchange') else 'pdf';p=P/(n+'.'+ext);p.write_bytes(r.content);rows.append(dict(name=n+'-native-attachment',url=u,httpStatus=r.status_code,bytes=len(r.content),sha256=hashlib.sha256(r.content).hexdigest(),label=a.text))
 if not r.content.startswith((b'%PDF',b'PK')):
  rows[-1]['blockedReason']='Public attachment link returns session-expired HTML even normal anonymous page session';(P/(n+'-download-blocked.html')).write_bytes(r.content);continue
 if ext=='pdf':
  with pdfplumber.open(p)as doc:t='\n'.join(x.extract_text()or''for x in doc.pages)
  (P/(n+'-attachment.txt')).write_text(t);print(n,t)
 else:
  z=zipfile.ZipFile(io.BytesIO(r.content));out=P/'deu-summer-native';out.mkdir(exist_ok=True)
  for f in z.infolist():
   name=f.filename
   try:name=name.encode('cp437').decode('euc-kr')
   except:pass
   target=out/pathlib.Path(name).name;target.write_bytes(z.read(f));print(str(target))
(P/'source-ledger.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
