"""Whitelist current educational course plans from officially linked faculty publication."""
from html.parser import HTMLParser
from pathlib import Path
from datetime import date
import re,json,hashlib
R=Path(__file__).parent
class Node:
 def __init__(self,tag,attrs=None):self.tag=tag;self.attrs=dict(attrs or []);self.children=[]
 def nodes(self):
  yield self
  for c in self.children:
   if isinstance(c,Node):yield from c.nodes()
 def has(self,cls):return cls in self.attrs.get('class','').split()
 def text(self,skip=None):
  if self.tag in ['script','style'] or (skip and skip(self)):return ''
  return re.sub(r'\s+',' ',' '.join(c.text(skip) if isinstance(c,Node) else c for c in self.children)).strip()
class Parser(HTMLParser):
 def __init__(self):super().__init__(convert_charrefs=True);self.root=Node('root');self.stack=[self.root]
 def handle_starttag(self,t,a):
  n=Node(t,a);self.stack[-1].children.append(n)
  if t not in ['area','base','br','col','embed','hr','img','input','link','meta','param','source','track','wbr']:self.stack.append(n)
 def handle_startendtag(self,t,a):self.stack[-1].children.append(Node(t,a))
 def handle_endtag(self,t):
  for i in range(len(self.stack)-1,0,-1):
   if self.stack[i].tag==t:self.stack=self.stack[:i];break
 def handle_data(self,d):self.stack[-1].children.append(d)
def tree(p):q=Parser();q.feed(p.read_text());return q.root
skip=lambda n:n.tag=='button' or 'hidden' in n.attrs or n.has('slides') or n.has('tag-online') or n.has('tag-exam')
plans=[]
for slug in ['uni111','cse480']:
 p=Path('/private/tmp/unist-current-'+slug+'-response');root=tree(p);nodes=list(root.nodes());hero=next(n for n in nodes if n.has('hero'));eyebrow=next(n for n in hero.nodes() if n.has('hero-eyebrow')).text();title=next(n for n in hero.nodes() if n.tag=='h1').text();sub=next(n for n in hero.nodes() if n.has('hero-sub')).text();intro=next(n for n in nodes if n.attrs.get('id')=='about');facts={}
 for n in intro.nodes():
  if n.tag=='div':
   bs=[x for x in n.children if isinstance(x,Node) and x.tag=='b'];spans=[x for x in n.children if isinstance(x,Node) and x.tag=='span']
   if len(bs)==1 and len(spans)==1 and bs[0].text() in ['Time','Location','For']:facts[bs[0].text()]=spans[0].text()
 assert 'Fall 2026' in eyebrow and slug.upper() in eyebrow
 if slug=='uni111':prof='Seongil Wi';role='Coordinator';assert 'Coordinator' in intro.text() and 'Prof. Seongil Wi' in intro.text();assert facts['For']=='First-year students';start=960;end=1035;room='104-E206'
 else:
  staff=next(n for n in nodes if n.attrs.get('id')=='staff');card=next(n for n in staff.nodes() if n.has('staff-card') and any(x.has('staff-role') and x.text()=='Instructor' for x in n.nodes()));prof=next(n for n in card.nodes() if n.has('staff-name')).text();role='Instructor';assert prof=='Seongil Wi';start=870;end=945;room='106-T205'
 schedule=next(n for n in nodes if n.attrs.get('id')=='schedule');rows=[]
 for n in schedule.nodes():
  if 'data-date' not in n.attrs:continue
  d=n.attrs['data-date'];day=date.fromisoformat(d).isoweekday();off=next((x.text() for x in n.nodes() if x.has('off-label')),None);talk=next((x.text(skip) for x in n.nodes() if x.tag=='h3' and x.has('talk')),None);notes=[x.text() for x in n.nodes() if x.has('note')];remote=any(x.has('tag-online') and x.text()=='Online' for x in n.nodes());exam=bool(talk and talk=='Final Exam');faculty=[x.text() for x in n.nodes() if x.has('prof-name')];reasons=[]
  if off:reasons.append('explicitNoClass')
  if remote or any('recorded lecture video' in x for x in notes):reasons.append('explicitRecordedVideoNoOfflineClockAllocation')
  if exam:reasons.append('nativeFinalExamClockRoomNotSeparatelyPublished')
  if not off and not talk:raise AssertionError(d)
  rows.append({'nativeISODate':d,'nativeDisplayDate':next(x.text(skip) for x in n.nodes() if x.has('col-date')),'nativeTopic':talk or '', 'nativeFaculty':faculty,'nativeNoClassText':off or '', 'nativeEducationNotes':notes,'nativeDeliveryException':'Online / recorded lecture video' if remote else '', 'nativeKind':'exam' if exam else 'noClass' if off else 'class','heldReasons':reasons,'weekday':day})
 url='https://websec-lab.github.io/courses/2026f-'+slug+'/'
 plans.append({'sourceId':url+'#course','referenceKind':'internalDocumentLocator','sourceUrl':url,'sourceSHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'status':200,'nativeCourseHeading':eyebrow,'nativeCourseCode':slug.upper(),'nativeCourseTitle':title,'nativeCourseIntroClockRoomText':sub,'nativeFacts':facts,'nativeProfessor':prof,'nativeProfessorRole':role,'nativeSection':'','nativeCredits':None,'nativeClassification':'','nativeRoom':room,'startMinute':start,'endMinute':end,'educationDateRows':rows,'actualAttendanceConfirmed':False,'rawBodySaved':False})
calp=Path('/private/tmp/unist-current-calendar-public-json-response');cal=json.loads(calp.read_text());educ=[{'nativeTitle':r['content'],'startDate':r['beginDt'],'endDate':r['endDt']} for r in cal['data'] if r['beginDt']>='2026-08-01' and (any(k in r['content'] for k in ['개강','종강','공휴일','추석','중간고사','기말고사','개원기념일']) or r['content']=='겨울방학')]
assert any(x['startDate']=='2026-08-31' and '개강' in x['nativeTitle'] for x in educ);assert any(x['startDate']=='2026-12-18' and '종강' in x['nativeTitle'] for x in educ)
proof=[]
for name,url in [('cse-lab','https://cse.unist.ac.kr/cse/research/lab.do?article.offset=20&articleLimit=10&mode=list'),('official-faculty','https://cse.unist.ac.kr/cse/people/people.do?mode=view&profSeq=345'),('undergraduate-subjects','https://cse.unist.ac.kr/cse/education/undergraduate-program/subjects01.do'),('faculty-teaching','https://seongil-wi.github.io/')]:
 p=Path('/private/tmp/unist-current-'+('cse-lab' if name=='cse-lab' else name if name!='undergraduate-subjects' else 'undergraduate-subjects')+'-response');rt=tree(p);links=[{'nativeLabel':n.text(),'publicTarget':n.attrs['href']} for n in rt.nodes() if n.tag=='a' and n.attrs.get('href') in ['https://websec-lab.github.io/','https://websec-lab.github.io/courses/2026f-uni111/','https://websec-lab.github.io/courses/2026f-cse480/']];proof.append({'sourceUrl':url,'status':200,'SHA256':hashlib.sha256(p.read_bytes()).hexdigest(),'educationPublicLinks':links,'nativeScope':'학부/undergraduate CSE480 컴퓨터공학특론Ⅰ' if name=='undergraduate-subjects' else 'Seongil Wi / Web Security Lab' if name in ['cse-lab','official-faculty'] else 'Teaching 2026F UNI111 Coordinator / CSE480'})
undergraduate=tree(Path('/private/tmp/unist-current-undergraduate-subjects-response')).text();assert re.search(r'CSE480\s+컴퓨터공학특론Ⅰ',undergraduate)
proof[2]['nativeUndergraduateEntry']={'code':'CSE480','nativeTitle':'컴퓨터공학특론Ⅰ','nativePageScope':'학사과정 / 교과목안내'}
assert any(x['educationPublicLinks'] for x in proof[:2]);assert len(proof[-1]['educationPublicLinks'])>=2
source={'researchOnly':True,'wholeSchoolCompletionClaim':False,'officialPublicPublicationProof':proof,'coursePlans':plans,'calendar':{'sourceUrl':'https://www.unist.ac.kr/unist/education/academic/schedule.do?mode=getCalendarData&siteId=unist&start=2026-01-01&end=2027-01-01','status':200,'SHA256':hashlib.sha256(calp.read_bytes()).hexdigest(),'publicPageScript':'https://www.unist.ac.kr/_custom/unist/resource/js/app/calendar/app.view-calendar.js?74792','educationalEvents':educ,'rawBodySaved':False},'previousCalendarLeadPreservedSeparately':{'oldPublishedPdfUrl':'https://freshman.unist.ac.kr/eng/wp-content/uploads/2026/04/2026-UNIST-Academic-Calendar.pdf','normalCurrentStatus':200,'normalCurrentResponseIsPdf':False,'normalCurrentBodyTitle':'미래인재학부','indexedHistoricalPdfNotUsedAsCurrentDateProof':True,'currentCalendarDateAuthority':'currentOwnPublicCMSJSON'},'privateContactsOrStaffIdsOrStudentRosterOrScoreboardOrLabAccessFieldsSaved':False,'protectedOpenCoursesOrLMSRequested':False}
p=R/'unist-current-two-faculty-plan-education-source-20261008.json';p.write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n');print([(p['nativeCourseCode'],len(p['educationDateRows']),sum(not r['heldReasons'] for r in p['educationDateRows'])) for p in plans]);print('SHA',hashlib.sha256(p.read_bytes()).hexdigest())
