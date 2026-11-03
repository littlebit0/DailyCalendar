import json,pathlib,re
from lxml import html
O=pathlib.Path('work/course-owner-filter-20261012');S=O/'agent-a-sources';out=json.load(open(O/'agent-a-organizations.json'));maps=out['mappings'];cat=json.load(open('assets/timetable/catalog.json'));ds=[(p,json.load(open(p))) for p in cat];units={u:sorted({v for p,d in ds if d['universityId']==u for c in d['courses'] for v in c.get('departments',[])}) for u in out['scope']}
def add(u,cam,label,col,dep,url,file,ev,off=False):
 if label not in units[u]:return
 maps.append(dict(university=u,campus=cam,sourceLabel=label,college=col,department=dep,sourceUrl=url,sourceFile=file,evidence=ev,isOfferingUnit=off))
# Explicit college section heading scope on official academic overview pages.
for u in ['ajou','ewha']:
 p=S/(u+'-colleges.html');r=html.fromstring(p.read_text());url={'ajou':'https://www.ajou.ac.kr/kr/admission/list01.do','ewha':'https://www.ewha.ac.kr/ewha/academics/college.do'}[u];aff={}
 for box in r.xpath('//div[@class="college-box"] | //div[@class="b-box"]'):
  hh=box.xpath('./h4|./div/h4');cols=[' '.join(x.text_content().split()) for x in hh]
  if not cols:continue
  col=cols[0]
  for a in box.xpath('.//a'):
   label=' '.join(a.text_content().split())
   if label and len(label)<55:aff[label]=col
 for lab in units[u]:
  # Ajou labels include native sust and major joined; sust parent exact official anchor.
  base=lab.split(' / ')[0]
  if base in aff:add(u,'*',lab,aff[base],lab if lab!=aff[base] else None,url,str(p),'Exact official department anchor grouped under college section heading. Compound curriculum association retains original label; not course organizer.',False)
# Hansung official table rows use explicit rowspan college column. Map exact track or published track base only.
p=S/'hansung-colleges.html';r=html.fromstring(p.read_text());url='https://www.hansung.ac.kr/hansung/6208/subview.do'
for table in r.xpath('//table'):
 col=None
 for tr in table.xpath('.//tbody/tr'):
  th=tr.xpath('./th')
  if th:
   name=' '.join(th[0].text_content().split());name=re.sub(r'\s+','',name)
   if name.endswith('대학'):col=name
  if col is None:continue
  text=' '.join(tr.text_content().split())
  parts=[t.strip() for td in tr.xpath('./td') for t in re.split(r'[,\n]',td.text_content()) if t.strip()]
  for lab in units['hansung']:
   if lab in parts or (lab.endswith('트랙') and lab[:-2] in parts):add('hansung','main',lab,col,lab,url,str(p),'Official college/department/track table with inherited college rowspan; track matched exact source base plus published track suffix.',False)
# Verified standalone GKNU adult learner unit, not the future 2027 reform name.
url='https://law.gknu.ac.kr/module/bbs/view.php?bdno=189&mid=%2Fadministration%2Fnotice&rdno=169076'
for lab in units['gknu']:add('gknu','*',lab,None,'성인학습자학부 '+lab,url,str(S/'gknu-current.html'),'2026-08-10 official notice explicitly excludes 성인학습자 from college affiliation. Adult learner official site lists 사회복지학/스포츠레저학/뷰티학 majors. Standalone faculty; future 2027 name not applied.',False)
# Hanyang official web overview reviewed in browser; exact department memberships only.
seoul={'공과대학':'건축학부|건축공학부|건설환경공학과|도시공학과|자원환경공학과|융합전자공학부|컴퓨터소프트웨어학부|정보시스템학과|신소재공학부|화학공학과|생명공학과|유기나노공학과|에너지공학과|기계공학부|원자력공학과|산업공학과|미래자동차공학과|데이터사이언스학부|반도체공학과','인문과학대학':'국어국문학과|중어중문학과|영어영문학과|독어독문학과|사학과|철학과|미래인문학융합학부','사회과학대학':'정치외교학과|사회학과|미디어커뮤니케이션학과|관광학부','자연과학대학':'수학과|물리학과|화학과|생명과학과','정책과학대학':'정책학과|행정학과','경영대학':'경영학부|파이낸스경영학과','사범대학':'교육학과|교육공학과|국어교육과|영어교육과|수학교육과|응용미술교육과','생활과학대학':'의류학과|식품영양학과|실내건축디자인학과','음악대학':'성악과|작곡과|피아노과|관현악과|국악과','예술·체육대학':'연극영화학과|무용학과','국제대학':'국제학부|글로벌콘텐츠융합학부'}
erica={'공학대학':'건축학부|건축학전공|건축공학전공|건설환경공학과|교통·물류공학과|전자공학부|재료화학공학과|배터리소재화학공학과|기계공학과|산업경영공학과|로봇공학과|에너지바이오학과|해양융합공학과|융합시스템공학과|스마트융합공학부|지능형로봇학과','소프트웨어융합대학':'컴퓨터학부|컴퓨터전공|지능형클라우드전공|ICT융합학부|데이터인텔리전스전공|디자인컨버전스전공|인공지능학과|수리데이터사이언스학과|융합보안학과','첨단융합대학':'차세대반도체융합공학부|신소재반도체공학전공|반도체디스플레이공학전공|바이오신약융합학부|분자의약전공|바이오나노공학전공|국방지능정보융합공학부|지능형시스템공학전공|국방전략기술공학과','글로벌문화통상대학':'글로벌문화통상학부|한국언어문학과|중국학과|일본학과|영미언어문화학과|프랑스학과','커뮤니케이션&컬처대학':'광고홍보학과|미디어학과|문화인류학과|문화콘텐츠학과','경상대학':'경제학부|경영학부|보험계리학과|회계세무학과','디자인대학':'주얼리·패션디자인학과|산업디자인학과|커뮤니케이션디자인학과|영상디자인학과','예체능대학':'스포츠과학부|스포츠문화전공|스포츠코칭전공|무용예술학과|실용음악학과'}
for cam,groups in [('seoul',seoul),('erica',erica)]:
 url='https://www.hanyang.ac.kr/'+('s' if cam=='seoul' else 'e')+'_college_department-info'
 for col,words in groups.items():
  for lab in words.split('|'):add('hanyang',cam,lab,col,lab,url,None,'Official campus college/department overview section explicitly lists this department. Exact affiliation only; no course organizer inference.',False)
# Dedupe same mapping identity and keep first concrete source; report conflicting actual affiliation separately.
ded={}
for m in maps:
 key=(m['university'],m['campus'],m['sourceLabel'],m['college'],m['department'],m.get('isOfferingUnit',False))
 if key not in ded:ded[key]=m
out['mappings']=list(ded.values());out['gaps']=[]
for u in out['scope']:
 have={m['sourceLabel'] for m in out['mappings'] if m['university']==u};mis=[x for x in units[u] if x not in have]
 if mis:out['gaps'].append(dict(university=u,unmappedLabels=mis,reason='Exact affiliation unresolved. No guessing; current source role may be target curriculum rather than organizer.'))
json.dump(out,open(O/'agent-a-organizations.json','w'),ensure_ascii=False,indent=2)
print('mappings',len(out['mappings']),'owners',len(out['courseOwners']),'gaps',sum(len(x['unmappedLabels']) for x in out['gaps']));print([(u,len([m for m in out['mappings'] if m['university']==u])) for u in out['scope']])
