import json,collections,math,pathlib,re
root=pathlib.Path('work/academic-region-ui-20261011');schools=json.load(open('assets/academic/universities.json'))['universities'];addresses=json.load(open(root/'source-addresses.json'))
locations={};sources={}
for r in schools:
 if r['id'] not in addresses:continue
 a=addresses[r['id']]
 if a:
  pieces=a.split();province=pieces[0];city=pieces[1]
  if province=='전남광주통합특별시':province='광주' if city.endswith('구') else '전남'
  else:province=next(v for k,v in [('서울','서울'),('부산','부산'),('대구','대구'),('인천','인천'),('광주','광주'),('대전','대전'),('울산','울산'),('세종','세종'),('경기','경기'),('강원','강원'),('충청북','충북'),('충청남','충남'),('전라북','전북'),('전북','전북'),('전라남','전남'),('경상북','경북'),('경상남','경남'),('제주','제주')] if province.startswith(k))
  locations[r['id']]=[{'province':province,'city':city,'address':a,'sourceUrl':'https://m.academyinfo.go.kr/pubinfo/pubinfo0020/list.do?schlId='+r['sourceSchoolId']}]
 else:locations[r['id']]=[]
def extra(id,province,city,campus,url):locations[id].append({'province':province,'city':city,'campus':campus,'sourceUrl':url})
extra('special:knpu','충남','아산시','', 'https://knpo.police.ac.kr/pds/1773965481634.pdf')
extra('academyinfo:0000063','인천','연수구','메디컬캠퍼스','https://www.gachon.ac.kr/kor/7740/subview.do')
extra('academyinfo:0000149','인천','연수구','국제캠퍼스','https://www.yonsei.kr/sc/357/subview.do')
extra('academyinfo:0000066','경기','용인시','국제캠퍼스','https://news.khu.ac.kr/kor/user/contents/view.do?menuNo=200227')
extra('academyinfo:0000066','경기','남양주시','광릉캠퍼스','https://geo.khu.ac.kr/gip/user/bbs/BMSR00045/list.do?menuNo=3300061')
extra('academyinfo:0000133','경기','수원시','자연과학캠퍼스','https://skku.edu/portal.nsf')
extra('academyinfo:0000192','경기','용인시','글로벌캠퍼스','https://www.hufs.ac.kr/')
extra('academyinfo:0000008','충남','천안시','천안캠퍼스','https://www.kongju.ac.kr/KNU/16692/subview.do')
extra('academyinfo:0000173','경기','고양시','고양창의캠퍼스','https://www.joongbu.ac.kr/')
extra('academyinfo:0000106','경기','동두천시','동두천캠퍼스','https://urs.dyu.ac.kr/professor/')
extra('academyinfo:0000157','충북','진천군','진천캠퍼스','https://www.woosuk.ac.kr/main/?menu=74')
extra('academyinfo:0000092','충남','당진시','당진캠퍼스','https://www.sehan.ac.kr/')
extra('academyinfo:0000154','충남','아산시','아산캠퍼스','https://www.u1.ac.kr/u1/introduction/campus-map02.do')
extra('academyinfo:0000284','인천','인천','인천캠퍼스','https://www.chungwoon.ac.kr/')
# Only public, sourced locations are classified. An unresolved corporate school
# remains accessible under all/unlocated rather than guessing north or south.
north={'고양시','구리시','남양주시','동두천시','양주시','의정부시','파주시','포천시','가평군','연천군'}
bycity=collections.defaultdict(set)
for r in schools:
 for loc in locations.get(r['id'],[]):
  if loc['province'] in {'강원','충북','충남','전북','전남','경북','경남'} and loc['city'].endswith('시'):
   bycity[(loc['province'],loc['city'])].add(r['institutionId'])
citygroups={k for k,v in bycity.items() if len(v)>=5 and k not in {('충남','천안시'),('충남','아산시')}}
print('separate cities',[(k,len(bycity[k])) for k in sorted(citygroups)])
def group(province,city):
 if province=='경기':return '경기북부' if city in north else '경기남부'
 if province=='충남' and city in {'천안시','아산시'}:return '천안아산'
 if (province,city) in citygroups:return city.removesuffix('시')
 return province
members=collections.defaultdict(set)
for r in schools:
 if r['id'] not in locations:continue
 for loc in locations[r['id']]:members[group(loc['province'],loc['city'])].add(r['institutionId'])
 if not locations[r['id']]:members['지역 미확인'].add(r['institutionId'])
provincecodes={'11':'서울','21':'부산','22':'대구','23':'인천','24':'광주','25':'대전','26':'울산','29':'세종','31':'경기','32':'강원','33':'충북','34':'충남','35':'전북','36':'전남','37':'경북','38':'경남','39':'제주'}
# Geographic placement, labels can be offset by the widget to avoid collision.
anchors={'서울':[126.98,37.57],'인천':[126.35,37.40],'경기북부':[127.12,37.93],'경기남부':[127.12,37.17],'강원':[128.43,37.74],'충북':[127.88,36.90],'천안아산':[127.00,36.81],'충남':[126.57,36.36],'세종':[127.26,36.53],'대전':[127.38,36.22],'경북':[128.85,36.22],'대구':[128.60,35.88],'전북':[127.12,35.77],'광주':[126.87,35.16],'전남':[126.90,34.72],'경남':[128.26,35.28],'울산':[129.30,35.56],'부산':[129.05,35.14],'제주':[126.55,33.38],'청주':[127.50,36.64],'경산':[128.80,35.80],'원주':[127.94,37.34]}
# Ramer-Douglas-Peucker simplification for outline only, not territorial edits.
def simplify(points,tol=.004):
 if len(points)<=4:return points
 a,b=points[0],points[-1];dx=b[0]-a[0];dy=b[1]-a[1]
 def dist(p):
  t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/(dx*dx+dy*dy))) if dx or dy else 0
  return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy)
 ds=[dist(p) for p in points[1:-1]];m=max(ds)
 if m<=tol:return [a,b]
 i=ds.index(m)+1;return simplify(points[:i+1],tol)[:-1]+simplify(points[i:],tol)
def rings(feature):
 geom=feature['geometry'];polys=[geom['coordinates']] if geom['type']=='Polygon' else geom['coordinates']
 for poly in polys:
  for ring in poly:
   s=simplify(ring)
   if len(s)>=4:yield [[round(x,4),round(y,4)] for x,y in s]
paths=collections.defaultdict(list);islands={'울릉도':[],'독도':[]}
for f in json.load(open(root/'municipalities-raw.json'))['features']:
 p=provincecodes[f['properties']['code'][:2]];name=f['properties']['name'];city=name.split()[0];city=(re.match(r'^(.+?시)',city).group(1) if re.match(r'^(.+?시)',city) else city)
 # Some municipal geometry entries are city districts (e.g. 청주시 상당구).
 city=next((c for prov,c in citygroups if prov==p and name.startswith(c)),city)
 key=group(p,city)
 for ring in rings(f):
  if min(x for x,y in ring)>130:
   islands['독도' if min(x for x,y in ring)>131 else '울릉도'].append(ring)
  else:paths[key].append(ring)
# Very small Dokdo must use the native unsimplified shapes in a labelled inset.
f=next(f for f in json.load(open(root/'provinces-raw.json'))['features'] if f['properties']['code']=='37')
for poly in f['geometry']['coordinates']:
 if min(x for x,y in poly[0])>131:islands['독도'].append([[round(x,6),round(y,6)] for x,y in poly[0]])
regions=[]
order=['서울','인천','경기북부','경기남부','강원','원주','충북','청주','천안아산','충남','세종','대전','경북','경산','대구','전북','광주','전남','경남','울산','부산','제주','지역 미확인']
for key in order:
 if key not in paths and key not in members:continue
 regions.append({'id':key,'name':key,'anchor':anchors.get(key,[129.3,33.65]),'institutionIds':sorted(members[key]),'rings':paths[key]})
outlines=[ring for f in json.load(open(root/'provinces-raw.json'))['features'] for ring in rings(f) if min(x for x,y in ring)<130]
asset={'outlines':outlines,'schemaVersion':1,'checkedAt':'2026-10-11','geometrySource':'https://github.com/southkorea/southkorea-maps/tree/master/kostat/2018/json','geometryLicense':'KOSTAT: Free to share or remix (repository README).','geometryPurpose':'2018 geographic outline only; present-day school grouping uses current sourced addresses, not historical administrative names.','regions':regions,'islands':islands,'campusLocations':locations,'classificationPolicy':{'separateCityMinimumInstitutions':5,'gyeonggiNorthCities':sorted(north),'cheonanAsanCombined':True,'unlocatedNotGuessed':True}}
pathlib.Path('assets/academic/university_regions.json').write_text(json.dumps(asset,ensure_ascii=False,separators=(',',':'))+'\n')
print('regions',len(regions),'size',pathlib.Path('assets/academic/university_regions.json').stat().st_size,'unknown',len(members['지역 미확인']))
