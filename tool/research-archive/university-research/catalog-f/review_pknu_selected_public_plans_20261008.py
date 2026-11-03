"""Scoped replay of already published public plan flow; never query absent buttons."""
import json,urllib.request,urllib.parse,http.cookiejar,subprocess,time,re,xml.etree.ElementTree as ET,hashlib
from pathlib import Path
P=Path(__file__).parent;D=P/'pknu-current-20261008';entry='https://irumi.pknu.ac.kr/nxui/launch.html?screenid=Desktop_screen_quick&menuId=U020913'
rows={r['COURSE_NO']+'-'+r['DCLSS_NO']:r for r in json.loads((P/'pknu-latest-rows.json').read_text())}
jar=http.cookiejar.CookieJar();op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
def read(url,fields=None):
 req=urllib.request.Request(url,data=urllib.parse.urlencode(fields).encode()if fields else None,headers={'User-Agent':'Mozilla/5.0','Content-Type':'application/x-www-form-urlencoded','Referer':entry})
 with op.open(req,timeout=40)as f:return f.read()
node='/Users/kimhwi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node';dec=subprocess.Popen([node,str(P/'pknu-report-decode-stream.js')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
read(entry)
try:
 for identity in ['104866-101','114376-101','114380-101','106808-101','109917-101','109920-101']:
  r=rows[identity];assert r['KOR_YN']=='Y';enc=lambda x:urllib.parse.quote(urllib.parse.quote(x,safe=''),safe='')
  params={'YY':'2026','SHTM_CD':'U0003002','IN_PARAM':"('%s','%s','%s','U0253001')"%(r['COURSE_NO'],r['DCLSS_NO'],r['STAFF_NO']),'_CLIENT_USER_INFO':{},'_PROG_INFO':{'PGM_PATH':'uni::cour/open/LtPdocInq.xfdl','MENU_ID':'U020913','MENU_NM':'강의계획서조회'}}
  report={'reportPath':enc('uni/cour/open/LtPdocMngtPrn.mrd'),'reportParam':enc(json.dumps(params,ensure_ascii=False,separators=(',',':'))),'reportOption':enc('{"ds":"uni"}'),'beforeDraw':'','afterDraw':'','sessionId':next((c.value for c in jar if c.name=='JSESSIONID'),'')}
  h=read('https://reporting.pknu.ac.kr/ReportingServer/embed',{'report':json.dumps(report,separators=(',',':')),'key':''}).decode();args=re.search(r"viewer.openFile\('([^']*)','([^']*)',option\)",h);assert args
  dec.stdin.write(json.dumps({'path':args[1],'param':args[2]})+'\n');dec.stdin.flush();v=json.loads(dec.stdout.readline());assert not v.get('error')
  raw=read('https://reporting.pknu.ac.kr/ReportingServer/service',{'opcode':'700','mrd_path':v['path'],'mrd_param':v['param'],'mrd_plain_param':'','mrd_data':'','runtime_param':'','mmlVersion':'0','protocol':'sync'})
  texts=[x.text or''for x in ET.fromstring(raw).iter('TL')];labels=['교과목명','학수번호','분반','강의시간','강의실','강의형태','개설학년','학점-이론-실습'];boundary=set(labels+['개설학(부)과','담당교수','연구실','상담시간','연락처','이메일','혁신수업','핵심역량','인재상','전공능력','ESG']);fields={}
  for label in labels:
   if label not in texts:continue
   out=[]
   for val in texts[texts.index(label)+1:]:
    if val in boundary:break
    out.append(val)
   fields[label]=out
  assert ''.join(fields['학수번호'])==r['COURSE_NO']and''.join(fields['분반'])==r['DCLSS_NO']
  selected=set()
  for n,text in enumerate(texts):
   if re.search(r'\d{1,2}\s*월\s*\d{1,2}\s*일|\d{1,2}[.]\d{1,2}\s*[~～(-]|집중수업|수상레저|수강제한|수강불가',text):selected.update(range(max(0,n-3),min(len(texts),n+5)))
  contexts=[{'sourceTextIndex':i,'text':texts[i]}for i in sorted(selected)if not re.search(r'@|\b0\d{1,2}[- ]\d{3,4}[- ]\d{4}\b|연락처|이메일|비밀번호|password|상담시간',texts[i],re.I)]
  value={'identity':identity,'year':'2026','semester':'2','fields':fields,'selectedAcademicContexts':contexts,'rawBodyStored':False,'sourceSHA256':hashlib.sha256(raw).hexdigest(),'source':'official published public menu U020913/report embed/opcode700','verifiedAt':time.strftime('%Y-%m-%dT%H:%M:%S%z'),'noLoginOrBypass':True}
  (D/(identity+'.selected-education.json')).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n');print(identity,len(contexts),flush=True);time.sleep(.75)
finally:dec.terminate()
