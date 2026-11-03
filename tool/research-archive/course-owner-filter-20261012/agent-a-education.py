import json,re,pathlib
O=pathlib.Path('work/course-owner-filter-20261012');x=json.load(open(O/'agent-a-organizations.json'));ds=[(p,json.load(open(p))) for p in json.load(open('assets/timetable/catalog.json'))]
units={u:sorted({v for p,d in ds if d['universityId']==u for c in d['courses'] for v in c.get('departments',[])}) for u in x['scope']}
def add(u,lab,col,dep,url,file,ev):x['mappings'].append(dict(university=u,campus='*',sourceLabel=lab,college=col,department=dep,sourceUrl=url,sourceFile=file,evidence=ev,isOfferingUnit=False))
url='https://www.bu.ac.kr/sites/web/intro/2026_1_fresh.html'
for lab in units['baekseok']:
 if lab not in ['교양','교양대학','교직','계약학과','혁신교육플랫폼대학']:add('baekseok',lab,None,lab,url,None,'2026 official enrollment 안내 explicitly lists current faculties and independent 간호학과/국제학부 as direct undergraduate units without parent college; exact source label.')
add('baekseok','혁신교육플랫폼대학','혁신교육플랫폼대학',None,'https://sanhak.bu.ac.kr/iis/index.do',None,'Official unit website names 혁신교육플랫폼대학 and enumerates its four interdisciplinary majors. Affiliation only, not proof of direct college organizer.')
for lab in units['chosun']:
 if re.fullmatch('간호학과 [1-4]학년',lab):add('chosun',lab,'의과대학','간호학과','https://medical.chosun.ac.kr/nurse/index.do',None,'Official 조선대학교 의과대학 간호학과 website; timetable grade suffix is curriculum cohort association, not organizer identity.')
base={'윤리':'윤리교육과','국어':'국어교육과','사회':'사회과교육과','수학':'수학교육과','과학':'과학교육과','체육':'체육교육과','음악':'음악교육과','미술':'미술교육과','실과':'실과교육과','교육':'교육학과','영어':'영어교육과','컴퓨터':'컴퓨터교육과'}
settings={
'bnue':('https://www.bnue.ac.kr/','work/university-research/catalog-k/bnue-2026-2-current.xlsx'),
'cje':('https://www.cje.ac.kr/web/main.do?screenTp=USER',None),
'dnue':('https://www.dnue.ac.kr/kor/CMS/UnivOrganMgr/view.do?mCode=MN116',None),
'ginue':('https://www.ginue.ac.kr/kor/Main.do','work/university-research/catalog-g/ginue-publichome.html'),
'gnue':('https://www.gnue.ac.kr/','work/university-research/calendar-a/gnue-landing.html')}
for u,(url,file) in settings.items():
 for lab in units[u]:
  dep=None
  if u=='cje':dep=re.sub('^[1-4]학년 ','',lab)+'과'
  elif u=='gnue' and '(' in lab:dep=re.search(r'\(([^()]*)\)',lab).group(1)
  else:
   label=re.sub(r'^\d학년\s*','',lab);label=re.sub(r'^\d+\s*','',label);label=re.sub(r'\s*[ⅠⅡAB]\s*$','',label);label=re.sub(r'\s*\d+$','',label);label=re.sub(r'\s+','',label)
   if u=='bnue' and label=='사회':dep='사회교육과'
   elif u=='bnue' and label=='초등특수유아':dep='초등특수·유아교육과'
   elif u=='dnue' and label=='특수(통합)':dep='특수통합교육과'
   elif u=='ginue' and label=='생활과학':dep='생활과학교육과'
   elif u=='ginue' and label=='특수':dep='특수(통합)교육학과'
   elif u=='ginue' and label=='유아':dep='유아교육과'
   else:dep=base.get(label)
  if dep:add(u,lab,None,dep,url,file,'Official undergraduate roster lists direct 심화과정/department units without college layer. Published timetable 심화과정 or cohort department association normalized by grade/class number and A/B/Ⅰ/Ⅱ suffix; no claim of actual course owner.')
have={u:{m['sourceLabel'] for m in x['mappings'] if m['university']==u} for u in x['scope']}
for g in x['gaps']:
 if g['university']!='cau':g['unmappedLabels']=[v for v in g['unmappedLabels'] if v not in have[g['university']]]
x['gaps']=[g for g in x['gaps'] if g['unmappedLabels'] or g.get('courseCount')]
json.dump(x,open(O/'agent-a-organizations.json','w'),ensure_ascii=False,indent=2);print(len(x['mappings']),sum(len(g['unmappedLabels']) for g in x['gaps']))
