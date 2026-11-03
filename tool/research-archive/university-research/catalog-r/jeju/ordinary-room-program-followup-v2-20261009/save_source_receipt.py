"""Keep only current educational calendar text, never contacts or page scripts."""
import json, hashlib, re
from pathlib import Path
from html.parser import HTMLParser
R=Path(__file__).parent
class Text(HTMLParser):
    def __init__(self):
        super().__init__();self.parts=[];self.skip=0
    def handle_starttag(self,t,a):
        if t in ['script','style']: self.skip+=1
    def handle_endtag(self,t):
        if t in ['script','style']: self.skip-=1
    def handle_data(self,d):
        if not self.skip and d.strip(): self.parts.append(d.strip())
receipts=[]
for name,url in [('future','https://fc.jejunu.ac.kr/fc/academic.htm'),('vet-calendar','https://vetmed.jejunu.ac.kr/vetmedmain/degree/schedule.htm'),('medical-calendar','https://medical.jejunu.ac.kr/medical/guide/schedule.htm')]:
    b=Path('/tmp/jeju-'+name+('-current' if name=='future' else '')+'.html').read_bytes()
    t=Text();t.feed(b.decode());text=' '.join(t.parts)
    start=text.index('09.01(화) 2학기 개시일')
    end=text.index('번역 안내',start)
    excerpt=text[start:end]
    # Keep undergraduate calendar fields and footnotes; exclude graduate entries.
    excerpt=re.sub(r'\d{2}\.\d{2}\([^)]*\)(?: ~ \d{2}\. \d{2}\([^)]*\))? \(대학원\).*?(?=\d{2}\.\d{2}\([^)]*\)|1\) 의과대학)', '', excerpt)
    receipts.append(dict(sourceUrl=url,normalHttpStatus=200,checkedDate='2026-10-09',sourceSha256=hashlib.sha256(b).hexdigest(),displayedYear=2026,educationalCalendarExcerpt=excerpt))
result=dict(researchOnly=True,completionClaim=False,sources=receipts,currentGuideNormalRecheck=dict(sourceUrl='https://jejunu.ac.kr/ara/noticesurvey/outEvent.htm?act=download&category=321&seq=278363&no=4',normalHttpStatus=200,sha256='833b2922d3a8356e2ad041b6455ad4e44192765939d20c9eec714c911c85242a',sameAsFrozen=True),scopeDecisions=dict(veterinary='Current school/college calendar lists medical separate calendar, not veterinary; v1 substring 의과대학 incorrectly matched 수의과대학. Only native weekday/known clock/direct room and no source contradictions released.',futureConvergence='Own current 2026 calendar directly supplies ordinary Sep1/midterm/makeup windows. Exception names finals/semesterend next Saturday only. Reserve weekday pre-makeup slots; Saturday clock application unproven held.',medical='Current medical calendar displays generic calendar plus explicit separate medical-calendar warning. Current home course notices link portal login. No separate actual medical operation dates available, all49 retained held.',roomCorrespondence='Only exact room-first runs or exact day-period[room] pairs. Blank rooms, unmatched substrings, overlapping different rooms or times held. No per-department campus inference.',remoteBlended='133 remote /182 mixed held unchanged; guide distinguishes remote exam-only clocks from instruction; no untimed online conversion.',latestWholeFreshness='Current published guide bytes unchanged. Whole July29 catalog and later portal changes/closure census not currently verified.'),authUsed=False,privateApiUsed=False)
(R/'current-program-clock-source-receipt.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
