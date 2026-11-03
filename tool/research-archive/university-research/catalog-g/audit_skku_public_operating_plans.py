"""Resumable actual outsider educational detail audit; no print calls or credentials."""
import json,time,re,io,urllib.request,hashlib,zipfile,xml.etree.ElementTree as ET
import threading,http.cookiejar
from concurrent.futures import ThreadPoolExecutor,wait,FIRST_COMPLETED
from datetime import datetime,timezone
from pathlib import Path
from pypdf import PdfReader
from pypdf.errors import EmptyFileError,PdfReadError
from probe_skku_public_educational_plan import NoSavePublic,params,P,FIELDS
from skku_public import UA,REFERER
PRIVATE=re.compile(r'@|(?:\+82[- ]?)?0\d{1,2}[- .]\d{3,4}[- .]\d{4}|PER_ID|GYOGANGSA_ID|담당자번호|연락처|E-mail|email|Phone|전화번호|[?&](?:pwd|token|sessionid|access_token)=|(?:비밀번호|암호|password|passwd)\s*[:=]',re.I)
SIGNAL=re.compile(r'휴강|휴업|보강|추석|한글날|건학|공부자|모듈|module|집중|대면|비대면|온라인|오프라인|화상|동영상|영상강의|플립|사전학습|사전\s*학습|현장|개별|실습|수강|이수.*제한|선수과목|견학|답사|교외|대체출석|수업\s*없|no\s+(?:class|lecture)|cancel(?:led|ed)?|make[- ]?up|holiday|remote|online|off[- ]?line|flipped|intensive|field\s+trip|excursion|prerequisite|only.{0,20}student|\b\d{1,2}[./]\d{1,2}\b|\b\d{1,2}:\d{2}\b|\d{1,2}\s*월\s*\d{1,2}\s*일',re.I)
TERM_HEADER=re.compile(r'\b(?:Fall|Autumn|Spring|Summer|Winter)\s+(?:semester\s+)?20\d{2}\b|\b20\d{2}\s*(?:년\s*)?[-/]?\s*[12]\s*학기\b|\b20\d{2}\s*(?:Fall|Autumn|Spring|Summer|Winter)\b',re.I)
MONTH_DATE=re.compile(r'\b(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\.?\s*\d{1,2}(?:st|nd|rd|th)?\b',re.I)
CATALOG_FIELDS=('GAESUL_YEAR','GAESUL_TERM','CAMPUS_GB','CAMPUS_NM','HAKWI_NAME','JUKYONGHAKWI_GB','GRADE_NAME','ISU_NAME','HAKSU_NO','BUNBAN','HAKSU_NO_BUNBAN','GWAMOK_NAME','GWAMOK_ENG_NAME','HAKJUM','PER_NAME','GYOSI_NAME','HYUNGTAE','BIGO','SUUP_TYPE_CD','SUUP_TYPE_NM','BOKSUJUNGONG_YN_NAME','ABEEK_YN','ISU_NAME2','ISU_NAME3','HAKBU_JIBJUNG_GB','HAKBU_JIBJUNG_GB_NM','LECTURE_PLAN_TYPE','INFORM')
LAST_REQUEST=0.0
REQUEST_LOCK=threading.Lock()
STOP_REQUESTS=threading.Event()
def request_start():
    global LAST_REQUEST
    with REQUEST_LOCK:
        if STOP_REQUESTS.is_set():raise RuntimeError('Single-owner collection already stopped')
        time.sleep(max(0,.8-(time.monotonic()-LAST_REQUEST)))
        if STOP_REQUESTS.is_set():raise RuntimeError('Single-owner collection already stopped')
        LAST_REQUEST=time.monotonic()
class SpacedPublic(NoSavePublic):
    def __init__(self,lang='EN',prefix='skku-'):
        self.prefix=prefix
        self.op=urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        request_start()
        self.op.open(urllib.request.Request(REFERER,headers={'User-Agent':UA}),timeout=30).read()
        self.post('/E_NCommon/sessionLogin',{'langCd':lang},'anonymous-language-bootstrap',save=False)
    def post(self,*args,**kwargs):
        request_start()
        return super().post(*args,**kwargs)
    def download(self,url):
        request_start()
        response=self.op.open(urllib.request.Request(url,headers={'User-Agent':UA,'Referer':REFERER}),timeout=45)
        if response.status!=200:raise RuntimeError('Non-success public download')
        body=response.read()
        beginning=body[:1024].lstrip().lower()
        if beginning.startswith((b'<!doctype html',b'<html')) or any(signal in beginning for signal in (b'access denied',b'web application firewall',b'captcha',b'cf-chl-')):
            raise RuntimeError('Unexpected public HTML/protection response; single-owner collection stopped')
        return body
def education(value):
    lines=str(value or '').splitlines();kept=[];suppressed=0
    for line in lines:
        if PRIVATE.search(line):suppressed+=1
        else:kept.append(line)
    return '\n'.join(kept),suppressed
def text_evidence(text,code,section,professor):
    safe,suppressed=education(text);contexts=[];truncated=False
    # Many school PDFs extract a page as one line. Capture each actual marker's
    # nearby sentence, not the first650 chars of that unrelated full page.
    for match in list(SIGNAL.finditer(safe))+list(TERM_HEADER.finditer(safe))+list(MONTH_DATE.finditer(safe)):
        start=max(0,match.start()-230);end=min(len(safe),match.end()+300)
        context=re.sub(r'\s+',' ',safe[start:end]).strip()
        if context not in contexts:contexts.append(context)
    return {'headerCourseCodePresent':code in safe,'year2026Present':bool(re.search(r'2026',safe)),'currentTermPresent':bool(re.search(r'2026.{0,100}(?:2\s*학기|Fall|Autumn)|(?:2026-2|2026/2)',safe,re.I|re.S)),'explicitAcademicTermMarkers':list(dict.fromkeys(m.group(0) for m in TERM_HEADER.finditer(safe))),'catalogProfessorPresent':professor in safe if professor else False,'educationalOperatingContexts':contexts[:100],'contextLimitReached':len(contexts)>100,'contextTruncated':False,'privacySuppressedLineCount':suppressed}
class ProtectedPdfEducationalSource(ValueError):pass
def pdf_evidence(body,code,section,professor):
    reader=PdfReader(io.BytesIO(body))
    if reader.is_encrypted:raise ProtectedPdfEducationalSource('Encrypted public PDF is left unread without password attempts')
    text='\n'.join(page.extract_text() or '' for page in reader.pages)
    return {**text_evidence(text,code,section,professor),'pages':len(reader.pages),'byteCount':len(body),'educationalParserVersion':3}
def docx_evidence(body,code,section,professor):
    with zipfile.ZipFile(io.BytesIO(body)) as archive:
        info=archive.getinfo('word/document.xml')
        if info.file_size>20_000_000:raise ValueError('Public educational XML beyond expected bound')
        root=ET.fromstring(archive.read(info))
        text='\n'.join(''.join(n.itertext()) for n in root.iter('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}p'))
    return {**text_evidence(text,code,section,professor),'byteCount':len(body),'educationalParserVersion':3}
def fetch_record(p,row):
    offering=row['HAKSU_NO_BUNBAN']
    code,section=row['HAKSU_NO'],row['BUNBAN'];record={'educationalParserVersion':3,'offeringCode':offering,'sourceRow':{k:row.get(k) for k in CATALOG_FIELDS},'detail':[],'weekly':[],'attachments':[]}
    detail=p.post('/E_NHSSU900011P/selectMain0',params(code,section,'selectMain0','dsInfoTab01'),'',save=False).get('dsInfoTab01',[])
    for d in detail:
        safe={};suppressed=0
        for k in FIELDS:
            value,n=education(d.get(k));safe[k]=value;suppressed+=n
        safe['privacySuppressedLineCount']=suppressed;record['detail'].append(safe)
    record['currentDetailIdentityConfirmed']=bool(detail) and all(d.get('GAESUL_YEAR')=='2026' and d.get('GAESUL_TERM')=='20' and d.get('HAKSU_NO')==code and d.get('BUNBAN')==section for d in detail)
    if detail and detail[0].get('INPUT_TYPE_GB')=='1':
        files=p.post('/E_NHSSU900011P/selectFile2',params(code,section,'selectFile2','dsMyFile2'),'',save=False).get('dsMyFile2',[])
        for f in files:
            fileid=f.get('BIZ_PLN_FILE_ID')
            if not fileid:continue
            q={'FILE_ID':fileid,'_TRANSACTION_ID':'selectDsFile2','_FIRST_OUT_DS_NM':'dsFile2','_ALL_OUT_DS_NM':'dsFile2=dsFile2','_MENU_ID':'EXT_SCHEDULE','_PGM_ID':'NHSSU030840M'}
            attachments=p.post('/E_NAttachFile/selectAttachFiles',q,'',save=False).get('dsFile2',[])
            for a in attachments:
                suffix=a.get('FILE_NM','').rsplit('.',1)[-1].lower();item={'format':suffix}
                if suffix in ('pdf','docx','hwp','hwpx','pptx'):
                    url='https://kingoinfo.skku.edu/gaia/E_Nsystem/fileDownload.do?attachFileId='+a['DOWNLOAD_FILE_ID']+'&sequenceNumber='+a['FILE_SEQ']
                    body=p.download(url)
                    if suffix in ('pdf','docx'):
                        try:
                            item.update((pdf_evidence if suffix=='pdf' else docx_evidence)(body,code,section,row['PER_NAME']))
                        except ProtectedPdfEducationalSource:
                            item.update({'protectionPresent':True,'status':'Actual encrypted public PDF left unread; no password attempts or bypass.'})
                        except (EmptyFileError,PdfReadError,zipfile.BadZipFile,KeyError,ET.ParseError):
                            item['byteCount']=len(body);item['educationalContentIncomplete']=True
                            item['status']='Actual public attachment is empty or unreadable; offering remains individually blocked without retry or bypass.'
                    else:
                        from read_skku_published_office_plan import hwp_text,hwpx_text,pptx_text,ProtectedPublishedOfficeSource
                        try:
                            text={'hwp':hwp_text,'hwpx':hwpx_text,'pptx':pptx_text}[suffix](body)
                            item.update(text_evidence(text,code,section,row['PER_NAME']));item['educationalParserVersion']=3;item['byteCount']=len(body);text=None
                        except ProtectedPublishedOfficeSource:
                            item.update({'protectionPresent':True,'status':'Actual protected/distributed public HWP left unread; no bypass.'})
                        except (ValueError,KeyError,zipfile.BadZipFile):
                            item['status']='Actual public office source not safely readable with installed parser; no protection bypass or missing-current-content inference.'
                    body=None
                elif suffix=='txt':
                    url='https://kingoinfo.skku.edu/gaia/E_Nsystem/fileDownload.do?attachFileId='+a['DOWNLOAD_FILE_ID']+'&sequenceNumber='+a['FILE_SEQ'];body=p.download(url)
                    txt,n=education(body.decode('utf8',errors='replace'));item['publicStatusExcerpt']=txt[:400];item['privacySuppressedLineCount']=n;body=None
                else:item['status']='Actual public attachment exists but educational format requires separate normal review; not parsed or treated current.'
                record['attachments'].append(item)
    elif detail:
        group=p.post('/E_NHSSU900011P/selectMain01',params(code,section,'selectMain01','dsPlanWeekGb'),'',save=False).get('dsPlanWeekGb',[])
        weektype=group[0].get('PLAN_WEEK_GB') if group else None;record['weekType']=weektype
        weekly=p.post('/E_NHSSU900011P/selectMain3',params(code,section,'selectMain3','dsTab04'),'',save=False).get('dsTab04',[])
        for w in weekly:
            if w.get('PLAN_WEEK_GB')!=weektype:continue
            safe={};suppressed=0
            for k in ('GAESUL_YEAR','GAESUL_TERM','HAKSU_NO','BUNBAN','PLAN_WEEK_GB','PLAN_WEEK_CNT','PLAN_WEEK_CONT','BIGO'):
                safe[k],n=education(w.get(k));suppressed+=n
            safe['privacySuppressedLineCount']=suppressed;record['weekly'].append(safe)
    detail=None;record['status']='Actual current public educational evidence fetched; per-course operation review still required.'
    return record

def stopped_worker(p,row):
    try:return fetch_record(p,row)
    except BaseException:
        STOP_REQUESTS.set();raise

if __name__=='__main__':
    source=json.loads((P/'skku-ko-all-2026-2.json').read_text())['records'];source=[r for r in source if r['JUKYONGHAKWI_GB']!='05'];assert len(source)==2782
    path=P/'skku-public-operating-plan-audit.json';audit=json.loads(path.read_text()) if path.exists() else {'researchOnly':True,'completionClaim':False,'total':2782,'records':[],'stopped':False,'allCurrentDetailsFetched':False}
    done={r['offeringCode'] for r in audit['records']};assert len(done)==len(audit['records'])
    def save():
        audit['updatedAt']=datetime.now(timezone.utc).isoformat();audit['count']=len(done);tmp=path.with_suffix('.tmp');tmp.write_text(json.dumps(audit,ensure_ascii=False,indent=2));tmp.replace(path)
    pool=None
    try:
        audit['stopped']=False;audit.pop('failureType',None);audit.pop('failure',None)
        audit['collectionPolicy']={'maximumAnonymousSessions':2,'maximumConcurrentOfferings':2,'globalMinimumRequestStartIntervalSeconds':.8,'singleCheckpointWriter':True,'noAutomaticRetry':True}
        remaining=iter(row for row in source if row['HAKSU_NO_BUNBAN'] not in done)
        clients=[SpacedPublic('KO'),SpacedPublic('KO')]
        pool=ThreadPoolExecutor(max_workers=2);pending={}
        for index,client in enumerate(clients):
            row=next(remaining,None)
            if row is not None:pending[pool.submit(stopped_worker,client,row)]=index
        while pending:
            completed,_=wait(pending,return_when=FIRST_COMPLETED)
            for future in completed:
                index=pending.pop(future);record=future.result();offering=record['offeringCode'];assert offering not in done
                audit['records'].append(record);done.add(offering);save()
                if len(done)%25==0:print('Educational offering audit',len(done),'of',len(source),flush=True)
                if not STOP_REQUESTS.is_set():
                    row=next(remaining,None)
                    if row is not None:pending[pool.submit(stopped_worker,clients[index],row)]=index
        audit['allCurrentDetailsFetched']=True;save()
    except BaseException as error:
        STOP_REQUESTS.set();audit['stopped']=True;audit['failureType']=type(error).__name__;audit['failure']='Normal public request/parsing stopped; no private exception text, bypass or automatic retry.';save();raise SystemExit(1)
    finally:
        STOP_REQUESTS.set()
        if pool is not None:pool.shutdown(wait=True,cancel_futures=True)
