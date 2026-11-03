# Normal public syllabus button path; anonymous cookie and returned metadata preserved.
import urllib.request,urllib.parse,http.cookiejar,json,os,hashlib,base64
from pathlib import Path
from cryptography.hazmat.primitives.ciphers import Cipher,algorithms,modes
from cryptography.hazmat.primitives.padding import PKCS7
r=Path(__file__).parent;op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()));entry='https://jump.jbnu.ac.kr/link?div=sucrPlan';op.open(entry,timeout=30).read();path='sucs/SucsLctrPldocPrtLesnSbj';meta=json.loads(op.open(urllib.request.Request('https://jump.jbnu.ac.kr/Report/print.do',data=urllib.parse.urlencode({'reportFile':path}).encode(),headers={'Content-Type':'application/x-www-form-urlencoded','User-Agent':'Mozilla/5.0','Referer':entry}),timeout=30).read())['_METADATA_']
row=next(x for x in json.loads((r/'jbnu-course-rows.json').read_text()) if x['CERT_DIVCD']=='SUCC010.001' and (x['LESSN_HR_DIVCDNM'] or '').startswith('75'))
params={'TITLE':'강의계획서(2026학년도 2학기)','P_YRSA':'2026','P_SEMSTR_CD':'SUSR016.020','P_SBJCT_CD':row['SBJCT_CD'],'P_DVCLS_NO':row['DVCLS_NO'],'P_MACE_DIVCD':'SUEA103.001','PRT_INFO':meta['PRINT_INFO'],'_AUTH_USER_ID':meta.get('AUTH_USER_ID',''),'_AUTH_TASK_AUTHRT_ID':meta.get('AUTH_TASK_AUTHRT_ID',''),'_AUTH_MENU_ID':meta.get('AUTH_MENU_ID',''),'APP_CONTEXT':meta['APP_CONTEXT'],'APP_USER_ID':meta.get('APP_USER_ID','')}
iv=os.urandom(16);salt=os.urandom(16);key=hashlib.pbkdf2_hmac('sha1',b'wjsqnreogkrrycnffura',salt,100,16)
def enc(t):
 p=PKCS7(128).padder();b=p.update(str(t).encode())+p.finalize();c=Cipher(algorithms.AES(key),modes.CBC(iv)).encryptor();return urllib.parse.quote(base64.b64encode(c.update(b)+c.finalize()).decode(),safe='')
fields=[('Xiiv',iv.hex()),('Xsst',salt.hex()),('crfFilePath',path)]+[('viewerParameter',enc(k+':='+str(v))) for k,v in params.items()]
opts={'reportViewMode':'DOCSVG','exportFileName':params['TITLE'],'excelSheetName':'제목없음','scaleRatio':'100','visibleToolbar':'true','visibleSaveButton':'true','visiblePrintButton':'true','directPrint':'false','saveFileTypes':'ALL','viewFontFamily':'DEFAULT','drmBarcodeAply':'N','forcePrvcDownloadLog':'N'};fields += [(k,enc(v)) for k,v in opts.items()];url='https://jump.jbnu.ac.kr/report/reportFx.jsp'
with op.open(urllib.request.Request(url,data=urllib.parse.urlencode(fields).encode(),headers={'Content-Type':'application/x-www-form-urlencoded','Referer':'https://jump.jbnu.ac.kr/clipreport/reportViewer.jsp'}),timeout=45) as q:
 b=q.read();(r/'jbnu-syllabus-report.html').write_bytes(b);print(q.status,len(b),row['STDTR_NO'],row['DVCLS_NO'],row['DOW_HR_CN'])
(r/'jbnu-syllabus-request-fields.json').write_text(json.dumps({'url':url,'courseIdentity':row['SBJCT_CD']+'-'+str(row['DVCLS_NO']),'fields':[k for k,v in fields],'publishedCodec':'PBKDF2 SHA1 100 iterations 128bit, randomsalt/iv, AES-CBC-PKCS7; exact public reportViewer.jsp codec','publicSessionEstablished':True,'noPrintTriggered':True},ensure_ascii=False,indent=2))

import re
uid=re.search(r"'uid':'([^']+)'",b.decode())[1]
url='https://jump.jbnu.ac.kr/report/report_server.jsp';payload=urllib.parse.urlencode({'ClipType':'DocumentPageView','ClipData':json.dumps({'reportkey':uid,'pageMethod':0,'isMakeDocument':True})}).encode()
with op.open(urllib.request.Request(url,data=payload,headers={'Content-Type':'application/x-www-form-urlencoded','User-Agent':'Mozilla/5.0','Referer':'https://jump.jbnu.ac.kr/report/reportFx.jsp'}),timeout=45) as q:
 raw=q.read();(r/'jbnu-syllabus-page0.json').write_bytes(raw);print('documentpage',q.status,len(raw),raw[:150])

payload=urllib.parse.urlencode({'ClipType':'DocumentPageOnly','ClipData':json.dumps({'reportkey':uid,'pageMethod':'TotalPage','isMakeDocument':True})}).encode()
with op.open(urllib.request.Request(url,data=payload,headers={'Content-Type':'application/x-www-form-urlencoded','User-Agent':'Mozilla/5.0','Referer':'https://jump.jbnu.ac.kr/report/reportFx.jsp'}),timeout=45) as q:
 raw=q.read();(r/'jbnu-syllabus-all-pages.json').write_bytes(raw);print('allpages',q.status,len(raw))
