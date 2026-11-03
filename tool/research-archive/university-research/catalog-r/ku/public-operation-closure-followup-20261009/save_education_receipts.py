import hashlib,io,json
from pathlib import Path
from html.parser import HTMLParser
import openpyxl,pdfplumber
R=Path(__file__).parent
class P(HTMLParser):
 def __init__(self):super().__init__();self.parts=[];self.skip=0
 def handle_starttag(self,t,a):
  if t in ('script','style'):self.skip+=1
 def handle_endtag(self,t):
  if t in ('script','style'):self.skip-=1
 def handle_data(self,s):
  if not self.skip:self.parts.append(s)
def src(k,u):
 b=Path('/tmp/ku-'+k+'-20261009.html').read_bytes();p=P();p.feed(b.decode());return ' '.join(' '.join(p.parts).split()),dict(sourceUrl=u,normalHttpStatus=200,sourceSha256=hashlib.sha256(b).hexdigest(),retrievedDate='2026-10-09')
def save(n,d):(R/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
fc,fr=src('fcguide','https://www.korea.ac.kr/jsp/sugang/guide/college/A004.html')
nm,nr=src('nemo','https://ctl.korea.ac.kr/ctl/elearning/nemo.do')
assert '총 강의시간의 1/3 에서 1/2 까지 온라인으로 구성 가능' in fc
assert '그 후에 진행되는 출석수업에서는 토론 및 연습' in fc
assert '실시간으로 송출' in nm
save('fc-nemo-official-operation-education.json',dict(researchOnly=True,completionClaim=False,currentLegendSource='work/university-research/root-ku-normal-ui-20261009/current-course-badge-legend-education.json',currentLegendYear=2026,currentLegendSemester='2R',sources=[dict(**fr,nativeFC=['FC(Flipped Class)','수업자료 사전 LMS 학습 후 출석수업에서 토론 및 연습','총 강의시간의 1/3 에서 1/2 까지 온라인으로 구성 가능'],nativeNeMo=['메인강의실에서 강의하고 서브강의실에서는 온라인으로 강의를 듣는 강의 형태','캠퍼스(인문계/자연계) 간 거리 불편 해소']),dict(**nr,nativeHeading='NeMo Class(온/오프라인 동시 강의)',nativeDefinition='Networked Modular Class',nativeOperation=['실시간 원격 화상강의 시스템','교수자는 일반적인 강의를 진행하며 해당 강의가 실시간으로 송출','인터넷 환경에서 각자 편한 장소의 PC/스마트폰으로 수강'])],interpretation=dict(FC='Badge is pedagogical mixture, not whole remote cancellation. Source native physical clock/room may remain a public reservation plan with unknown individual online dates/quantity; no every-date attendance or inPerson override claim. Explicit plan conflict still held.',NM='Simultaneous onsite/live stream supported, not VOD substitution. Preserve actual room scope and explicit individual plan. Do not select arbitrary main/sub room if same period ambiguous.',userThreeModes='User-selected planning mode retained when individual dated deliveryMode unpublished; mode choice is not proof that all three were officially offered.',sourcePublicationDate='General public operational policy undated; connected to current2026-2 legend, not claimed as a dated2026 revision'),privateLmsNotAccessed=True))
withdrawal,wr=src('withdrawal','https://uc.korea.ac.kr/uc/community/event.do?articleNo=1585322&mode=view')
assert '2026. 09. 23.(수) 17:00' in withdrawal and '수강인원이 0명' in withdrawal
save('seoul-third-closure-boundary-education.json',dict(**wr,researchOnly=True,nativeAcademicTerm='2026학년도 2학기',nativeThirdClosureDateTime='2026-09-23 17:00',nativeRule='수강포기로 인한 수강인원이 0명인 교과목에 한하여 3차 폐강 처리',actualThirdClosedNativeListObtained=False,knownExistingSeoulFirstSecondUnion=132,decision='Third phase date/rule is not proof that third list is empty or first/second complete; current whole third cancellation freshness unknown',completionClaim=False))
teacher,tr=src('teacher-policy','https://secu.korea.ac.kr/bbs/sti/145/270442/artclView.do')
zero,zr=src('teacher-zero-rule','https://libart.korea.edu/libart_en/community/notice.do?articleNo=346197&mode=view')
assert '2026학년도 2학기' in teacher and '08:40' in teacher
assert 'in conjunction with the 1' in zero
save('teacher-zero-specific-policy-education.json',dict(researchOnly=True,completionClaim=False,sources=[dict(**tr,nativeCurrentTerm='2026학년도2학기',nativePublishedDate='2026-06-22',nativeScope='강의시간(서울캠퍼스)',nativeException='교직과목 0 교시 설정 수업 시간: 08:40~'),dict(**zr,nativeEffectiveFrom='2023 fall semester',nativePolicy='For a teacher training course, the 0th period begins at08:40 and is operated in conjunction with the1st period')],decision='Teacher0 is a specific08:40 exception. Generic0 08:00–08:50 currenttable must not overwrite it. Standalone teacher0 end unpublished; do not invent08:50 or09:30. Source-specific direct clock or explicit0+1 grouping needed. No current native rows altered.',currentGenericClockReceipt='work/university-research/catalog-r/ku/current-whole-public-followup-v2-20261009/current-2026-2-campus-clock-education.json'))
notice,sr=src('sejong-closure','https://sti.korea.ac.kr/bbs/koreaSejong/656/272717/artclView.do')
x=Path('/tmp/ku-sejong-182421-20261009.bin').read_bytes();p=Path('/tmp/ku-sejong-182420-20261009.bin').read_bytes()
s=openpyxl.load_workbook(io.BytesIO(x),data_only=True).worksheets[0]
rows=[]
for rr in range(4,57):
 v=[c.value for c in s[rr]];assert v[0:3]==['2026','2학기','세종'] and v[10]=='폐강'
 rows.append(dict(sourceRow=rr,sourceEducationalCells=v,nativeCode=v[6],nativeSection=v[7],identity=v[6]+'-'+v[7]))
with pdfplumber.open(io.BytesIO(p)) as pdf:
 kr=[row for pg in pdf.pages[:3] for row in pg.extract_tables()[0][1:]]
 en=[row for pg in pdf.pages[3:] for row in pg.extract_tables()[0][1:]]
assert len(kr)==len(en)==len(rows)==53
ids={(v['nativeCode'],v['nativeSection']) for v in rows}
assert ids=={(v[6],v[7]) for v in kr}=={(v[6],v[7]) for v in en}
assert len(ids)==53
save('sejong-current-53-closure-education.json',dict(**sr,researchOnly=True,completionClaim=False,nativeTitle=s['A1'].value,nativePublishedDate='2026-09-10',scope='Current2026-2 Sejong undergraduate only; not Seoul, not guessed third-phase current status',noticeObservedAttachments=['https://sti.korea.ac.kr/bbs/koreaSejong/656/182420/download.do','https://sti.korea.ac.kr/bbs/koreaSejong/656/182421/download.do'],pdfSha256=hashlib.sha256(p).hexdigest(),xlsxSha256=hashlib.sha256(x).hexdigest(),normalDownloadStatus=200,nativeHeader=[c.value for c in s[3]],nativeCancelledOfferings=53,uniqueNativeIdentities=53,independentPdfKoreanIdentitiesMatch=True,independentPdfEnglishIdentitiesMatch=True,nativeSectionLeadingZerosAndLettersRetained=True,rows=rows,latestWholeClosureVerified=False))
print('FC/NM, teacher0, third-rule, Sejong53 receipt saved; xlsx/PDF kr/en53 match')
