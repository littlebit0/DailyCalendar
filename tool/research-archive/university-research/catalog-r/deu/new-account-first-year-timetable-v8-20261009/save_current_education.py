from pathlib import Path
from html.parser import HTMLParser
import json,hashlib,re,pdfplumber
R=Path(__file__).parent
def save(n,d):(R/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
class P(HTMLParser):
 def __init__(self):super().__init__();self.parts=[];self.links=[];self.u='';self.skip=0
 def handle_starttag(self,t,a):
  d=dict(a)
  if t=='a':self.u=d.get('href','')
  if t in ('script','style'):self.skip+=1
 def handle_endtag(self,t):
  if t=='a':self.u=''
  if t in ('script','style'):self.skip-=1
 def handle_data(self,t):
  if not self.skip:self.parts.append(t)
  if self.u and 'articleNo=' in self.u and t.strip():self.links.append(dict(nativeEducationalTitle=t.strip(),observedHref=self.u))
newpaths={
 'main':('https://www.deu.ac.kr/www/index.do','/tmp/deu-main-v8.html'),
 'commerceMenu':('https://www.deu.ac.kr/www/deu-college-of-cne.do','/tmp/deu-college-cne-v8.html'),
 'artsMenu':('https://www.deu.ac.kr/www/deu-college-of-arts.do','/tmp/deu-college-arts-v8.html'),
 'healthMenu':('https://www.deu.ac.kr/www/deu-college-of-healthcare.do','/tmp/deu-college-healthcare-v8.html'),
 'accountSearch':('https://accounting.deu.ac.kr/account/sub06_03.do?mode=list&srSearchKey=article_text&srSearchVal=%EC%8B%9C%EA%B0%84%ED%91%9C','/tmp/deu-account-time-search-v8.html'),
 'musicSearch':('https://music.deu.ac.kr/music/sub06_03.do?mode=list&srSearchKey=article_text&srSearchVal=%EC%8B%9C%EA%B0%84%ED%91%9C','/tmp/deu-music-time-search-v8.html'),
 'ptSearch':('https://pt.deu.ac.kr/pt/sub06_03.do?mode=list&srSearchKey=article_text&srSearchVal=%EC%8B%9C%EA%B0%84%ED%91%9C','/tmp/deu-pt-time-search-v8.html'),
 'currentNotice':('https://accounting.deu.ac.kr/account/sub06_03.do?mode=view&articleNo=88744','/tmp/deu-account-88744-v8.html'),
 'currentAccountRegistration':('https://accounting.deu.ac.kr/account/sub06_03.do?mode=view&articleNo=88423','/tmp/deu-account-88423-v8.html'),
 'currentMusicRegistration':('https://music.deu.ac.kr/music/sub06_03.do?mode=view&articleNo=88531','/tmp/deu-music-current-v8.html')}
receipts=[]
for key,(url,path) in newpaths.items():
 b=Path(path).read_bytes();p=P();p.feed(b.decode());v=dict(sourceKey=key,sourceUrl=url,normalHttpStatus=200,sourceSha256=hashlib.sha256(b).hexdigest())
 if key.endswith('Search'):v['returnedEducationalTitles']=[x for x in p.links if 'writer' not in x['observedHref']]
 receipts.append(v)
notice=Path('/tmp/deu-account-88744-v8.html').read_text()
assert 'attachNo=138673' in notice and 'attachNo=138674' in notice
save('new-official-navigation-education.json',dict(researchOnly=True,completionClaim=False,retrievedDate='2026-10-09',sources=receipts,observedDepartmentLinks=['https://accounting.deu.ac.kr/account/index.do','https://music.deu.ac.kr/music/index.do','https://pt.deu.ac.kr/pt/index.do'],formVerified='Observed GET action? with srSearchKey article_text option and srSearchVal. No hidden API.',currentNoticeNativeTitle='2026학년도2학기1학년신입생수강신청안내',nativeNoticeDate='2026-08-13',notOpened=['Account/password guide attachment138671','Previous protected timetable/portal routes','Existing72pages guide repeated download'],musicCurrentNoticeFinding='88531 only current registration handbook/timetable verification guide attachments, not separately posted actual course-clock table',musicAndPtSearchScope='Current exact time-table body query returned0 educational links; not proof of allsite absence'))
allrows=[]
sources=[]
for number,kind,expected in [(138673,'first-year-general',209),(138674,'first-year-major',334)]:
 b=Path('/tmp/deu-current-time-'+str(number)+'-v8.pdf').read_bytes()
 with pdfplumber.open('/tmp/deu-current-time-'+str(number)+'-v8.pdf') as pdf:
  rows=[];pages=[]
  for pageNo,page in enumerate(pdf.pages,1):
   text=page.extract_text() or '';ids=re.findall(r'\b\d{6}-\d{3}\b',text)
   lines=text.splitlines();seen=[];department=None
   heading=next((x for x in lines if x.startswith(('계열교양','균형교양','나. 전공과목'))),None)
   for lineNo,line in enumerate(lines,1):
    m=re.search(r'\b(\d{6})-(\d{3})\b',line)
    if not m:
     if kind=='first-year-major' and re.fullmatch(r'.*(?:학과|학부|전공)',line.strip()):department=line.strip()
     continue
    # The native header declares final parenthesized number as enrollment.
    # Preserve only educational cells, excluding that capacity/count field.
    education=re.sub(r'\(\d+\)\s*$','',line).strip()
    row=dict(sourceDocument=number,sourcePage=pageNo,sourceLine=lineNo,nativeDepartment=department,nativePageHeading=heading,nativeCode=m[1],nativeSection=m[2],nativeIdentity=m[0],nativeEducationalRow=education,educationalCountFieldExcluded=True,clockConversionApplied=False,datedReservationGenerated=False,sourceTerm='2026-2',scope=kind,nativeScheduleClipped=(education.count('[')!=education.count(']')))
    rows.append(row);seen.append(m[0])
   assert seen==ids
   pages.append(dict(actualPdfPage=pageNo,nativeIdentityCount=len(ids),nativeFooter=next((x for x in lines if '[Ucb0321R]' in x),None)))
  assert len(rows)==expected
  sources.append(dict(actualObservedDownloadUrl='https://accounting.deu.ac.kr/account/sub06_03.do?mode=download&articleNo=88744&attachNo='+str(number),normalHttpStatus=200,sourceSha256=hashlib.sha256(b).hexdigest(),kind=kind,actualPdfPages=len(pdf.pages),nativeRows=len(rows),pages=pages,rows=rows))
  allrows.extend(rows)
assert len(allrows)==543
unique={x['nativeIdentity'] for x in allrows}
save('current-first-year-native-543-education.json',dict(researchOnly=True,completionClaim=False,sourceNoticeUrl='https://accounting.deu.ac.kr/account/sub06_03.do?mode=view&articleNo=88744',nativeNoticeDate='2026-08-13',currentTermVerified=True,sourceDocuments=sources,totalNativeRows=543,uniqueNativeCodeSections=len(unique),campusAssociationUnverified=True,actualPerPeriodClockUnverified=True,wholeCurrentUniversityCatalog=False,scope='Freshman/currentfirst-year published timetable subset. General PDF actual9pages has originalfooter /13 and major14pages has /14. Do not claim fullallgrade offering coverage.',clippedNativeRowCount=sum(x['nativeScheduleClipped'] for x in allrows),latestClosureVerified=False,datedMeetings=0))
save('audit.json',dict(researchOnly=True,completionClaim=False,impossibleClaim=False,newNativeRows=543,newUniqueNativeIdentities=len(unique),newEligibleDatedMeetings=0,sourcePdfGeneralPages=9,sourcePdfMajorPages=14,sourcePdfGeneralOriginalFooterPageTotal=13,sourceScopeFirstYearOnly=True,oldHeld4ObjectsUnmodified=True,currentNativeClockNeeded=True,latestWholeClosureNeeded=True,actualModelThreeModeScheduledProof='Deferred; no direct undergraduate period-to-HH:mm mapping. No vacuous scheduled test claimed.',sdkUsed=False,productModified=False,authOrProtectedRouteRetried=False))
print('new native543 / unique',len(unique),'clipped',sum(x['nativeScheduleClipped'] for x in allrows))
