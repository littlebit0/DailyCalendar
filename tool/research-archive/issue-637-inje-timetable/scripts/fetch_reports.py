# 순차 1초 간격, 목록에 실제 출력 버튼이 있는 키만, 같은 키 재요청 없음(성공 캐시 재사용).
import json,re,sys,subprocess,hashlib,time,urllib.parse,os
import xml.etree.ElementTree as ET
base=sys.argv[1]; rows=json.load(open(os.path.join(base,'inje-native-all-public-rows-20261023.json')))
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0 Safari/537.36 DailyCalendar/1.0 (+https://github.com/littlebit0/DailyCalendar)'
targets={}
for r in rows:
  if r['reportOnclick']: targets.setdefault((r['교과목'],r['분반']),r)
outdir=os.path.join(base,'report-fields'); done=0; errs=0; consec=0
for (code,sec),r in targets.items():
  out=os.path.join(outdir,f'{code}-{sec}.json')
  if os.path.exists(out) and 'error' not in json.load(open(out)): done+=1; continue
  path=re.search(r"PopupReportP\('([^']+)'",r['reportOnclick']).group(1)
  params=dict(urllib.parse.parse_qsl(urllib.parse.urlsplit(path).query,keep_blank_values=True)); params['CAP']=r['reportCAP'] or ''
  u='https://navi.inje.ac.kr/MRD/Subject/SubjB0011R_XML.aspx?'+urllib.parse.urlencode(params)
  res=subprocess.run(['curl','-s','-m','30','-A',UA,u],capture_output=True)
  d={'code':code,'section':sec,'sourceUrl':u,'fetchedAt':time.strftime('%Y-%m-%dT%H:%M:%S%z'),'returncode':res.returncode,'sha256':hashlib.sha256(res.stdout).hexdigest()}
  try:
    root=ET.fromstring(res.stdout)
    d['title']=root.findtext('제목')
    d['courseInformation']={n.tag:(n.text or '') for n in root.findall('./수업계획서/수업정보/*')}
    d['professorDepartment']=root.findtext('./수업계획서/담당교수정보/담당교수소속')
    consec=0
  except Exception as e:
    d['error']=str(e); d['bodyPrefix']=res.stdout[:200].decode(errors='replace'); errs+=1; consec+=1
  json.dump(d,open(out,'w'),ensure_ascii=False,indent=1); done+=1
  if done%100==0: print('processed',done,'errors',errs,flush=True)
  if consec>=5: print('stopped: 5 consecutive failures',flush=True); break
  time.sleep(1.0)
print('done',done,'of',len(targets),'errors',errs,flush=True)
