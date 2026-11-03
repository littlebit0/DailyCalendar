import json,pathlib,xml.etree.ElementTree as ET
O=pathlib.Path('work/course-owner-filter-20261012');x=json.load(open(O/'agent-a-organizations.json'));P=pathlib.Path('work/university-research/expansion17-20261011/a');c=P/'ewha-runtime-codes.json';v=json.loads(json.load(open(c))['result']['value']);r=ET.fromstring(v['universities']);names={q.find("Col[@id='UNIV_CD']").text:q.find("Col[@id='UNIV_NM_KOR']").text for q in r.findall('.//Row')};labs={v for p in json.load(open('assets/timetable/catalog.json')) for d in [json.load(open(p))] if d['universityId']=='ewha' for course in d['courses'] for v in course.get('departments',[])};old={m['sourceLabel'] for m in x['mappings'] if m['university']=='ewha'}
for p in P.glob('ewha-native-*.json'):
 for row in json.load(open(p)).get('rows',[]):
  lab=row.get('CLS_MAJ_CD_NM');col=names.get(row.get('GROUP_CD'))
  if lab in labs and lab not in old and col and col.endswith('대학'):
   x['mappings'].append(dict(university='ewha',campus='*',sourceLabel=lab,college=col,department=None if lab==col else lab,sourceUrl='https://eureka.ewha.ac.kr/eureka/hs/sg/openHssg504021q.do',sourceFile=str(p),evidence='Official public course response CLS_MAJ_CD_NM and same-row GROUP_CD; GROUP_CD resolved by official runtime UNIV_CD/UNIV_NM_KOR code dataset '+str(c)+'. Uses returned row classification, not requested query filename.',isOfferingUnit=False));old.add(lab)
for g in x['gaps']:
 if g['university']=='ewha':g['unmappedLabels']=[v for v in g['unmappedLabels'] if v not in old]
json.dump(x,open(O/'agent-a-organizations.json','w'),ensure_ascii=False,indent=2);print(len(old),len(x['mappings']))
