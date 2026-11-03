"""Resumable anonymous current syllabus audit; educational whitelist only.
Published UI report parameters are obtained from the ordinary current query.
Internal report identity exists only in transient memory. PDFs/full plans are not saved.
"""
import io,json,re,time,urllib.request,urllib.parse,threading
from concurrent.futures import ThreadPoolExecutor,wait,FIRST_COMPLETED
from pathlib import Path
from datetime import datetime,timezone
from pypdf import PdfReader
P=Path(__file__).resolve().parent
OUT=P/'gachon-full-operating-report-audit.json'
HOST='https://info.gachon.ac.kr'
HEAD={'User-Agent':'Mozilla/5.0','Accept-Language':'ko-KR,ko;q=0.9'}
PUBLIC=('HAKSU_NO','SUBJECT_NM_KOR','ISU_NM','AREA_NM','SISU','PRINT_DPT','PROFNM','TIME','LOC_NM','CYBER_YN')
SIGNALS=('실시간','화상','ZOOM','Zoom','온라인','비대면','대면','녹화','동영상','영상강의','사전학습','Flipped','플립','보강','휴강','휴일','추석','한글날','시험','중간고사','기말고사','집중','현장','실습','봉사')
ENGLISH_SIGNALS={
    '온라인':r'\bonline\b|e[ -]?learning',
    '비대면':r'\bremote\b|non[ -]?face[ -]?to[ -]?face|distance[ -]?learning',
    '동영상':r'\bvideo\b|\basynchronous\b|\bpre[ -]?recorded\b|\brecorded\b',
    '실시간':r'\bsynchronous\b|\blive\s+(?:online|lecture|class|session)',
    '휴강':r'\bno\s+(?:class|lecture|meeting)|\b(?:class|lecture)\s+(?:cancelled|canceled)|\bcancellation\b',
    '휴일':r'\bholiday\b|\bchuseok\b|\bhangeul\b|\bhangul\b|\blunar\s+new\s+year',
    '보강':r'\bmake[ -]?up\b|\bmakeup\b|\breschedul',
    '집중':r'\bintensive\b|\bblock\s+(?:course|teaching|class)',
    '시험':r'\bmid[ -]?term\b|\bfinal\s+(?:exam|test)|\bexam(?:ination)?\b',
    '교외활동':r'답사|견학|교외|대체\s*출석|현장\s*방문|field[ -]?trip|site[ -]?visit|\bexcursion\b|attendance[ -]?replacement',
    '수업없음':r'수업\s*(?:없|미실시|안\s*함|하지\s*않|진행하지)|강의\s*(?:없|미실시)|\bno\s+(?:scheduled\s+)?classes\b',
    '학기불일치표현':r'\b(?:spring|summer|winter)\s+(?:semester|term|202\d)|\b202\d\s+(?:spring|summer|winter)|2026\s*[-/]\s*1\s*학기',
    '영문날짜표현':r'\b(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\.?\s+\d{1,2}\b',
}
ENGLISH_OPERATING=re.compile('|'.join(ENGLISH_SIGNALS.values()),re.IGNORECASE)
OPERATING=re.compile(r'실시간|화상|ZOOM|Zoom|비대면|대면|녹화|동영상|영상강의|사전학습|Flipped|플립|보강|휴강|휴일|추석|한글날|수업.*온라인|온라인.*수업|집중.*수업|실습.*기간|봉사.*시간|중간고사|기말고사|midterm|final exam|face-to-face|in-person|classroom|lecture video|pre-class|in advance|in-class|offline|\d{1,2}:\d{2}|(?<!\d)\d{1,2}\s*시|(?:월|화|수|목|금|토|일)요일|\d{1,2}\s*월\s*\d{1,2}\s*일|(?<!\d)\d{1,2}[./]\d{1,2}(?!\d)',re.IGNORECASE)
PRIVATE=re.compile(r'@|전화|연락|휴대폰|010[- ]|MEMBER|member_no|면담|상담시간|연구실|교수정보|[0-9]{7,}')
def safe_context(lines,index):
    context=' '.join(lines[max(0,index-1):min(len(lines),index+2)]).strip()
    if PRIVATE.search(context):return None
    return context[:450]
ENROLLMENT=re.compile(r'수강\s*대상|수강\s*자격|수강.*제한|수강.*불가|수강.*금지|수강.*가능|이수.*불가|이수.*가능|이수.*제한|전용|재수강|수강신청|선수\s*(?:교과|과목)|prerequisite|pre-requisite|enrollment|restricted|only.{0,40}students|students.{0,40}only',re.IGNORECASE)
ENROLLMENT_HEADING=re.compile(r'^\s*(수강\s*대상|수강\s*자격|수강\s*제한|이수\s*조건|선수\s*과목|선수\s*교과목)\s*[:：]?')

def parse_report(data,row):
    reader=PdfReader(io.BytesIO(data));text='\n'.join(p.extract_text() or '' for p in reader.pages)
    match=re.search(r'학수번호\s*([A-Z0-9]{8})',text)
    identity={'bytes':len(data),'pages':len(reader.pages),'headerCourseCodeMatches':bool(match and match[1]==row['HAKSU_NO']),'currentTermMatches':bool(re.search(r'2026\s*-\s*2\s*학기',text)),'catalogProfessorAppearsInReport':bool(row.get('PROFNM') and row['PROFNM'].strip() in text)}
    result={'educationalParserVersion':6,'report':identity,'weeklyRows':[],'operatingContexts':[],'status':'identity-unverified'}
    if not identity['headerCourseCodeMatches'] or not identity['currentTermMatches']:return result
    result['potentialDifferentTermStatement']=bool(re.search(ENGLISH_SIGNALS['학기불일치표현'],text,re.IGNORECASE))
    weekly=re.search(r'주차\s*기\s*간',text)
    section=text[weekly.end():] if weekly else ''
    section=re.sub(r'(?m)^.*(?:교과목명|강의시간|Date\s*:|주차\s*기\s*간).*$','',section)
    matches=list(re.finditer(r'(?m)^\s*(\d{1,2})\s+(\d{2}/\d{2})\s*~\s*(\d{2}/\d{2})',section))
    for j,m in enumerate(matches):
        activity=section[m.end():matches[j+1].start() if j+1<len(matches) else len(section)].strip()
        lines=activity.splitlines();contexts=[]
        for index,line in enumerate(lines):
            if OPERATING.search(line) or ENGLISH_OPERATING.search(line):
                context=safe_context(lines,index)
                if context and context not in contexts:contexts.append(context)
        signals=[s for s in SIGNALS if s in activity]
        for canonical,pattern in ENGLISH_SIGNALS.items():
            if re.search(pattern,activity,re.IGNORECASE) and canonical not in signals:signals.append(canonical)
        date_expression=re.search(r'\d{1,2}\s*월\s*\d{1,2}\s*일|(?<!\d)\d{1,2}[./]\d{1,2}(?!\d)',activity) or re.search(ENGLISH_SIGNALS['영문날짜표현'],activity,re.IGNORECASE)
        result['weeklyRows'].append({'week':int(m[1]),'startMonthDay':m[2],'endMonthDay':m[3],'activityPresent':bool(activity),'signals':signals,'explicitClockMention':bool(re.search(r'\d{1,2}:\d{2}|(?<!\d)\d{1,2}\s*시',activity)),'explicitAdditionalDateMention':bool(date_expression),'operatingContexts':contexts[:8],'operatingContextLimitReached':len(contexts)>8,'operatingContextTruncationDetected':any(len(c)==450 for c in contexts)})
    enrollment=[];heading_evidence=[];suppressed_enrollment=0
    enrollment_lines=text.splitlines()
    for index,line in enumerate(enrollment_lines):
        heading=ENROLLMENT_HEADING.match(line)
        if heading:
            value=line[heading.end():].strip()
            if PRIVATE.search(value):value=''
            heading_evidence.append({'heading':heading[1],'sameLineEducationalValue':value[:300],'sameLineState':'published-value' if value else 'empty-same-line-not-proof-of-unrestricted'})
        if ENROLLMENT.search(line):
            context=safe_context(enrollment_lines,index)
            if context and context not in enrollment:enrollment.append(context)
            if context is None:suppressed_enrollment+=1
    result['enrollmentEvidence']={'separateFieldState':'heading-found' if heading_evidence else 'no-separate-restriction-heading-found-in-readable-report','headings':heading_evidence,'publicRestrictionContexts':enrollment[:20],'restrictionSentenceState':'educational-sentence-found-needs-context-review' if enrollment else 'no-explicit-restriction-sentence-found-in-readable-report','absenceMeansUnrestricted':False,'privacySuppressedContextCount':suppressed_enrollment,'contextLimitReached':len(enrollment)>20,'contextTruncationDetected':any(len(c)==450 for c in enrollment)}
    # Short operating excerpts include actual teaching-method statements before the weekly table.
    lines=text.splitlines();contexts=[]
    for index,line in enumerate(lines):
        if OPERATING.search(line) or ENGLISH_OPERATING.search(line):
            context=safe_context(lines,index)
            if context and context not in contexts:contexts.append(context)
    result['operatingContexts']=contexts[:30]
    method=re.search(r'강의\s*진행방법(.*?)(?:가천대\s*6대|성적\s*평가방법|평가요소|강의\s*규정|학습자\s*유의사항|교재\s*및\s*참고)',text,re.DOTALL)
    if method:
        method_lines=[line.strip() for line in method[1].splitlines() if line.strip() and not PRIVATE.search(line)]
        result['teachingMethodEducationalExcerpt']=' '.join(method_lines)[:1600]
    else:result['teachingMethodEducationalExcerpt']=''
    result['weeklyTablePresent']=bool(weekly)
    result['noWeeklyDataMessage']='조회된 데이터가 없습니다' in section
    result['status']='current-public-plan-extracted-needs-semantic-review'
    result['allWeeklyRowsAreClasses']=False
    return result

REQUEST_LOCK=threading.Lock()
HALT=threading.Event()
LAST_REQUEST_START=0.0

def request(url,data,headers):
    global LAST_REQUEST_START
    with REQUEST_LOCK:
        if HALT.is_set():raise RuntimeError('Public collection stopped')
        pause=max(0.0,.8-(time.monotonic()-LAST_REQUEST_START))
        if HALT.wait(pause):raise RuntimeError('Public collection stopped')
        LAST_REQUEST_START=time.monotonic()
    try:
        with urllib.request.urlopen(urllib.request.Request(url,data=data,headers=headers),timeout=50) as response:
            if response.status!=200:raise RuntimeError('HTTP non-success')
            body=response.read(8000001)
            if len(body)>8000000:raise RuntimeError('Response limit')
            return body
    except BaseException:
        # In particular401/403/429 stop both workers before another request.
        HALT.set()
        raise

def fetch_report(item):
    campus,category,row=item
    code=row['HAKSU_NO']
    if not re.fullmatch(r'[A-Z0-9]{8}',code):raise RuntimeError('Malformed actual published code')
    record={'educationalParserVersion':6,'campus':campus,'category':category,'sourceRow':{k:row.get(k) for k in PUBLIC}}
    member=row.get('MEMBER_NO')
    if not member:record['status']='no-published-report-identity'
    else:
        rv='REP_ID[SSU0906R] REP_TITLE[수업계획서] REP_SUB_TITLE[2026학년도 2학기] REP_SCHOOL_NM[가천대학교] group_cd['+campus+'] year[2026] term_cd[20] subject_cd['+code[:5]+'] class_num['+code[5:]+'] member_no['+str(member)+'] out_yn[Y] '
        param='/rfn ['+HOST+'/DataServer/rdagent.jsp] /rsn [KWUHS] /rv '+rv+' /rp ['+str(member)+'] /rxlsopt [12] /rhmllocpos [1]'
        form={'opcode':500,'mrd_path':HOST+'/report/see/seeRLectPlan.mrd','mrd_param':param,'export_type':'pdf','protocol':'file','delete_file':'true','attachment':'true','crownix-client':'html5viewer'}
        body=request(HOST+'/ReportingServer/service',urllib.parse.urlencode(form).encode(),{**HEAD,'Content-Type':'application/x-www-form-urlencoded;charset=UTF-8','Referer':HOST+'/jsp/reportViewerOtherNew.html'})
        if not body.startswith(b'%PDF'):raise RuntimeError('Public export not PDF; stopping without bypass')
        record.update(parse_report(body,row));body=None;member=None;rv=None;param=None;form=None
    return record

def run():
    audit=json.loads(OUT.read_text()) if OUT.exists() else {'researchOnly':True,'completionClaim':False,'term':'2026-2','reports':[]}
    audit['stopped']=False;audit['allCurrentReportsFetched']=False;audit['publicQueries']=[]
    def save():
        audit['updatedAt']=datetime.now(timezone.utc).isoformat()
        tmp=OUT.with_suffix('.tmp');tmp.write_text(json.dumps(audit,ensure_ascii=False,indent=2));tmp.replace(OUT)
    rows=[]
    try:
        for campus in ('20','21'):
            for category in ('001','002','003','004','005','006'):
                query={'groupType':campus,'searchYear':'2026','searchTerm':'20','searchUnivCD':'','searchDeptCD':'','searchIsuCD':category,'searchGrade':'','searchSubjectNm':''}
                body=request(HOST+'/Ssu1000q/mainSearch.do',json.dumps({'data':{'SendData':query}}).encode(),{**HEAD,'Content-Type':'application/json;charset=UTF-8','Referer':HOST+'/ssu/showTimetable.do'})
                result=json.loads(body);current=result.get('MainData');count=int(result['dmRowCnt']['rowCnt'])
                if not isinstance(current,list) or len(current)!=count:raise RuntimeError('Incomplete current scope')
                audit['publicQueries'].append({'campus':campus,'category':category,'rowCount':count})
                rows.extend((campus,category,row) for row in current);save();time.sleep(.8)
        if len(rows)!=3809:raise RuntimeError('Current scope changed; explicit reconciliation required')
        previous={(i['campus'],i['row']['HAKSU_NO']):i['row'] for i in json.loads((P/'gachon-current-refresh/courses.json').read_text())}
        changed=sum(any(row.get(k)!=previous.get((campus,row['HAKSU_NO']),{}).get(k) for k in PUBLIC) for campus,category,row in rows)
        audit['fullCurrentCatalogCount']=len(rows);audit['currentEducationalFieldDifferences']=changed
        if changed:raise RuntimeError('Current educational source changed; reconciliation required')
        done={(r['campus'],r['sourceRow']['HAKSU_NO']) for r in audit['reports'] if r.get('educationalParserVersion',0)>=6}
        positions={(r['campus'],r['sourceRow']['HAKSU_NO']):i for i,r in enumerate(audit['reports'])}
        # First examine Flipped Learning and explicit live online, then remaining whole scope.
        rows.sort(key=lambda x:(0 if 'Flipped' in x[2]['SUBJECT_NM_KOR'] else 1 if '실시간화상' in x[2]['SUBJECT_NM_KOR'] else 2,x[2]['HAKSU_NO'],x[0]))
        queue=iter(item for item in rows if (item[0],item[2]['HAKSU_NO']) not in done)
        audit['maxOutstandingReports']=2
        audit['sharedMinimumRequestStartIntervalSeconds']=.8
        audit['currentParserVerifiedCount']=len(done);save()
        with ThreadPoolExecutor(max_workers=2) as pool:
            pending=set()
            for _ in range(2):
                item=next(queue,None)
                if item is not None:pending.add(pool.submit(fetch_report,item))
            try:
                while pending:
                    finished,_=wait(pending,return_when=FIRST_COMPLETED)
                    # Read all completed outcomes before dispatching another report.
                    records=[future.result() for future in finished]
                    pending.difference_update(finished)
                    for record in records:
                        key=(record['campus'],record['sourceRow']['HAKSU_NO'])
                        if key in positions:audit['reports'][positions[key]]=record
                        else:positions[key]=len(audit['reports']);audit['reports'].append(record)
                        done.add(key);audit['currentParserVerifiedCount']=len(done);save()
                        if len(done)%25==0:print('Current parser educational reports',len(done),'of',len(rows),flush=True)
                    for _ in records:
                        if HALT.is_set():raise RuntimeError('Public collection stopped')
                        item=next(queue,None)
                        if item is not None:pending.add(pool.submit(fetch_report,item))
            except BaseException:
                HALT.set()
                for future in pending:future.cancel()
                raise
        audit['allCurrentReportsFetched']=True;save();print('Whole current public report fetch finished',len(audit['reports']),flush=True)
    except BaseException as error:
        audit['stopped']=True;audit['failureType']=type(error).__name__
        audit['failure']='Normal public request or parser failed; private exception text omitted; no bypass or automatic retry.'
        save();print('Stopped',type(error).__name__,'after',len(audit['reports']),'reports',flush=True)
        return 1
    return 0
if __name__=='__main__':raise SystemExit(run())
