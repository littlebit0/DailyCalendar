import json,re
from pathlib import Path
from bs4 import BeautifulSoup
O=Path('work/all-university-completion-20261012');P=O/'b-sources'
raw=json.load(open('work/university-research/catalog-f/jbnu-course-rows.json'))
names=sorted(set(r['MNG_SCSBJT_CDNM']for r in raw));entries=[];mapped={};checked=[]
colleges={176:'간호대학',224:'경상대학',178:'공과대학',189:'농업생명과학대학',203:'사범대학',239:'사회과학대학',219:'생활과학대학',169:'수의과대학',514:'약학대학',214:'예술대학',504:'의과대학',230:'인문대학',212:'자연과학대학',506:'치과대학',223:'환경생명자원대학',1095:'AI대학'}
def norm(x):return re.sub(r'[\s.·ㆍ∙/()\-]','',x)
for idx,college in colleges.items():
 f=P/('jbnu-college-'+str(idx)+'.html');s=BeautifulSoup(f.read_text(errors='replace'),'html.parser')
 url='https://www.jbnu.ac.kr/web/unvr/university.do?unq='+str(idx);checked.append({'url':url,'sourceFile':str(f)})
 for table in s.find_all('table'):
  if '학부'not in table.get_text()or '전화'not in table.get_text():continue
  for row in table.find_all('tr'):
   cells=row.find_all('td',recursive=False)
   if not cells:continue
   label=cells[0].get_text(' ',strip=True)
   for d in names:
    if norm(d)==norm(label)or norm(label).endswith(norm(d)+'전공')or norm(d) in [norm(z)for z in label.split(' ')]or ('(구 '+d+')')in label:
     # Source's literal faculty+degree programme heading, not professor or responsible faculty.
     mapped.setdefault(d,[]).append({'college':college,'sourceUrl':url,'sourceFile':str(f),'evidence':'공식 단과대학 '+college+' 학과/전화번호 학사조직표 첫열 '+label+'와 native개설학과 '+d+' 직접대조; 전공명 축약 대응은 원문목록 전체에 동일 문자열+전공이 있는 경우만 적용','sourceLabel':d,'department':d,'university':'jbnu','campus':'*','kind':'ordinaryCollege','group':None,'officialGroups':[]})
for d,ms in mapped.items():
 cs=set(m['college']for m in ms)
 if len(cs)==1:entries.append(ms[0])

import fitz
f=O/'root-sources/jbnu-2026fall-final-handbook.pdf';url='https://www.jbnu.ac.kr/web/Board/215187/detailView.do';doc=fitz.open(f)
abbrevs={'간호대':'간호대학','경상대':'경상대학','상과대':'경상대학','공과대':'공과대학','농생대':'농업생명과학대학','사범대':'사범대학','사회대':'사회과학대학','생활대':'생활과학대학','수의대':'수의과대학','예술대':'예술대학','인문대':'인문대학','의과대':'의과대학','자연대':'자연과학대학','치과대':'치과대학','환생대':'환경생명자원대학','약학대':'약학대학','약대':'약학대학','AI대':'AI대학'}
col=None;handled={e['department']for e in entries}
for idx in range(13,32):
 for tb in doc[idx].find_tables().tables:
  rr=tb.extract()
  if not rr or '대학'not in str(rr[0])or len(rr[0])<10:continue
  for r in rr[3:]:
   if len(r)<2:continue
   c=re.sub(r'\s+','',r[0]or'');d=r[1]
   if c in colleges.values()or c in abbrevs or c=='대학본부':col=abbrevs.get(c,c)
   elif c:col=None
   if not d or not col or len(d)>100:continue
   label=re.sub(r'\s+','',d)
   label=label.replace('<재직자>','(재)')
   if label.startswith('융합기술공학부(')and label.endswith(')(재)'):label=label.removeprefix('융합기술공학부(').removesuffix(')(재)')+'(재)'
   cleanLabel=re.sub(r'\((계약학과|정원외전담학과)\)','',label)
   for n in names:
    if n in handled:continue
    same=norm(n)==norm(cleanLabel)or norm(n) in [norm(z)for z in re.findall(r'\(([^)]+)\)',label)] or label==n+'(정원외전담학과)' or (label.startswith('융합기술공학부(') and label.endswith(n+')'))
    # These cells explicitly name undergraduate faculties and their own constituent degree units.
    if same:
     entries.append({'university':'jbnu','campus':'*','sourceLabel':n,'department':n,'kind':'universityDirect'if col=='대학본부'else'ordinaryCollege','college':None if col=='대학본부'else col,'group':('국제이공학부'if n=='엔지니어링사이언스'else n)if col=='대학본부'else None,'officialGroups':['국제이공학부'if n=='엔지니어링사이언스'else n]if col=='대학본부'else[],'sourceUrl':url,'sourceFile':str(f),'evidence':'공식2026-2 최종수강편람 printed'+str(idx-5)+'(PDFindex'+str(idx)+') 대학/학부(과)전공 이수학점표의 실제 대학열 '+col+' 학과행 '+d.replace('\n',' ')+'와 native명 직접대조; 적용학년도별 legacy를 임의새이름으로 치환하지 않음'})
     handled.add(n)
programs=['예술융합창작','IAB융합','에너지신산업','메타버스/엔터테인먼트','반도체융합','반도체 소재/부품/장비','방위산업','지식재산']
f=O/'root-sources/jbnu-2026fall-final-handbook.pdf';url='https://www.jbnu.ac.kr/web/Board/215187/detailView.do'
for d in programs:
 if d not in names:continue
 entries=[e for e in entries if e['department']!=d]
 entries.append({'university':'jbnu','campus':'*','sourceLabel':d,'department':d,'kind':'officialProgramSystem','college':None,'group':'융합전공','officialGroups':['융합전공'],'sourceUrl':url,'sourceFile':str(f),'evidence':'공식2026-2최종 수강편람 printed177(PDFindex182) 융합전공 목록31~38에 '+d+' 명시. 교과목 개설학과/참여교수 단과대를 별도제도 소속으로 변환하지 않음'})

f=P/'jbnu-systems.html';url='https://www.jbnu.ac.kr/web/academic/curriculum/sub04.do'
for d in ['미래수송기기','농생명·바이오']:
 entries=[e for e in entries if e['department']!=d]
 entries.append({'university':'jbnu','campus':'*','sourceLabel':d,'department':d,'kind':'officialProgramSystem','college':None,'group':'융합전공','officialGroups':['융합전공'],'sourceUrl':url,'sourceFile':str(f),'evidence':'공식 융합전공/연계전공 페이지의 융합전공 현황표 전공 '+d+' / 대학=공유대학 / 학부=융합학부('+d+') 직접명시. JST 공유대학 소속을 일반 단과대에 치환하지 않음'})
checked.append({'url':url,'sourceFile':str(f)})
handled={e['department']for e in entries};unresolved=[{'department':d,'nativeClassifications':sorted(set(r['CMCRS_DIVCDNM']for r in raw if r['MNG_SCSBJT_CDNM']==d and r.get('CMCRS_DIVCDNM'))),'checkedSources':[x['url']for x in checked],'researchComplete':False,'notRequiredForMajorFilter':True,'reason':'현행16단과대학 직접조직표 literal/명시전공 축약과 미일치. 편람 학년별 조직표 및 별도학부/행정주관·공유대학 여부 추가대조 필요'}for d in names if d not in handled]
(O/'jbnu-full-affiliation-b.json').write_text(json.dumps({'final':False,'majorOnlyAffiliationsReady':True,'nonMajorOnlyUnresolved':True,'nativeDepartmentCount':len(names),'entries':entries,'checkedSources':checked,'unresolved':unresolved},ensure_ascii=False,indent=2))
print('native',len(names),'mapped',len(entries),'unresolved',len(unresolved));print([x['department']for x in unresolved])
