# Reproduce only the public outlink form and its published PatisTransaction codec.
import urllib.request,http.cookiejar,json,re,uuid,base64
from pathlib import Path
from cryptography.hazmat.primitives.ciphers import Cipher,algorithms,modes
from cryptography.hazmat.primitives.padding import PKCS7
R=Path(__file__).parent
op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
q=op.open(urllib.request.Request('https://cnuit.cnu.ac.kr/patis/common/OutLinkController.do',data=b'method=checkURL&MENU_KEY=M69r16057e79Y231',headers={'Content-Type':'application/x-www-form-urlencoded'}));t=q.read().decode();user=re.search(r'"gv_sessionUser":"([^"]+)"',t)[1]
def enc(v,k):
 if not v:return v
 key=k.replace('-','')[:16].encode();p=PKCS7(128).padder();v=p.update(str(v).encode())+p.finalize();c=Cipher(algorithms.AES(key),modes.CBC(key)).encryptor();return base64.b64encode(c.update(v)+c.finalize()).decode()
def send(method,args,service='Uls0321Service'):
 uid=uuid.uuid4().hex
 args.update(FRAMEWORK_SERVICE_NAME=service,FRAMEWORK_METHOD_NAME=method,FRAMEWORK_LANGUAGE_GB='KO',FRAMEWORK_TRANSACTION_ID=uid,FRAMEWORKLOG_PROTOCOL='JSON',FRAMEWORK_SESSION_USER=user,FRAMEWORK_FRAME_GB='3',FRAMEWORK_FRAME_INFO='outlink',FRAMEWORK_MENU_CD='S010403')
 params={};i=1
 for k,v in args.items():
  if k=='FRAMEWORK_TRANSACTION_ID':n=0;key=user
  else:n=i;i+=1;key=uid
  params[f'FRAMEWORKLOG_PARAM{n}']=[enc(k,key)];params[f'FRAMEWORKLOG_VALUE{n}']=[enc(v,key)]
 body=json.dumps({'param':params});url=f'https://cnuit.cnu.ac.kr/patis/system/serviceController.do?GB={service}_{method}'
 with op.open(urllib.request.Request(url,data=body.encode(),headers={'Content-Type':'application/json','User-Agent':'Mozilla/5.0'}),timeout=45) as q:
  b=q.read();(R/f'cnu-intern-{method}.json').write_bytes(b);print(method,len(b),b[:450])
 j=json.loads((R/'requests.json').read_text());j.append(dict(file=f'cnu-intern-{method}.json',url=url,method='POST',publishedCodec='PatisTransaction, AES CBC PKCS7; ephemeral anonymous outlink user preserved; no auth/queue interaction',requestFields=list(args)));(R/'requests.json').write_text(json.dumps(j,ensure_ascii=False,indent=2))

row=json.loads((R/'cnu-selectList01.json').read_text())['ds_out'];row=next(x for x in row if x['COURSE_NO']=='1000-9133-00')
print({k:v for k,v in row.items() if 'OPEN' in k or 'GENRL' in k or 'STAFF' in k})
send('selectGangwiPopInitData', {k:row[k] for k in ['OPEN_YR','OPEN_SHTM_CD','OPEN_ORGN_CLSF_CD','OPEN_SUST_MJ_CD','OPEN_SBJT_NO','OPEN_DCLSS']}, 'Uls0604Service')

send('selectTab01List', {k:row[k] for k in ['OPEN_YR','OPEN_SHTM_CD','OPEN_ORGN_CLSF_CD','OPEN_SUST_MJ_CD','OPEN_SBJT_NO','OPEN_DCLSS','GENRL_LT_PDOC_TYPE_CD','LT_STAFF_NO']}, 'Uls0604Service')
