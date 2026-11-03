"""Normal official public syllabus read only; no raw contact/session persistence."""
import json,urllib.request,urllib.parse,urllib.error,http.cookiejar,subprocess,time,re,xml.etree.ElementTree as ET
from pathlib import Path
p=Path(__file__).parent;outdir=p/'pknu-current-syllabus';outdir.mkdir(exist_ok=True)
rows=json.loads((p/'pknu-latest-rows.json').read_text())
node='/Users/kimhwi/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node'
decoder=subprocess.Popen([node,str(p/'pknu-report-decode-stream.js')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
jar=http.cookiejar.CookieJar();op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
entry='https://irumi.pknu.ac.kr/nxui/launch.html?screenid=Desktop_screen_quick&menuId=U020913'
def read(url,fields=None):
 if fields is None:req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'})
 else:req=urllib.request.Request(url,data=urllib.parse.urlencode(fields).encode(),headers={'Content-Type':'application/x-www-form-urlencoded','Referer':entry,'User-Agent':'Mozilla/5.0'})
 with op.open(req,timeout=40) as f:return f.read()
def parse(raw,r,source):
 root=ET.fromstring(raw);texts=[e.text or '' for e in root.iter('TL')];wanted={}
 labels=['교과목명','학수번호','분반','강의시간','강의실','강의형태','개설학년','학점-이론-실습']
 boundaries=set(labels+['개설학(부)과','담당교수','연구실','상담시간','연락처','이메일','혁신수업','핵심역량','인재상','전공능력','ESG'])
 runs={}
 for label in labels:
  if label not in texts:continue
  values=[]
  for value in texts[texts.index(label)+1:]:
   if value in boundaries:break
   values.append(value)
  runs[label]=values
  wanted[label]=(', ' if label=='강의실' else ' ').join(values).strip()
 # Only retain academic timing/restriction evidence, never teacher contact lines.
 evidence=[]
 for t in texts:
  if re.search(r'집중수업|수강제한|수강불가|이수불가|(?:\d{1,2}\s*월\s*\d{1,2}\s*일)|(?:\d{1,2}[.]\d{1,2}\s*[(~～-])',t) and not re.search(r'@|\b0\d{1,2}[- ]\d{3,4}[- ]\d{4}\b|상담|연락처',t):evidence.append(t)
 return {'identity':r['COURSE_NO']+'-'+r['DCLSS_NO'],'year':'2026','semester':'2','fields':wanted,'fieldTextRuns':runs,'parserVersion':2,'periodRestrictionEvidence':evidence,'source':source,'verifiedAt':time.strftime('%Y-%m-%dT%H:%M:%S%z'),'rawBodyStored':False}
# Reuse four already freshly verified raw-document cache; future files contain no contacts.
for r in rows:
 id=r['COURSE_NO']+'-'+r['DCLSS_NO'];cache=p/f'pknu-syllabus-{id}.mml';dst=outdir/(id+'.json')
 if cache.exists() and (not dst.exists() or json.loads(dst.read_text()).get('parserVersion')!=2):dst.write_text(json.dumps(parse(cache.read_bytes(),r,'fresh-existing-public-MML-cache'),ensure_ascii=False,indent=2))
read(entry)
started=time.time();stats={};records=[]
for index,r in enumerate(rows):
 id=r['COURSE_NO']+'-'+r['DCLSS_NO'];dst=outdir/(id+'.json')
 if dst.exists() and json.loads(dst.read_text()).get('parserVersion')==2:stats['cached']=stats.get('cached',0)+1;continue
 if r.get('KOR_YN')!='Y' and r.get('ENG_YN')!='Y':
  (outdir/(id+'.unavailable.json')).write_text(json.dumps({'identity':id,'reason':'Current public catalog exposes neither Korean nor English syllabus button','notImpossibleClaim':True},ensure_ascii=False));stats['notPublished']=stats.get('notPublished',0)+1;continue
 failed=None
 for attempt in range(2):
  try:
   enc=lambda x:urllib.parse.quote(urllib.parse.quote(x,safe=''),safe='')
   flag='U0253001' if r.get('KOR_YN')=='Y' else 'U0253002'
   params={'YY':'2026','SHTM_CD':'U0003002','IN_PARAM':"('%s','%s','%s','%s')"%(r['COURSE_NO'],r['DCLSS_NO'],r['STAFF_NO'],flag),'_CLIENT_USER_INFO':{},'_PROG_INFO':{'PGM_PATH':'uni::cour/open/LtPdocInq.xfdl','MENU_ID':'U020913','MENU_NM':'강의계획서조회'}}
   report={'reportPath':enc('uni/cour/open/LtPdocMngtPrn.mrd'),'reportParam':enc(json.dumps(params,ensure_ascii=False,separators=(',',':'))),'reportOption':enc('{"ds":"uni"}'),'beforeDraw':'','afterDraw':'','sessionId':next((c.value for c in jar if c.name=='JSESSIONID'),'')}
   h=read('https://reporting.pknu.ac.kr/ReportingServer/embed',{'report':json.dumps(report,separators=(',',':')),'key':''}).decode('utf-8');time.sleep(.5)
   args=re.search(r"viewer.openFile\('([^']*)','([^']*)',option\)",h)
   if not args:raise ValueError('No official public openFile document response')
   decoder.stdin.write(json.dumps({'path':args[1],'param':args[2]})+'\n');decoder.stdin.flush();decoded=json.loads(decoder.stdout.readline())
   if decoded.get('error'):raise ValueError('Official public transform failed')
   raw=read('https://reporting.pknu.ac.kr/ReportingServer/service',{'opcode':'700','mrd_path':decoded['path'],'mrd_param':decoded['param'],'mrd_plain_param':'','mrd_data':'','runtime_param':'','mmlVersion':'0','protocol':'sync'})
   value=parse(raw,r,'official-public-syllabus-embed-and-opcode700-MML')
   if value['fields'].get('학수번호')!=r['COURSE_NO'] or value['fields'].get('분반')!=r['DCLSS_NO']:raise ValueError('Document identity mismatch')
   dst.write_text(json.dumps(value,ensure_ascii=False,indent=2));stats['success']=stats.get('success',0)+1;failed=None;break
  except urllib.error.HTTPError as e:
   failed={'identity':id,'type':'HTTPError','status':e.code,'attempt':attempt+1}
   if e.code in [401,403,429]:
    (outdir/(id+'.error.json')).write_text(json.dumps(failed));raise SystemExit('Stop on access or rate-limit response; no bypass')
  except Exception as e:failed={'identity':id,'type':type(e).__name__,'message':str(e)[:180],'attempt':attempt+1}
  if failed and attempt==0:time.sleep(5)
 if failed:(outdir/(id+'.error.json')).write_text(json.dumps(failed));stats['errors']=stats.get('errors',0)+1
 if index%25==0:
  state={'total':len(rows),'index':index,'stats':stats,'elapsedSeconds':round(time.time()-started),'resume':'Restart same script; successful JSON caches reused; unpublished button cases never queried','completeCurrentTimeClaim':False}
  (p/'pknu-syllabus-batch-progress.json').write_text(json.dumps(state,ensure_ascii=False,indent=2));print(json.dumps(state),flush=True)
 time.sleep(.75)
state={'total':len(rows),'index':len(rows),'stats':stats,'elapsedSeconds':round(time.time()-started),'finished':True,'completeCurrentTimeClaim':False}
(p/'pknu-syllabus-batch-progress.json').write_text(json.dumps(state,ensure_ascii=False,indent=2));decoder.terminate();print(json.dumps(state),flush=True)
