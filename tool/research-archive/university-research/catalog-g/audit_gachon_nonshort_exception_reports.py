"""Anonymous public Crownix export using actual current UI query identities.
No PDF, complete report text, staff IDs, cookies or contacts are persisted.
"""
import io,json,re,time,urllib.request,urllib.parse,pathlib
from pypdf import PdfReader
HOST='https://info.gachon.ac.kr'
OUT=pathlib.Path('work/university-research/catalog-g/gachon-nonshort-report-exception-audit.json')
PUBLIC=('HAKSU_NO','SUBJECT_NM_KOR','ISU_NM','AREA_NM','SISU','PRINT_DPT','PROFNM','TIME','LOC_NM','CYBER_YN')
HEAD={'User-Agent':'Mozilla/5.0','Accept-Language':'ko-KR,ko;q=0.9'}
audit={'researchOnly':True,'completionClaim':False,'term':'2026-2','publicQueries':[],'reports':[],'stopped':False}
def save():
 tmp=OUT.with_suffix('.tmp');tmp.write_text(json.dumps(audit,ensure_ascii=False,indent=2));tmp.replace(OUT)
def request(url,data,headers,timeout=50):
 with urllib.request.urlopen(urllib.request.Request(url,data=data,headers=headers),timeout=timeout) as r:
  if r.status!=200:raise RuntimeError('HTTP non-success')
  b=r.read(8000001)
  if len(b)>8000000:raise RuntimeError('Response limit')
  return b
rows=[]
try:
 for campus in ('20','21'):
  for cat in ('001','002','003','004','005','006'):
   v={'groupType':campus,'searchYear':'2026','searchTerm':'20','searchUnivCD':'','searchDeptCD':'','searchIsuCD':cat,'searchGrade':'','searchSubjectNm':''}
   b=request(HOST+'/Ssu1000q/mainSearch.do',json.dumps({'data':{'SendData':v}}).encode(),{**HEAD,'Content-Type':'application/json;charset=UTF-8','Referer':HOST+'/ssu/showTimetable.do'})
   a=json.loads(b);rr=a.get('MainData');n=int(a['dmRowCnt']['rowCnt'])
   if not isinstance(rr,list) or len(rr)!=n:raise RuntimeError('Incomplete current scope')
   audit['publicQueries'].append({'campus':campus,'category':cat,'rowCount':n})
   for r in rr:
    rows.append((campus,cat,r))
   save();time.sleep(.6)
 audit['fullCurrentCatalogCount']=len(rows)
 wanted={r['row']['HAKSU_NO'] for r in json.loads(pathlib.Path('work/university-research/catalog-g/gachon-full-catalog-nonshort-exception-candidates.json').read_text())['rows']}
 rows=[item for item in rows if item[2]['HAKSU_NO'] in wanted]
 rows.sort(key=lambda item: (0 if ('NTree' in item[2]['SUBJECT_NM_KOR'] or '부트캠프' in item[2]['SUBJECT_NM_KOR']) else 1 if item[2].get('CYBER_YN') else 2,item[2]['HAKSU_NO']))
 audit['selectedContextCount']=len(rows);save();print('Selected context audit count',len(rows),flush=True)
 for index,(campus,cat,r) in enumerate(rows):
  code=r['HAKSU_NO'];member=r.get('MEMBER_NO')
  record={'campus':campus,'category':cat,'sourceRow':{k:r.get(k) for k in PUBLIC}}
  if not re.fullmatch(r'[A-Z0-9]{8}',code):raise RuntimeError('Malformed actual published code')
  if not member:
   record['status']='no-published-report-identity';audit['reports'].append(record);save();continue
  rv='REP_ID[SSU0906R] REP_TITLE[수업계획서] REP_SUB_TITLE[2026학년도 2학기] REP_SCHOOL_NM[가천대학교] group_cd['+campus+'] year[2026] term_cd[20] subject_cd['+code[:5]+'] class_num['+code[5:]+'] member_no['+str(member)+'] out_yn[Y] '
  param='/rfn ['+HOST+'/DataServer/rdagent.jsp] /rsn [KWUHS] /rv '+rv+' /rp ['+str(member)+'] /rxlsopt [12] /rhmllocpos [1]'
  form={'opcode':500,'mrd_path':HOST+'/report/see/seeRLectPlan.mrd','mrd_param':param,'export_type':'pdf','protocol':'file','delete_file':'true','attachment':'true','crownix-client':'html5viewer'}
  b=request(HOST+'/ReportingServer/service',urllib.parse.urlencode(form).encode(),{**HEAD,'Content-Type':'application/x-www-form-urlencoded;charset=UTF-8','Referer':HOST+'/jsp/reportViewerOtherNew.html'})
  if not b.startswith(b'%PDF'):raise RuntimeError('Public export not PDF; possible service block; stopping')
  reader=PdfReader(io.BytesIO(b));text='\n'.join(p.extract_text() or '' for p in reader.pages)
  codeMatch=re.search(r'학수번호\s*([A-Z0-9]{8})',text)
  record['report']={'bytes':len(b),'pages':len(reader.pages),'headerCourseCodeMatches':bool(codeMatch and codeMatch[1]==code),'currentTermMatches':bool(re.search(r'2026\s*-\s*2\s*학기',text)),'catalogProfessorAppearsInReport':bool(r.get('PROFNM') and r['PROFNM'].strip() in text)}
  if not record['report']['headerCourseCodeMatches'] or not record['report']['currentTermMatches']:
   record['status']='identity-unverified';record['weeklyDateEvidence']=[]
  else:
   weekly=re.search(r'주차\s*기\s*간',text)
   section=text[weekly.end():] if weekly else ''
   dates=[]
   for line in section.splitlines():
    if re.search(r'@|전화|연락|010[- ]|면담|Date\s*:',line):continue
    # Only date expressions are retained. Neither narrative nor contact text.
    for m in re.finditer(r'(?<!\d)(?:20\d{2}[./-])?\d{1,2}[./]\d{1,2}(?!\d)|(?<!\d)\d{1,2}\s*월\s*\d{1,2}\s*일',line):
     dates.append(m[0])
   weekRows=[]
   section=re.sub(r'(?m)^.*(?:교과목명|강의시간|Date\s*:|주차\s*기\s*간).*$','',section)
   matches=list(re.finditer(r'(?m)^\s*(\d{1,2})\s+(\d{2}/\d{2})\s*~\s*(\d{2}/\d{2})',section))
   for j,m in enumerate(matches):
    activity=section[m.end():matches[j+1].start() if j+1<len(matches) else len(section)].strip()
    weekRows.append({'week':int(m[1]),'startMonthDay':m[2],'endMonthDay':m[3],'activityPresent':bool(activity),'signals':[word for word in ('온라인','비대면','화상','보강','휴강','휴일','추석','한글날','중간고사','기말고사','시험','프로젝트','현장') if word in activity]})
   record['weeklyRows']=weekRows
   relevant=[]
   lines=section.splitlines()
   for j,line in enumerate(lines):
    if not re.search(r'\d{1,2}[./]\d{1,2}|온라인|비대면|보강|휴강|공휴일|입시|논술',line):continue
    context=' '.join(lines[max(0,j-1):min(len(lines),j+2)])
    if re.search(r'@|전화|연락|010[- ]|MEMBER|면담|[0-9]{7,}',context):continue
    # Only scheduling-related public table sentences, max one paragraph.
    relevant.append(context[:700])
   record['publicSchedulingContexts']=list(dict.fromkeys(relevant))
   record['weeklyDateEvidence']=list(dict.fromkeys(dates));record['weeklyTablePresent']=bool(weekly)
   record['noWeeklyDataMessage']='조회된 데이터가 없습니다' in section
   record['status']='date-expressions-present-needs-row-context' if dates else 'no-explicit-weekly-date'
  audit['reports'].append(record);save()
  if (index+1)%25==0:print('Reports',index+1,'of',len(rows),'date-bearing',sum(bool(x.get('weeklyDateEvidence')) for x in audit['reports']),flush=True)
  b=None;text=None;reader=None;member=None;param=None;rv=None;time.sleep(.6)
 audit['allSelectedReportsFetched']=True;save();print('Finished public nonshort exception reports',len(rows),flush=True)
except BaseException as e:
 audit['stopped']=True;audit['failureType']=type(e).__name__;audit['failure']='Normal public request or parser failed; no bypass/retry/private exception text retained.';save();print('Stopped',type(e).__name__,'after',len(audit['reports']),'reports',flush=True)
 raise SystemExit(1)
