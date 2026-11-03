"""Current public educational operation checks; no contacts or full plans retained."""
import hashlib
from concurrent.futures import ThreadPoolExecutor
from threading import Event
import html
import json
from pathlib import Path
import re
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'hansung-current-operating-proofs'
OUT.mkdir(exist_ok=True)
STOP=Event()
PAGE = 'https://info.hansung.ac.kr/jsp_21/student/kyomu/'
SIGNAL = re.compile(r'답사|견학|탐방|교외|외부|워크샵|워크숍|휴업|대체|출석|소집|수업.{0,8}(?:없|않|대신)|수업.{0,8}종료|휴강|보강|보충|휴일|공휴일|추석|연휴|개천절|한글날|개교기념|영상|비디오|자율|월요일|화요일|수요일|목요일|금요일|토요일|일요일|비대면|비실시간|비동기|실시간|온라인|동영상|녹화|대면|강의실|현장|집중|계절|인턴|중간고사|기말고사|중간시험|기말시험|Zoom|ZOOM|VOD|no\s*class|holiday|make[\s-]?up|cancel|video|asynchronous|synchronous|online|face.?to.?face|in.?person|mid.?term|final.{0,8}exam|intensive|recorded|January|February|March|April|May|June|July|August|September|October|November|December|on[ -]?line|off[ -]?line|on.?site|campus|lecture.?room|field.?trip|hangeul|hangul|thanksgiving|recess|national.{0,10}day|monday|tuesday|wednesday|thursday|friday|saturday|sunday|[0-2]?\d:[0-5]\d|\d{1,2}\s*[/.월]\s*\d{1,2}\s*일?',re.I)
CONTACT = re.compile(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|(?<!\d)(?:0\d{1,2}[-. ]?)?\d{3,4}[-. ]\d{4}(?!\d)')


def plain(value):
    text = html.unescape(str(value or ''))
    text = re.sub(r'<br\s*/?>', '\n', text, flags=re.I)
    text = re.sub(r'<[^>]+>', '', text)
    text=re.sub(r'https?://\S+', '[접속링크 제외]', text)
    return CONTACT.sub('[연락처 제외]', text).strip()


def proof(payload, row):
    if payload.get('insertYn') != 'Y':
        return {'status': 'currentNotPublished'}
    values = payload.get('data', [])
    if len(values) != 1:
        raise ValueError('Unexpected public current plan count')
    d = values[0]
    for field, expected in [('data_year','2026'), ('hakgi','2'), ('kwamok',row['kwamokcode']), ('bunban',row['bunban'])]:
        if str(d.get(field,'')).strip() != expected:
            raise ValueError('Current course identity mismatch')
    weekly = []
    for i in range(1,16):
        topics = plain(d.get(f'j{i}juje'))
        # Preserve operation-bearing lines only. Subject lesson content is discarded.
        lines = [line.strip() for line in topics.splitlines() if SIGNAL.search(line)]
        weekly.append({'week':i, 'topicPublished':bool(topics), 'operatingEvidence':lines,
                       'flipped':d.get(f'j{i}f') == 'Y',
                       'makeupPlannedDate1':plain(d.get(f'j{i}bogang1')),
                       'makeupPlannedDate2':plain(d.get(f'j{i}bogang2'))})
    notes = plain(d.get('gita'))
    return {'status':'currentVerifiedIdentity', 'academicYear':2026,'semester':'2',
            'courseCode':row['kwamokcode'],'section':row['bunban'],
            'courseName':plain(d.get('kwamokname')),
            'sourceSchedule':plain(d.get('timeclassroom')),
            'sourceTarget':plain(d.get('daesang')), 'sourcePrerequisites':plain(d.get('sunsu')),
            'sourceOfflineFlag':plain(d.get('offlineyn')), 'sourceOnlineType':plain(d.get('onlinetype')),
            'sourceCreditMode':plain(d.get('onoffhakjum')),
            'operatingNotes':[line.strip() for line in notes.splitlines() if SIGNAL.search(line)],
            'weeks':weekly,'weeklyDateMeaning':'bogang is planned makeup, not ordinary teaching date'}


def retrieve(row):
    if STOP.is_set():return {'status':'accessStopped'},None
    target=OUT/f"{row['kwamokcode']}-{row['bunban']}.json"
    if target.exists():
        current=json.loads(target.read_text())
        if current.get('educationalParserVersion')==4:return current,None
    req=urllib.request.Request(PAGE+'suupplan_main_view_data.jsp',
        urllib.parse.urlencode({'type':'view','yearhakgi':'20262','code':row['plan'].strip()}).encode(),
        headers={'User-Agent':'Mozilla/5.0','Referer':PAGE+'suupplan_main_view.jsp'})
    try:
        with urllib.request.urlopen(req,timeout=30) as response: raw=response.read(8000001)
        if len(raw)>8000000:raise ValueError('Unexpected public plan response size')
        p=proof(json.loads(raw.decode('cp949')),row)
        p['sourceResponseSha256']=hashlib.sha256(raw).hexdigest()
        p['checkedDate']='2026-10-08';p['educationalParserVersion']=4
        temp=target.with_suffix('.tmp');temp.write_text(json.dumps(p,ensure_ascii=False,indent=2)+'\n');temp.replace(target)
        return p,None
    except urllib.error.HTTPError as e:
        if e.code in (401,403,429):
            STOP.set()
            raise RuntimeError(f'Public access stopped HTTP{e.code}') from None
        return {'status':'requestError'}, {'courseCode':row['kwamokcode'],'section':row['bunban'],'error':f'HTTP{e.code}'}
    except (OSError,UnicodeError,ValueError) as e:
        return {'status':'requestError'},{'courseCode':row['kwamokcode'],'section':row['bunban'],'error':type(e).__name__}
    finally:time.sleep(.75)


def main():
    rows=json.loads((ROOT/'hansung-unique-2026-2.json').read_text())
    counts={};failures=[]
    # Bounded public reads. One owner, atomic progress, no personal session.
    with ThreadPoolExecutor(max_workers=4) as pool:
        for i,(p,error) in enumerate(pool.map(retrieve,rows),1):
            if error:failures.append(error)
            counts[p['status']]=counts.get(p['status'],0)+1
            if i%50==0 or i==len(rows):
                checkpoint={'processed':i,'total':len(rows),'statuses':counts,'errors':failures,
                    'researchOnly':True,'productionReady':False,'completionClaim':False,'educationalParserVersion':4}
                cp=ROOT/'hansung-current-operating-progress.json';tmp=cp.with_suffix('.tmp');tmp.write_text(json.dumps(checkpoint,ensure_ascii=False,indent=2)+'\n');tmp.replace(cp)
                print(f'Checked{i}/{len(rows)} currentpublicplans(version4); failures{len(failures)}',flush=True)

if __name__=='__main__':main()
