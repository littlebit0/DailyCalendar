import json,collections
from pathlib import Path
p=Path('assets/academic/universities.json');data=json.loads(p.read_text());rows=data['universities'];byid={r['id']:r for r in rows}
# Explicit reviewed campus memberships. This is a release-time transformation,
# not a runtime name-stripping or name-similarity heuristic.
academy='https://m.academyinfo.go.kr/intro/intro0350/intro.do'
career='https://m.career.go.kr/cnet/web/base/school/schoolUniversityList.mdo'
groups=[]
def group(name, ids, sources):
 ids=[x if ':' in x else 'academyinfo:'+x for x in ids]
 assert all(x in byid for x in ids)
 gid='institution:'+ids[0]
 for index,id in enumerate(ids):
  r=byid[id];r['institutionId']=gid;r['institutionName']=name;r['campusOrder']=index
 groups.append({'id':gid,'name':name,'campusIds':ids,'sourceUrls':sources})
for r in rows:
 r['institutionId']='institution:'+r['id'];r['institutionName']=r['name'];r['campusOrder']=0
same_name={
'가톨릭대학교':['0000046','0000048','0000049'],
'강원대학교':['0000003','0000004','0003363','0003364'],
'건양대학교':['0000054','0000055'],
'경기대학교':['0000056','0000058'],
'경동대학교':['0000060','0002573','0002574','0002744'],
'경인교육대학교':['0000256','0000257'],
'단국대학교':['0000082','0002726'],
'명지대학교':['0000109','0000111'],
'상명대학교':['0000117','0002959'],
'신한대학교':['0002712','0002800'],
'안양대학교':['0000147','0000148'],
'예원예술대학교':['0000218','0000219'],
'을지대학교':['0000161','0000162','0002911'],
'인제대학교':['0000164','0000166'],
'인천가톨릭대학교':['0000168','0000167'],
'전남대학교':['0000023','0000024'],
'중앙대학교':['0000175','0000174'],
'홍익대학교':['0000212','0002949'],
}
for name,ids in same_name.items():
 assert all(byid['academyinfo:'+id]['name']==name for id in ids)
 group(name,ids,[academy])
group('정화예술대학교',['careernet:fa86040b74704edb','careernet:075febf2a618f117'],[career])
group('포스코기술대학',['careernet:7885ee23d498e403','careernet:4abddca9a225e68a'],[career,'https://newsroom.posco.com/kr/포스코기술대학-2018학년도-전문학사-40명-배출/'])
for name,ids,url in [
 ('가야대학교',['0002748','0002749'],'https://kplus.kaya.ac.kr/'),
 ('건국대학교',['0000052','0000053'],'https://www.kku.ac.kr/index.do'),
 ('고려대학교',['0000069','0000070'],'https://www.korea.ac.kr/ko/351/subview.do'),
 ('국립목포대학교',['0000011','0003312'],'https://www.mokpo.ac.kr/www/1397/subview.do'),
 ('국립창원대학교',['0000028','0003297','0003298'],'https://www.changwon.ac.kr/eduhub/main.do'),
 ('동국대학교',['0000100','0000101'],'https://www.dongguk.edu/page/513'),
 ('연세대학교',['0000149','0000150'],'https://www.yonsei.ac.kr/sc/intro/campus.jsp'),
 ('영산대학교',['0003193','0003194'],'https://www3.ysu.ac.kr/kor/Main.do'),
 ('한양대학교',['0000203','0000204'],'https://site.hanyang.ac.kr/web/family/erica'),
]:group(name,ids,[academy,url])
# Eight separately disclosed Polytechnic colleges, each containing its campus
# rows. ICT Polytechnic is a different institution and is never merged here.
for name,ids in [
 ('한국폴리텍 I 대학',['0000584','0000585','0000586','0002912']),
 ('한국폴리텍 II 대학',['0000589','0000590','0003105']),
 ('한국폴리텍 III 대학',['0000593','0000594','0002854']),
 ('한국폴리텍 IV 대학',['0000603','0000604','0000606','0000607']),
 ('한국폴리텍 V 대학',['0000616','0000617','0000619','0000620','0002975']),
 ('한국폴리텍 VI 대학',['0000623','0000624','0002674','0000636']),
 ('한국폴리텍 VII 대학',['0000631','0000632','0000633','0003157','0003163']),
 ('한국폴리텍 특성화대학',['0000635','0000637','0000638','0003104']),
]:
 group(name,ids,[academy,'https://www.kopo.ac.kr/intro.do'])
 for id in ids:
  r=byid['academyinfo:'+id]
  assert r['name'].startswith(name+' ')
  r.setdefault('sourceCampus',r['campus']);r['campus']=r['name'][len(name)+1:]

def campus(id,label,region=None,aliases=None):
 r=byid[id if ':' in id else 'academyinfo:'+id]
 r.setdefault('sourceCampus',r['campus']);r['campus']=label
 if region:
  r.setdefault('sourceRegion',r['region']);r['region']=region
 if aliases:r['aliases']=aliases
# The requested examples use the universities' published campus names. Keep
# the disclosure source's generic campus/region fields separately for auditing.
campus('0000117','서울캠퍼스','서울')
campus('0002959','천안캠퍼스','충남 천안')
campus('0000023','광주캠퍼스','광주')
campus('0000024','여수캠퍼스','여수')
campus('0000069','서울캠퍼스','서울 성북구',['안암','안암캠퍼스'])
campus('0000070','세종캠퍼스','세종')
# Every parenthesized campus name in the corpus is mapped explicitly above.
for id,label in {
 '0002748':'김해캠퍼스','0002749':'고령캠퍼스','0000052':'서울캠퍼스','0000053':'GLOCAL(글로컬)캠퍼스',
 '0000011':'도림캠퍼스','0003312':'담양캠퍼스','0000028':'창원캠퍼스','0003297':'거창캠퍼스','0003298':'남해캠퍼스',
 '0000100':'서울캠퍼스','0000101':'WISE캠퍼스','0000150':'미래캠퍼스','0003193':'해운대캠퍼스','0003194':'양산캠퍼스',
 '0000203':'서울캠퍼스','0000204':'ERICA캠퍼스',
}.items():campus(id,label)
campus('careernet:7885ee23d498e403','포항캠퍼스')
campus('careernet:4abddca9a225e68a','광양캠퍼스')
urls={
 '상명대학교':['https://map.smu.ac.kr/kor/index.do','https://admission.smu.ac.kr/apply/program.html'],
 '전남대학교':['https://english.jnu.ac.kr/english/18859/subview.do'],
 '고려대학교':['https://frecon.korea.ac.kr/temp_g/info/map.do'],
}
for g in groups:g['sourceUrls']+=urls.get(g['name'],[])
data['schemaVersion']=2;data['institutionCount']=len({r['institutionId'] for r in rows});data['institutionGroups']=groups
assert len(rows)==429
assert len({r['id'] for r in rows})==429
assert all('(' not in r['institutionName'] for r in rows if '(' in r['name'])
assert all(len({r['kind'] for r in rows if r['institutionId']==gid})==1 for gid in {r['institutionId'] for r in rows})
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('campuses',len(rows),'institutions',data['institutionCount'],'multicampus',len(groups))
print(collections.Counter(next(r['kind'] for r in rows if r['institutionId']==g) for g in {r['institutionId'] for r in rows}))
