import json,pathlib,shutil
p=pathlib.Path(__file__).parent;old=p.parent/'nsu-current-20261008'
for name in ['notice-102907-file0.jpg','notice-103190-image0.png','notice-102907.json','recovered-103190.json','closure-2026-2-education.json']:
 shutil.copyfile(old/name,p/name)
rows=[]
def add(notice,grade,day,periods,title,section,prof,room,band,hold='',per_teacher=None):
 rows.append({'noticeId':notice,'grade':grade,'weekday':day,'periods':periods,'courseName':title,'section':section,'professor':prof,'room':room,'imageBand':band,'sourceId':f'nsu-image{notice}-g{grade}-d{day}-p{periods[0]}-band{band}-s{section or "unknown"}','holdReason':hold,'periodProfessors':per_teacher or {str(x):prof for x in periods},'transcriptionMethod':'direct visual reading of public original image; row band and period-column locator, not OCR course code'})
# Architectural engineering: each stacked visual band is distinct, even within the same weekday.
for sec,periods in [('01',[1,2,3,4]),('02',[6,7,8,9])]:add(102907,1,1,periods,'공학CAD및실습',sec,'신예경','7312','g1mon')
for sec,periods in [('01',[2,3,4]),('02',[6,7,8])]:add(102907,1,4,periods,'건축일반구조',sec,'류이현','7308','g1thu')
for sec,periods in [('01',[2,3,4]),('02',[6,7,8])]:
 add(102907,2,1,periods,'건축시공및실습2',sec,'민경석 / 박세미','7311','g2mon-upper',per_teacher={str(periods[0]):'민경석',str(periods[1]):'민경석',str(periods[2]):'박세미'})
 add(102907,2,1,periods,'구조역학및실습',sec,'이종원','7310','g2mon-lower')
add(102907,2,2,[3,4,5],'건축법규','','신예경','7311','g2tue')
add(102907,2,3,[2,3,4],'거주후환경평가','','윤성훈','7311','g2wed')
add(102907,2,3,[6,7,8],'구조시스템계획','','류이현','7311','g2wed')
for sec,periods in [('01',[2,3,4]),('02',[6,7,8])]:add(102907,2,4,periods,'BIM및실습',sec,'신예경','7312','g2thu')
for sec,periods in [('01',[1,2,3,4]),('02',[6,7,8,9])]:add(102907,3,1,periods,'건설관리및실습',sec,'손보식','7316','g3mon-upper')
for sec,periods in [('01',[2,3,4]),('02',[6,7,8])]:add(102907,3,1,periods,'철근콘크리트실무실습',sec,'최광호','7308','g3mon-lower')
add(102907,3,2,[6,7,8,9],'건축공학종합설계[캡스톤디자인]','01','이종원 / 민경석 / 류이현','7312','g3tue-upper','multiple professor-area allocation unclear; do not infer individual allocation')
add(102907,3,2,[6,7,8,9],'건축공학종합설계[캡스톤디자인]','02','윤성훈 / 손보식 / 신예경','7308','g3tue-lower','multiple professor-area allocation unclear; do not infer individual allocation')
for sec,periods in [('01',[2,3,4]),('02',[6,7,8])]:
 add(102907,3,3,periods,'건축적산및실습',sec,'민경석 / 박세미','7310','g3wed-upper',per_teacher={str(periods[0]):'민경석',str(periods[1]):'민경석',str(periods[2]):'박세미'})
 add(102907,3,3,periods,'강구조실무실습',sec,'이종원','7312','g3wed-lower')
add(102907,3,4,[2,3,4],'건축설비및실습','','윤성훈','7310','g3thu')
for sec,periods in [('01',[2,3,4]),('02',[6,7,8])]:add(102907,4,2,periods,'인공지능건축공학',sec,'하대웅','7316','g4tue')
for sec,periods in [('01',[2,3,4]),('02',[6,7,8])]:add(102907,4,3,periods,'건설경제및실습',sec,'손보식 / 윤유상','7316','g4wed-upper',per_teacher={str(periods[0]):'손보식',str(periods[1]):'윤유상',str(periods[2]):'윤유상'})
add(102907,4,3,[6,7],'졸업논문2','01','윤성훈 / 신예경','7308','g4wed-lower','individual supervisor allocation not explicit')
add(102907,4,4,[3,4],'졸업논문2','02','이종원 / 민경석 / 손보식','7316','g4thu','individual supervisor allocation not explicit')
add(102907,4,4,[6,7],'친환경건축및실습','','윤성훈','7316','g4thu')
# Gray general courses have no public instructor/room, so retained only as held cells.
add(102907,1,2,[5,6],'고전읽기와쓰기','05','','','g1tue','instructor/room not printed')
add(102907,1,3,[3,4],'현대인과사회적영성','33','','','g1wed','instructor/room not printed')
add(102907,1,3,[5,6],'발표와토론','14','','','g1wed','instructor/room not printed')
add(102907,1,3,[8,9],'현대인과사회적영성','27','','','g1wed','instructor/room not printed')
add(102907,1,2,[7],'채플','','','','g1tue','instructor/room not printed')
add(102907,2,2,[7],'채플','','','','g2tue','instructor/room not printed')
# Smartfarm's actual columns are weekdays x grades, not sections.
add(103190,2,1,[2,3,4],'스마트팜기초공학','','박태현','10304','mon-g2')
add(103190,3,1,[2,3,4],'작물생리학','','이지예','10102-1','mon-g3')
add(103190,2,1,[6,7,8,9],'파이썬기계학습이론과실습','','박태현','10304','mon-g2')
add(103190,2,2,[7,8,9],'생장통계학','','안문형','10304','tue-g2')
add(103190,4,2,[3,4,5],'6차산업과고부가가치화','','안문형','10110','tue-g4')
add(103190,4,2,[7,8,9],'드론이론및실습','','공선석','10110','tue-g4')
add(103190,1,3,[2,3,4],'스마트팜농장실습(기초)A','','박창하','10101','wed-g1')
add(103190,2,3,[2,3,4],'생육환경에너지제어','','이지예','10102-1','wed-g2')
add(103190,3,3,[2,3,4,5],'스마트팜센서제어실습','','박태현','10110','wed-g3')
add(103190,1,3,[7,8,9],'식물영양학','','박창하','10101','wed-g1')
add(103190,3,3,[6,7,8],'스마트팜캡스톤디자인(1)','','이지예','10110','wed-g3')
add(103190,1,4,[2,3,4],'스마트팜농장실습(기초)B','','박창하','10102-1','thu-g1')
add(103190,3,4,[2,3,4],'스마트팜유통마케팅','','안문형','10101','thu-g3')
add(103190,1,4,[7,8,9],'시설원예학','','안문형','10101','thu-g1')
add(103190,3,4,[6,7,8],'식물공장구조의이해','','박창하','10102-1','thu-g3')
add(103190,4,1,[6],'졸업논문','','이지예','10110','mon-g4','individual supervisor/attendance schedule not confirmed')
add(103190,1,1,[3,4],'현대인과사회적영성','','','','mon-g1','instructor/room not printed')
add(103190,1,2,[5],'고전읽기와쓰기','','','','tue-g1','instructor/room not printed')
add(103190,1,2,[6],'채플','','','','tue-g1','instructor/room not printed')
add(103190,2,2,[6],'채플','','','','tue-g2','instructor/room not printed')
add(103190,1,4,[5,6],'발표와토론','','','','thu-g1','instructor/room not printed')
# Approximate source-pixel reading regions are inspection locators, not automatic OCR boxes.
arch_y={'g1mon':(226,308),'g1tue':(308,390),'g1wed':(390,472),'g1thu':(472,554),'g2mon-upper':(554,637),'g2mon-lower':(637,720),'g2tue':(720,802),'g2wed':(802,885),'g2thu':(885,969),'g3mon-upper':(969,1053),'g3mon-lower':(1053,1139),'g3tue-upper':(1139,1223),'g3tue-lower':(1223,1307),'g3wed-upper':(1307,1392),'g3wed-lower':(1392,1478),'g3thu':(1478,1563),'g4tue':(1563,1642),'g4wed-upper':(1642,1722),'g4wed-lower':(1722,1803),'g4thu':(1803,1881)}
arch_x=[180,310,442,572,704,833,964,1095,1226,1357]
smart_x=[50,105,160,215,270,325,380,435,490,545,600,655,710,765,820,875,930,966,1000,1035,1069]
smart_y=[81,137,194,251,308,365,422,479,535]
for r in rows:
 regions=[]
 for period in r['periods']:
  if r['noticeId']==102907:
   y0,y1=arch_y[r['imageBand']];bounds=[arch_x[period-1],y0,arch_x[period],y1]
  else:
   col=(r['weekday']-1)*4+r['grade']-1;bounds=[smart_x[col],smart_y[period-2],smart_x[col+1],smart_y[period-1]]
  regions.append({'period':period,'sourcePixelReadingBounds':bounds,'professor':r['periodProfessors'][str(period)],'classroom':r['room']})
 r['readingRegions']=regions
(p/'visual-image-literal-items.json').write_text(json.dumps({'researchOnly':True,'currentSemesterHeadings':['2026학년도 2학기 건축공학과 시간표','2026학년도 2학기 스마트팜학과 시간표'],'columnsMeaning':{'102907':'native weekday/grade row bands, periods1-9 across','103190':'each weekday has four grade1-4 columns; grade column is not section'},'items':rows},ensure_ascii=False,indent=2)+'\n')
print('items',len(rows),'clear',sum(not x['holdReason'] for x in rows),'held',sum(bool(x['holdReason']) for x in rows))
