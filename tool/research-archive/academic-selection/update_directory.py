import json
from collections import Counter
from pathlib import Path
p=Path('assets/academic/universities.json'); j=json.loads(p.read_text())
branches={'건국대학교','고려대학교','동국대학교','연세대학교','한양대학교'}
# Explicit picker scope, rather than matching religious words at runtime.
theology={
'감리교신학대학교','광주가톨릭대학교','대전가톨릭대학교','대전신학대학교',
'부산장신대학교','서울신학대학교','서울장신대학교','수원가톨릭대학교',
'순복음총회신학교','아신대학교','영남신학대학교','영산선학대학교',
'장로회신학대학교','중앙승가대학교','총신대학교','한국침례신학대학교',
'한일장신대학교','호남신학대학교',
}
military={'special:kma','special:kna','special:kafa','special:afna','special:kaay'}
review={
'가톨릭대학교':(['성심교정','성의교정','성신교정'],'https://m.songsin.catholic.ac.kr/ko/index.do'),
'강원대학교':(['춘천캠퍼스','삼척캠퍼스','도계캠퍼스','강릉캠퍼스','원주캠퍼스'],'https://admission.kangwon.ac.kr/admission/main.do'),
'건양대학교':(['글로컬캠퍼스','메디컬캠퍼스'],'https://www.konyang.ac.kr/kor.do'),
'경기대학교':(['수원캠퍼스','서울캠퍼스'],'https://enter.kyonggi.ac.kr/cms/FR_CON/index.do?MENU_ID=80'),
'경동대학교':(['글로벌캠퍼스','메디컬캠퍼스','메트로폴캠퍼스'],'https://www.kduniv.ac.kr/kor/CMS/SiteMap/SiteMapLayer.do'),
'경인교육대학교':(['인천캠퍼스','경기캠퍼스'],'https://lms.ginue.ac.kr/?epTicket=LOG'),
'단국대학교':(['죽전캠퍼스','천안캠퍼스'],'https://dankook.ac.kr/campusmap'),
'명지대학교':(['자연캠퍼스','인문캠퍼스'],'https://www.mju.ac.kr/mjukr/192/subview.do'),
'신한대학교':(['의정부캠퍼스','동두천캠퍼스'],'https://www.shinhan.ac.kr/kr/231/subview.do'),
'안양대학교':(['안양캠퍼스','강화캠퍼스'],'https://www.anyang.ac.kr/main/introduction/anyang-campus-map.do'),
'예원예술대학교':(['전북희망캠퍼스','경기드림캠퍼스'],'https://www.yewon.ac.kr/'),
'을지대학교':(['대전캠퍼스','성남캠퍼스','의정부캠퍼스'],'https://www.eulji.ac.kr/webshr/univ/download/2021Guide.pdf'),
'인제대학교':(['김해캠퍼스','부산캠퍼스'],'https://safety.inje.ac.kr/safety/management/aed.do'),
'인천가톨릭대학교':(['강화캠퍼스','송도국제캠퍼스'],'https://shin.iccu.ac.kr/'),
'중앙대학교':(['서울캠퍼스','다빈치캠퍼스'],'https://www.cau.ac.kr/cms/FR_CON/index.do?CAMPUS_MAP=2&MENU_ID=610'),
'홍익대학교':(['서울캠퍼스','세종캠퍼스'],'https://www.hongik.ac.kr/kr/index.do'),
'연세대학교':(['신촌캠퍼스','국제캠퍼스','미래캠퍼스'],'https://www.yonsei.ac.kr/wj/1483/subview.do'),
}
for r in j['universities']:
 if r['sourceKind'] in {'사이버대학(대학)','사이버대학(전문대학)','원격대학(대학)','원격대학(전문)'}:
  r['sourceDegreeKind']=r['kind']; r['kind']='cyberUniversity'
 r['campusSelectionRequired']=r['institutionName'] in branches
 if r['name'] in theology or r['id'] in military:
  r['selectable']=False
  r['selectionExclusion']='militaryAcademy' if r['id'] in military else 'theologicalInstitution'
 if r['campusOrder']==0 and r['institutionName'] in review:
  r['campusNames'],r['campusNamesSourceUrl']=review[r['institutionName']]
 if r['id']=='academyinfo:0000082': r['sourceCampus']=r['campus']; r['campus']='죽전캠퍼스'
 if r['id']=='academyinfo:0002726': r['sourceCampus']=r['campus']; r['campus']='천안캠퍼스'
 if r['id']=='academyinfo:0000149': r['sourceCampus']=r['campus']; r['campus']='신촌캠퍼스'; r['campusNames']=['신촌캠퍼스','국제캠퍼스']
for g in j['institutionGroups']:
 g['campusSelectionRequired']=g['name'] in branches
 if g['name'] in review and review[g['name']][1] not in g['sourceUrls']: g['sourceUrls'].append(review[g['name']][1])
j['selectionPolicy']={
 'checkedAt':'2026-09-26',
 'excludedMilitaryIds':sorted(military),
 'excludedTheologicalNames':sorted(theology),
 'branchSelectionInstitutions':sorted(branches),
 'notes':'Selection scope only. All original campus IDs and stored profiles remain valid. Religious affiliation alone does not exclude a comprehensive university.',
 'theologicalEvidenceUrls':['https://acts.ac.kr/design/contents10.asp?code=2010','https://www.dcatholic.ac.kr/univ/s2/college.php','https://www.suwoncatholic.ac.kr/','https://admission.gjc.ac.kr/inc/2025univplan.pdf','https://www.youngsan.ac.kr/'],
}
j['checkedAt']='2026-09-26'
p.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
print('raw kinds',dict(Counter(r['kind'] for r in j['universities'])))
print('selectable institutions',dict(Counter(r['kind'] for r in j['universities'] if r['campusOrder']==0 and r.get('selectable',True))))
print('excluded',sum(not r.get('selectable',True) for r in j['universities']))
