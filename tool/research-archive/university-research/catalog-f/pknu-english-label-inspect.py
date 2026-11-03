import subprocess,os,signal,time,json,re,urllib.parse,xml.etree.ElementTree as ET
from pathlib import Path
p=Path(__file__).parent;main=p/'pknu-all-syllabus-batch.py';matches=[int(line.split(None,1)[0]) for line in subprocess.check_output(['ps','-eo','pid,args'],text=True).splitlines() if line.rstrip().endswith(' work/university-research/catalog-f/pknu-all-syllabus-batch.py')]
if len(matches)>1:raise SystemExit('Duplicate collector processes: investigate before public requests')
pid=matches[0] if matches else None
if pid is not None:os.kill(pid,signal.SIGSTOP)
try:
 exec(main.read_text().split('# Reuse four')[0])
 r=next(x for x in json.loads((p/'pknu-latest-rows.json').read_text()) if x['COURSE_NO']=='105720' and x['DCLSS_NO']=='101')
 read(entry);time.sleep(.5)
 enc=lambda x:urllib.parse.quote(urllib.parse.quote(x,safe=''),safe='')
 params={'YY':'2026','SHTM_CD':'U0003002','IN_PARAM':"('%s','%s','%s','U0253002')"%(r['COURSE_NO'],r['DCLSS_NO'],r['STAFF_NO']),'_CLIENT_USER_INFO':{},'_PROG_INFO':{'PGM_PATH':'uni::cour/open/LtPdocInq.xfdl','MENU_ID':'U020913','MENU_NM':'강의계획서조회'}}
 report={'reportPath':enc('uni/cour/open/LtPdocMngtPrn.mrd'),'reportParam':enc(json.dumps(params,ensure_ascii=False,separators=(',',':'))),'reportOption':enc('{"ds":"uni"}'),'beforeDraw':'','afterDraw':'','sessionId':next((c.value for c in jar if c.name=='JSESSIONID'),'')}
 h=read('https://reporting.pknu.ac.kr/ReportingServer/embed',{'report':json.dumps(report,separators=(',',':')),'key':''}).decode();time.sleep(.5)
 a=re.search(r"viewer.openFile\('([^']*)','([^']*)',option\)",h);decoder.stdin.write(json.dumps({'path':a[1],'param':a[2]})+'\n');decoder.stdin.flush();d=json.loads(decoder.stdout.readline())
 raw=read('https://reporting.pknu.ac.kr/ReportingServer/service',{'opcode':'700','mrd_path':d['path'],'mrd_param':d['param'],'mrd_plain_param':'','mrd_data':'','runtime_param':'','mmlVersion':'0','protocol':'sync'});texts=[x.text or '' for x in ET.fromstring(raw).iter('TL')]
 labels=[t for t in texts if re.match(r'^(?:Course|Lecture|Class|Credit|Subject|Section|Year|Grade|Instructor|Office|E[ -]?mail|Phone|Department|Term|Semester)(?:\b|\s)',t,re.I) and len(t)<65]
 o={'identity':'105720-101','actualEnglishLabels':labels,'academicHeaderBeforeInstructor':texts[:texts.index('Instructor')],'rawBodyStored':False,'scope':'Published ENG_YN=Y button; no contact values retained'};(p/'pknu-english-published-label-schema.json').write_text(json.dumps(o,ensure_ascii=False,indent=2));print(json.dumps(o,ensure_ascii=False))
finally:
 try:decoder.terminate()
 except:pass
 if pid is not None:os.kill(pid,signal.SIGCONT)
