import json,re
from pathlib import Path
from bs4 import BeautifulSoup
P=Path('work/all-university-completion-20261012');S=P/'b-sources'
N=Path('work/full-timetable-audit-20261012/inje-full-a/inje-native-all-public-rows.json')
a=json.loads(N.read_text());native={}
for r in a:
 for z in r['개설학과'].split(','):
  raw=z.strip();base=re.sub(r'\([1-6]\)$','',raw)
  if base:native.setdefault(base,{}).setdefault(raw,[]).append({'code':r['교과목'],'section':r['분반'],'sourceRow':r['sourceRow'],'classification':r['이수구분']})
norm=lambda x:x.replace('ㆍ','·').replace('∙','·').replace(' ','').replace('*','')
u='https://www.inje.ac.kr/kor/setRoute/S_Page.asp?pCode=AC010010000'
b=BeautifulSoup((S/'inje-official-all-colleges.html').read_bytes(),'html.parser');official={};htmlProof=[]
for h in b.select('h4.h4-title'):
 group=h.get_text('',strip=True)
 for t in h.parent.parent.select('a.tit'):
  label=t.get_text('',strip=True).replace('*','').strip()
  official[norm(label)]=dict(college=None if group=='융합전공' else group,group=group if group=='융합전공'else None,kind='officialProgramSystem'if group=='융합전공'else'ordinaryCollege',officialLabel=label,sourceUrl=u,sourceFile=str(S/'inje-official-all-colleges.html'),evidence=f'본교 학과·계열 전체보기 실제본문 colBox h4={group}, 해당 colBox a.tit={label}. 메뉴나 교수정보가 아닌 단과대/융합전공 직접목록.',htmlHeading=group)
  htmlProof.append({'heading':group,'label':label})
(S/'inje-current-body-unit-headings.json').write_text(json.dumps(htmlProof,ensure_ascii=False,indent=2))
transfer='https://www.dit.ac.kr/kr/index.php?idx=16626&mode=fdn&num=1&pCode=employmentinfo&pg=3'
legacy={'경영학과':'경영대학','의공학부':'의생명보건대학','멀티미디어학부':'미디어ㆍ콘텐츠대학','스포츠헬스케어학과':'의생명보건대학','AI소프트웨어학부':'컴퓨터ㆍAI대학','산업안전보건학과(야간)':'의생명보건대학','임상병리학과(야간)':'의생명보건대학'}
for k,college in legacy.items():official[norm(k)]=dict(college=college,group=None,kind='ordinaryCollege',officialLabel=k,sourceUrl=transfer,sourceFile=str(S/'inje-transfer-2026-pdf.pdf'),sourcePages=[5],visualEvidence=str(S/'inje-transfer-2026-pdf-p5.png'),evidence=f'인제대학교 발행2026편입학 모집요강(2025.12.) PDF5/printed3 IV 전형유형별·모집단위별모집인원 실제표 {college}→{k}. 동의과학대 공식기관 자료실에서 배포한 발행원문 PDF 다운로드·직접열람. 본교최신조직의 해당 college와도 일치하며 2025현장실습旧학과표 부모를 그대로 상속하지 않음.')
# Current official FAQ expressly separates the legacy faculty from the current department.
official[norm('컴퓨터공학부')]=dict(college='컴퓨터ㆍAI대학',group=None,kind='ordinaryCollege',officialLabel='컴퓨터공학부',sourceUrl='https://cs.inje.ac.kr/cs/community/faq.do?article.offset=0&articleLimit=10&articleNo=73030&mode=view',sourceFile=str(S/'inje-cs-legacy-faq.html'),evidence='공식컴퓨터공학과 FAQ [20학번까지만해당] 본문 (4)컴퓨터·AI대학 컴퓨터공학부/(5)컴퓨터·AI대학 컴퓨터공학과를 구분하여 직접표기. 현재학과의교수소속으로 추정한 alias가 아니라 구학적 학부 자체의 공식부모확인.')
for k in ['지능로봇전공','스마트제조ICT전공','데이터기반지역혁신전공','스마트기계설계해석전공']:
 official[norm(k)]=dict(college=None,group='융합전공',kind='officialProgramSystem',officialLabel=k,officialProgramSystem='USG공유대학2.0',sourceUrl='https://rise.gnu.ac.kr/sub2/1/7',sourceFile=str(S/'inje-usg-current.html'),additionalSources=[dict(sourceUrl='https://www.inje.ac.kr/kor/setRoute/S_Page.asp?pCode=IF080000000',sourceFile=str(S/'inje-official-second-major.html')),dict(sourceUrl='https://biz.inje.ac.kr/biz/community/notice.do?articleNo=24627&attachNo=17088&mode=download',sourceFile=str(S/'inje-usg-2021.pdf'))],evidence=f'USG총괄 경상국립대 공식공유대학2.0 조직도 실제본문 {k.replace("전공","")} 운영제도와 참여대학 인제대를 명시. 본교2026-07-01 제2전공 actual융합전공 안내표 USG융합 문의처USG교육센터 직접명시. 본교배포2021USG모집요강도 지능로봇/스마트제조ICT/스마트기계설계해석 학위융합제도이며, 2026 native강좌 대상명과 exact대조. 학과·교수의단과대 자동상속 금지.')
entries=[];unresolved=[];administrative=[]
for base,variants in native.items():
 if base in ['대체교과목','현장실습학기제']:
  administrative.append(dict(nativeUnit=base,nativeVariants=variants,kind='nativeAdministrativeTargetNotDepartment',college=None,sourceFile=str(N),evidence='학과소속이 아닌 native 대상표시. 실제학과/단과대로 생성하지 않음. 전필/전선 강좌도 존재하므로 강좌삭제 또는 교양변환하지 않음.'))
  continue
 m=official.get(norm(base))
 if not m:unresolved.append(base);continue
 for raw,rows in variants.items():
  item=dict(university='inje',campus='*',sourceLabel=raw,department=base,**m,researchComplete=True,nativeUnit=base,nativeRelation='publicOfferingTargetAssociation',sourceLabelPolicy='개설학과 개별단위 raw학년괄호보존; display department 학년suffix만제거, 야간보존',nativeCourseScope=rows)
  if m['kind']=='officialProgramSystem':item['officialGroups']=[m['group']];item['collegeDirectEligible']=False
  entries.append(item)
packet=dict(final=not unresolved,scope='All exact native target-unit variants of Inje 2026-2 1756 code/section public offering inventory; not professor ownership inference',entries=entries,unitCount=len(native),academicUnitCount=len(native)-len(administrative),sourceVariantCount=len(entries),administrativeTargets=administrative,unresolved=unresolved,sourceInventory=str(P/'inje-native-unit-inventory-b.json'),nativeSourceFile=str(N),nativeRows=len(a),productEdits=False,sdkVerification=False)
(P/'inje-full-confirmed-affiliations-b.json').write_text(json.dumps(packet,ensure_ascii=False,indent=2)+'\n')
print(dict(academicUnits=packet['academicUnitCount'],sourceVariants=len(entries),unresolved=unresolved,administrative=[x['nativeUnit']for x in administrative]))
