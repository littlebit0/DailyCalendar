# coding: utf-8
import json,pathlib
P=pathlib.Path(__file__).parent;f=P/'followup-a-official-system-inventory.json';d=json.loads(f.read_text());src=P/'root-followup-a-sources/chosun-2026-courseguide.pdf';url='https://lawdep.chosun.ac.kr/sites/acguide/download/2026_1%ED%95%99%EA%B8%B0_%EC%88%98%EA%B0%95%EA%B0%80%EC%9D%B4%EB%93%9C.pdf'
def add(g,name,page,**kw):d['entries'].append(dict(university='chosun',officialGroup=g,name=name,sourceUrl=url,sourceFile=str(src.resolve()),pdfPage=page,**kw))
for n,dep in [('도덕.윤리교육','교육학과'),('통합과학교육','물리교육과')]:add('연계전공',n,34,operatingDepartment=dep)
add('학생 자율설계 연계전공','학생 자율설계 연계전공',35,individualDesign=True)
names=['미술심리치료','경영정보-AI','문화콘텐츠-AI','에너지-AI','자동차-AI','로봇-AI','Bio medical-AI','스마트팩토리-AI','웰에이징 건강재활','창업','스마트AI부동산','핀테크 비즈니스','첨단반도체소재·소자·패키징','기후위기대응','자율주행차','친환경차','첨단바이오','에이지테크 소재부품']
for i,n in enumerate(names,1):add('융합전공',n,36,originalNumber=i,hostEvidence='원표 주관/참여학과 셀에 실제 구분 명시; PDF 페이지36 표를 기준으로 읽을 것. 주관학과의 단과대를 이 별도 제도의 소속으로 치환하지 않음.')
robot=['초급(이공계)','중급기구','중급전장','중급제어','중급지능','고급HW시스템 및 신뢰성','고급센서액츄에이터','고급 내비게이션','고급 AI시스템','고급 로봇통신','고급 우주로봇','고급 로봇SI']
for i,n in enumerate(robot,1):add('마이크로전공','지능형로봇 '+n,37,originalNumber='1-'+str(i),operatingDepartment='지능형로봇학과(지능형로봇사업단)')
base={2:'NHN SW 실무',3:'창업',4:'공연예술융복합',5:'무용치유',6:'성능위주소방설계',7:'전기공학설계',8:'스포츠융복합',9:'건강운동관리',10:'전인지도사',11:'미래모빌리티부품소재',12:'학교 밖 교육 전문가',13:'초급 기후위기대응',14:'중급 기후위기대응 기후인문학',15:'중급 기후위기대응 데이터분석',16:'중급 기후위기대응 거버넌스',17:'중급 기후위기대응 넷제로/그린디자인',18:'제어 테크니션',19:'구조 테크니션',20:'추진 테크니션',21:'설계 테크니션',22:'전장 테크니션',23:'통신 테크니션',24:'항공우주 엔지니어',25:'UAM 테크니션',47:'G-문화예술교류',48:'건강노화통합관리',49:'홀리스틱문화예술',50:'AI 리터러시와 다양성',51:'특수목적차량',52:'선박설계',53:'VMD 공간·패션 크리에이터',54:'미래시민윤리교육'}
for start,n in [(26,'경영정보-AI'),(29,'문화콘텐츠-AI'),(32,'에너지-AI'),(35,'자동차-AI'),(38,'로봇-AI'),(41,'Bio medical-AI'),(44,'스마트팩토리-AI')]:
 for offset,stage in enumerate(['초급','중급','고급']):base[start+offset]=n+' '+stage
for i,n in sorted(base.items()):add('마이크로전공',n,37 if i<=6 else 38 if i<=43 else 39,originalNumber=i,sourceRangeExpanded=26<=i<=46)
for n in ['아트콜라보크리에이터','기후위기대응']:add('CSU나노인증',n,39)
add('4IR미래역량인증','4IR미래역량인증',40,courseCodeTablePdfPages=[41,42])
d['notes']=['Published inventories only; no offered-course creation, no title-only current timetable membership inference. GNU declared merged-cell source propagation. Chosun explicitly printed number-ranges expanded only into printed 초/중/고급 stages; host parents not invented.']
f.write_text(json.dumps(d,ensure_ascii=False,indent=2));print('Chosun published',sum(x['university']=='chosun' for x in d['entries']))
