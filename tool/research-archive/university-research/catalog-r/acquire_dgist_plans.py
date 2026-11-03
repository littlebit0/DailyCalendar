"""Read only actual published anonymous plans; persist education fields only."""
import json,pathlib,urllib.request,urllib.parse,time,http.cookiejar
P=pathlib.Path(__file__).resolve().parent
opener=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
opener.open('https://welcome.dgist.ac.kr/ucs/ucsqProfRespSbjtInq/index.do',timeout=35).read()
u={}
for y in ['2020','2024','2014']:
 for r in json.loads((P/f'dgist2026-2-{y}-curriculum-rows.json').read_text()):u.setdefault((r['SBJT_NO'],r['CLSS_NO']),r)
allowed={'SBJT_NO','CLSS_NO','SBJT_NM','CPTN_DCD','TMCNT','INFO','LT_SUMA','LT_PURO','LT_POLY','LSN_MTHD','ETC','SCHETCHUL','ALL_CNTN','PWEEK_YN'}
out=[];dest=P/'dgist-current-published-plans-educational.json'
if dest.exists():out=json.loads(dest.read_text())
done={(x['code'],x['section']) for x in out}
for key,x in u.items():
 if not int(x['LECPLN_CNT']) or key in done:continue
 f={k:x[v] for k,v in {'conYear':'SHYY','conTerm':'SHTM_DCD','conOrgn':'ORGN_CLSF_DCD','conSust':'ASGN_SUST_CD','conCors':'ASGN_CORS_DCD','conClss':'CLSS_NO','conSbjtNo':'SBJT_NO'}.items()};f.update(conLang='ko',pageNum='1',pageSize='100',commonProgramId='UcseLsnPdocMngt')
 try:
  time.sleep(.6)
  raw=opener.open(urllib.request.Request('https://welcome.dgist.ac.kr/ucs/ucseLsnPdocMngt/lecInfo.do',data=urllib.parse.urlencode(f).encode()),timeout=35).read()
  if not raw:
   time.sleep(.6)
   raw=opener.open(urllib.request.Request('https://welcome.dgist.ac.kr/ucs/ucseLsnPdocMngt/lecInfo.do',data=urllib.parse.urlencode(f).encode()),timeout=35).read()
  if not raw:
   out.append({'code':key[0],'section':key[1],'status':'empty-body-unverified','attempts':2});dest.write_text(json.dumps(out,ensure_ascii=False,indent=2));continue
  d=json.loads(raw)
  assert d['SBJT_NO']==key[0] and d['CLSS_NO']==key[1]
  safe={k:v for k,v in d.items() if k in allowed}
  out.append({'code':key[0],'section':key[1],'fields':safe});dest.write_text(json.dumps(out,ensure_ascii=False,indent=2))
  if len(out)%20==0:print('published plans',len(out),flush=True)
 except Exception as e:
  (P/'dgist-plan-request-failure.json').write_text(json.dumps({'code':key[0],'section':key[1],'errorType':type(e).__name__,'collected':len(out),'stoppedOnFailure':True},indent=2));print('stopped',type(e).__name__,len(out),flush=True);break
print('finished',len(out),flush=True)
