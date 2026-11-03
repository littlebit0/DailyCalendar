"""Normal anonymous public SAP lookup; session/signature values stay in memory."""
import hashlib
import html
import http.cookiejar
import io
import json
import re
import subprocess
import sys
import argparse
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).parent
ENTRY = 'https://sis109.sogang.ac.kr/sap/bc/webdynpro/sap/zcmw9016?sap-language=KO'
HEADERS = {'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36', 'Accept-Language': 'ko-KR,ko;q=0.9', 'Accept': 'text/html,application/xml,*/*'}
FIELDS = ['year','semester','division','department','subjectCode','section','title','syllabus','credit','meetingText','hours','professor','enrollment','english','chinese','approval','CU','HUSS','CI','oddEven','international','honors','cyber','exam','target','recommendedGrade','registrationRemarks','description','remarks']
SOURCE_LABELS = ['학년도','학기','소속','학과','과목번호','분반','과목명','강의계획서','학점','수업시간/강의실','시간','교수진','수강생수','영어강의','중국어강의','승인과목','CU','HUSS','CI','홀짝구분','국제학생','Honors','사이버강의','시험일자','수강대상','권장학년','수강신청 참조사항','과목 설명','비고']


def rendered(response):
    parts = re.findall(r'<!\[CDATA\[(.*?)\]\]>', response, re.S)
    return '\n'.join(parts) if parts else response


def rows(response):
    result = []
    content=rendered(response)
    clean=lambda value:re.sub(r'\s+',' ',html.unescape(re.sub('<[^>]+>',' ',value)).replace('\xa0',' ')).strip()
    headers=[clean(value) for value in re.findall(r'<th\b[^>]*role="columnheader"[^>]*>(.*?)</th>',content,re.S)]
    if not headers:
        return []
    mapping=dict(zip(SOURCE_LABELS,FIELDS))
    if len(headers)!=len(set(headers)) or any(label not in mapping for label in headers):
        raise ValueError('Unrecognized current public table headers')
    fields=[mapping[label] for label in headers]
    for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>', content, re.S):
        cells = re.findall(r'<td\b[^>]*role="gridcell"[^>]*>(.*?)</td>', row, re.S)
        if len(cells) != len(fields):
            continue
        values = [html.unescape(re.sub('<[^>]+>', ' ', c)).replace('\xa0', ' ').strip() for c in cells]
        record = dict(zip(fields, values))
        if not re.fullmatch(r'[A-Z]+\d+', record.get('subjectCode', '')):
            continue
        # Public instructor names are educational metadata; no identifiers or contacts.
        record.pop('enrollment', None)
        record.pop('syllabus', None)
        plan_cell = cells[fields.index('syllabus')] if 'syllabus' in fields else ''
        button = re.search(r'<div\b[^>]*id="([^"]+)"[^>]*role="button"', plan_cell)
        result.append((record, button.group(1) if button else None))
    return result


def same_educational_value(field, left, right):
    if left == right:
        return True
    if field != 'exam':
        return False
    # The public narrow search can reorder a set of exam rooms. Compare that
    # set only; a changed date, time or actual room must still stop collection.
    def room_sets(value):
        return re.sub(r'\[([^\]]+)\]', lambda m: '[' + ','.join(sorted(m[1].split(','))) + ']', value)
    return room_sets(left) == room_sets(right)


class PublicClient:
    def __init__(self):
        self.opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        self.action = ENTRY
        self.data = {}
        self.response = ''
        self.last_request = 0.0
        self._request(ENTRY)
        self.events([('LoadingPlaceHolder','Load',{'Id':'_loadingPlaceholder_'})])

    def _request(self, url, payload=None):
        delay = .8 - (time.monotonic() - self.last_request)
        if delay > 0:
            time.sleep(delay)
        self.last_request = time.monotonic()
        headers = dict(HEADERS, Referer=ENTRY)
        if payload is not None:
            headers.update({'Origin':'https://sis109.sogang.ac.kr','X-Requested-With':'XMLHttpRequest','X-XHR-Logon':'accept','Content-Type':'application/x-www-form-urlencoded'})
        with self.opener.open(urllib.request.Request(url, data=payload, headers=headers), timeout=35) as response:
            data = response.read(32000001)
        if len(data) > 32000000:
            raise ValueError('Public response exceeded bounded size')
        text = data.decode('utf-8')
        if any(marker in text.lower() for marker in ('access denied','web application firewall','too many requests')):
            raise ValueError('Protection response; stop normal collection')
        self.response = text
        # Initial HTML includes script CDATA too; parse its real form first.
        # Delta responses instead put the replacement form inside CDATA.
        form = re.search(r'<form\b[^>]*action="([^"]+)"[^>]*>(.*?)</form>', text, re.S)
        if form is None:
            form = re.search(r'<form\b[^>]*action="([^"]+)"[^>]*>(.*?)</form>', rendered(text), re.S)
        if form:
            self.action = urllib.parse.urljoin(ENTRY, html.unescape(form.group(1)))
            self.data = {html.unescape(n):html.unescape(v) for n,v in re.findall(r'name="([^"]+)" value="([^"]*)"', form.group(2))}
        return text

    def events(self, events):
        queue = ''.join(control+'_'+event+'\ue002'+'\ue005'.join(k+'\ue004'+str(v) for k,v in parameters.items())+'\ue003' for control,event,parameters in events)
        queue += '\ue002ResponseData\ue004delta\ue005ClientAction\ue004submit\ue003\ue002\ue003'
        self.data['SAPEVENTQUEUE'] = ''.join(c if c.isascii() and (c.isalnum() or c in '-_.') else '~'+format(ord(c),'04X') for c in queue)
        return self._request(self.action, urllib.parse.urlencode(self.data).encode())

    def whole(self):
        self.events([('ComboBox','Select',{'Id':'WD88','Key':'30000002','ByEnter':'false'})])
        return rows(self.events([('Button','Press',{'Id':'WDCA'})]))

    def course(self, code):
        if not getattr(self,'code_search_selected',False):
            self.events([('RadioButton','Change',{'Id':'WD6C','Checked':'true'})])
            self.code_search_selected=True
        self.events([('InputField','Change',{'Id':'WD7D','Value':code})])
        return rows(self.events([('Button','Press',{'Id':'WDCA'})]))

    def close_plan(self):
        buttons=[m.group(1) for m in re.finditer(r'<div[^>]*id="([^"]+)"[^>]*role="button"[^>]*>(.*?)</div>',rendered(self.response),re.S) if re.sub(r'\s+',' ',html.unescape(re.sub('<[^>]+>',' ',m.group(2)))).strip()=='확인 강조']
        if len(buttons)!=1:
            raise ValueError('Current public modal close button not identified')
        self.events([('Button','Press',{'Id':buttons[0]})])

    def pdf_probe(self, button):
        response = self.events([('Button','Press',{'Id':button})])
        links = [html.unescape(value) for value in re.findall(r'href="([^"]+)"',rendered(response))]
        links = [value for value in links if urllib.parse.urlsplit(value).hostname=='sis139.sogang.ac.kr' and urllib.parse.urlsplit(value).path=='/ContentServer/ContentServer.dll']
        if len(links)!=1:
            raise ValueError('Current public document link not uniquely identified')
        # Use only the current anonymous response's document link, never an old
        # saved signature or any authenticated student session.
        delay=.8-(time.monotonic()-self.last_request)
        if delay>0:
            time.sleep(delay)
        self.last_request=time.monotonic()
        with self.opener.open(urllib.request.Request(links[0],headers=HEADERS),timeout=35) as result:
            content=result.read(12000001)
        if len(content)>12000000 or not content.startswith(b'%PDF-'):
            raise ValueError('Public plan was not a bounded PDF')
        python='/Users/kimhwi/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3'
        parser='import io,json,sys; from pypdf import PdfReader; r=PdfReader(io.BytesIO(sys.stdin.buffer.read())); print(json.dumps({"pages":len(r.pages),"text":"\\n".join(p.extract_text() or "" for p in r.pages)},ensure_ascii=False))'
        extracted=json.loads(subprocess.run([python,'-c',parser],input=content,capture_output=True,check=True,timeout=40).stdout)
        text=extracted['text']
        text=re.sub(r'https?://\S+','[link omitted]',text)
        text=re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}','[contact omitted]',text)
        text=re.sub(r'(?<!\d)(?:\+82[- .]?)?\(?0\d{1,2}\)?[- .]+\d{3,4}[- .]\d{4}(?!\d)','[contact omitted]',text)
        text='\n'.join(line for line in text.splitlines() if not re.match(r'^\s*(?:Office:|Office Hours:|E-mail:|Homepage:)',line))
        return {'pages':extracted['pages'],'fileSha256':hashlib.sha256(content).hexdigest(),'educationalText':text,'documentUrlSaved':False,'operatingApproval':False}


def preflight():
    client = PublicClient()
    current = client.whole()
    if len(current)!=1541:
        text=rendered(client.response)
        print('Debug public response bytes',len(text),'tr',len(re.findall(r'<tr\b',text)),'gridcell',text.count('gridcell'),'formfields',len(client.data),'controlIds',re.findall(r'<control-update id="([^"]+)"',client.response)[:12],flush=True)
    assert len(current) == 1541, len(current)
    assert len({(r['subjectCode'],r['section']) for r,b in current}) == len(current)
    assert all(r['year']=='2026 학년도' and r['semester']=='2학기' and r['division']=='대학' for r,b in current)
    old = {(r['subjectCode'],r['section']):r for r in json.loads((ROOT/'sogang-2026-2.json').read_text())['records']}
    changed = []
    for record,button in current:
        previous = old.get((record['subjectCode'],record['section']))
        if previous is None or any(previous.get(k)!=v for k,v in record.items()):
            changed.append({'courseCode':record['subjectCode'],'section':record['section'],'changedFields':[k for k,v in record.items() if previous is None or previous.get(k)!=v]})
    public = {'checkedAt':'2026-10-08','sourceUrl':ENTRY,'completionClaim':False,'records':[r for r,b in current]}
    (ROOT/'sogang-current-educational-20261008.json').write_text(json.dumps(public,ensure_ascii=False,indent=2)+'\n')
    limited = client.course('AAS1001')
    assert limited and all(r['subjectCode']=='AAS1001' for r,b in limited), len(limited)
    audit = {'checkedAt':'2026-10-08','completionClaim':False,'currentWhole':len(current),'sourceMetadataChanges':changed,'normalCodeQueryMatches':len(limited),'normalCodeQueryResponseBytes':len(client.response.encode()),'operatingApproval':False,'publicLibraryEventEvidence':'SAP classes.js RadioButton Change(Id,Checked), InputField Change(Id,Value); published current screen IDs verified.'}
    (ROOT/'sogang-current-normal-query-preflight-20261008.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
    print('Current public whole',len(current),'educational changes',len(changed),'narrow real course matches',len(limited),'response bytes',len(client.response.encode()),flush=True)
    if '--pdf-probe' in sys.argv:
        assert limited[0][1], 'Public syllabus button missing'
        plan=client.pdf_probe(limited[0][1])
        plan.update({'courseCode':'AAS1001','section':limited[0][0]['section'],'checkedAt':'2026-10-08','sourceUrl':ENTRY})
        (ROOT/'sogang-aas1001-current-public-plan-probe-20261008.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n')
        print('Current public PDF pages',plan['pages'],'educational text length',len(plan['educationalText']),flush=True)
        client.close_plan()
        next_course=client.course('AAS2016')
        assert len(next_course)==1 and next_course[0][0]['subjectCode']=='AAS2016'
        print('Published modal close and next normal course lookup passed',flush=True)


def collect(limit):
    client=PublicClient()
    whole=client.whole()
    if len(whole)!=1541 or len({(r['subjectCode'],r['section']) for r,b in whole})!=1541:
        raise ValueError('Current whole scope changed; review before continuing')
    expected={(r['subjectCode'],r['section']):r for r,b in whole}
    directory=ROOT/'sogang-current-public-plan-education'
    directory.mkdir(exist_ok=True)
    written=0
    for code in dict.fromkeys(r['subjectCode'] for r,b in whole):
        wanted=[key for key in expected if key[0]==code]
        if all((directory/(key[0]+'-'+key[1]+'.json')).exists() for key in wanted):
            continue
        current=client.course(code)
        if {(r['subjectCode'],r['section']) for r,b in current}!=set(wanted):
            print('Public course scope mismatch',code,'expected',wanted,'actual',[(r['subjectCode'],r['section']) for r,b in current],'gridcells',client.response.count('gridcell'),'bytes',len(client.response),flush=True)
            raise ValueError('Current per-course section scope changed')
        for record,button in current:
            key=(record['subjectCode'],record['section'])
            if any(not same_educational_value(field, value, expected[key].get(field, '')) for field, value in record.items()):
                raise ValueError('Current course educational fields changed; review before saving')
            path=directory/(key[0]+'-'+key[1]+'.json')
            if path.exists():
                continue
            result={'checkedAt':'2026-10-08','courseCode':key[0],'section':key[1],'sourceUrl':ENTRY,'currentPublicRow':dict(expected[key], **record),'operatingApproval':False,'completionClaim':False}
            if button:
                try:
                    result.update(client.pdf_probe(button))
                except ValueError as error:
                    # Unsupported/absent public plans remain individual gaps;
                    # transport/protection errors are never swallowed here.
                    if str(error) not in ('Current public document link not uniquely identified','Public plan was not a bounded PDF'):
                        raise
                    result['publicPlanGap']=str(error)
                client.close_plan()
            else:
                result['publicPlanGap']='Current public syllabus button absent'
            temp=path.with_suffix('.tmp')
            temp.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
            temp.replace(path)
            written+=1
            print('Public plan checkpoint',key[0]+'-'+key[1],'saved',written,'cached',len(list(directory.glob('*.json'))),flush=True)
            if written>=limit:
                return


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--collect',action='store_true')
    parser.add_argument('--max-plans',type=int,default=1541)
    parser.add_argument('--pdf-probe',action='store_true')
    args=parser.parse_args()
    if args.collect:
        collect(args.max_plans)
    else:
        preflight()
