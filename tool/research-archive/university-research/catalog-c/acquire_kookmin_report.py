import urllib.request,urllib.parse,json,base64,re,http.cookiejar
from pathlib import Path
ROOT=Path(__file__).parent
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
headers={'User-Agent':UA,'Referer':'https://sugang.kookmin.ac.kr/front/enrollment/course-catalog','Accept':'*/*','X-Requested-With':'XMLHttpRequest'}
for subject in ['039540201','071690201','050420201']:
 opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
 data={'filePath':'sch/sles/slesfm/slesfm0340_prn03','paramType':'query','reportBtn':'PEH','reportParams':base64.b64encode(json.dumps({'mlangCd':'ko','reportList':'20262020000'+subject,'loginYn':'0'},separators=(',',':')).encode()).decode()}
 with opener.open(urllib.request.Request('https://kep.kookmin.ac.kr/report/callReport.jsp',data=urllib.parse.urlencode(data).encode(),headers=headers),timeout=35)as r:s=r.read().decode()
 key=re.search(r"'uid':'([^']+)'",s).group(1)
 import time
 for attempt in range(3):
  check={'ClipType':'pageCheck','ClipData':json.dumps({'reportkey':key,'s_time':'t'+str(attempt)},separators=(',',':'))}
  with opener.open(urllib.request.Request('https://kep.kookmin.ac.kr/report/report_server.jsp',data=urllib.parse.urlencode(check).encode(),headers=dict(headers,Referer='https://kep.kookmin.ac.kr/report/callReport.jsp')),timeout=35)as r:c=r.read()
  (ROOT/f'kookmin-report-{subject}-pagecheck.json').write_bytes(c);print(subject,'check',c[:180]);time.sleep(.4)
 payload={'ClipType':'makeDocumentPage','ClipData':json.dumps({'reportkey':key,'pageMethod':0,'compress':False},separators=(',',':'))}
 try:
  with opener.open(urllib.request.Request('https://kep.kookmin.ac.kr/report/report_server.jsp',data=urllib.parse.urlencode(payload).encode(),headers=dict(headers,Referer='https://kep.kookmin.ac.kr/report/callReport.jsp')),timeout=35)as r:b=r.read()
 except urllib.error.HTTPError as e:
  (ROOT/f'kookmin-report-{subject}-error.html').write_bytes(e.read());print(subject,e.code);continue
 (ROOT/f'kookmin-report-{subject}-document.json').write_bytes(b);j=json.loads(b);print(subject,len(b),j.keys(),str(j)[:160])
 if j.get('resValue',{}).get('viewData'):
  decoded=base64.b64decode(j['resValue']['viewData']).decode();(ROOT/f'kookmin-report-{subject}-decoded.json').write_text(decoded)

 if j.get('resValue',{}).get('status'):
  payload={'ClipType':'DocumentPageOnly','ClipData':json.dumps({'reportkey':key,'pageMethod':'TotalPage','isMakeDocument':True},separators=(',',':'))}
  with opener.open(urllib.request.Request('https://kep.kookmin.ac.kr/report/report_server.jsp',data=urllib.parse.urlencode(payload).encode(),headers=dict(headers,Referer='https://kep.kookmin.ac.kr/report/callReport.jsp')),timeout=45)as r:b=r.read()
  (ROOT/f'kookmin-report-{subject}-allpages.json').write_bytes(b);print('allpages',subject,len(b))
