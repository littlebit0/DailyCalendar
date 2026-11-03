# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet039-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={1103: [(3, 720, 885, '청503')], 1104: [(1, 720, 885, '청503')], 1106: [(3, 900, 1065, '청502')], 1107: [(2, 900, 1065, '청504')], 1108: [(2, 630, 705, '청304'), (4, 630, 705, '청304')], 1109: [(1, 720, 795, '청309'), (3, 720, 795, '청309')], 1110: [(3, 900, 1065, '청504')], 1111: [(6, 780, 945, '호701')], 1112: [(2, 1170, 1305, '정403')], 1113: [(1, 810, 885, '청620'), (3, 810, 885, '청620')], 1114: [(1, 540, 615, '청509'), (3, 540, 615, '청509')], 1115: [(2, 720, 885, '청507')], 1116: [(1, 810, 885, '청407'), (3, 810, 885, '청407')], 1118: [(2, 630, 705, '청620'), (4, 630, 705, '청620')], 1121: [(2, 630, 705, '청207'), (4, 630, 705, '청207')], 1123: [(1, 990, 1065, '청304'), (3, 990, 1065, '청304')], 1124: [(5, 720, 885, '청409')], 1125: [(5, 900, 1065, '청409')], 1126: [(2, 720, 795, '청509'), (4, 720, 795, '청509')], 1127: [(2, 630, 705, '청301'), (4, 630, 705, '청301')], 1128: [(4, 900, 1065, '청307')], 1129: [(5, 540, 705, '청407')], 1130: [(2, 900, 975, '청407'), (4, 900, 975, '청407')]}
weeks={1103: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], 1104: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15], 1106: [1, 2, 3, 4, 5, 6, 7, 11, 12, 13, 14], 1107: [1, 2, 3, 4, 5, 6, 7, 11, 12, 13, 14], 1108: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1109: [1, 2, 3, 5, 6, 7, 9, 10, 13, 15], 1110: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1111: [1, 2, 3, 6, 7, 9, 10, 11, 12, 13, 14], 1112: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1113: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1114: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1115: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1116: [1, 2, 3, 6, 7, 10, 11, 12, 15], 1118: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16], 1121: [1, 2, 3, 4, 5, 9, 10, 12, 13, 14, 15], 1123: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1124: [1, 3, 5, 7, 9, 10, 11, 12, 13, 14, 15], 1125: [1, 2, 14, 15], 1126: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1127: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1128: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], 1129: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1130: [1, 2, 4, 5, 6, 7, 10, 11, 12, 13, 14]}
reasons={1101: '공동 교수 계획 중 undated 순차 강의·혼합 운영과 다른 dated 계획이 있음. 실제 작성자별 우선순위/담당배정 불명확으로 전체 보류.', 1102: '영어트랙 제한 및 명시 in-person 기본을 보존. biweekly lectures와 매주 native 두 시간 및 주차표 운영 문구의 빈도 의미를 이번 후보에서 임의 선택하지 않아 보류. 학생 개별 발표 일부 사전녹화는 전체수업 원격으로 오해하지 않음.', 1103: '대면 기본/휴일 녹화만 별도. 자체 1–14주 정상 이론·GCP 수업발표;8주 AI 이론+중간과제는 정상수업 예외10/21.15 공란/16시험 보류.', 1104: '대면 기본/휴일만 원격.1–12/14–15주 정상 이론·수업발표;8주 AI 강의+중간대체과제10/26 자체 예외.13주 영상 혹은 오프라인 특강 미배정 제외.', 1105: '운영 추가설명 공란·온라인강의 별도선택. 같은 교수 다른 분반의 대면 기본을 차용하지 않음. 실제 이 분반별 방식 배정 미확인 보류.', 1106: '수업 전체3시간 이론·토론·현장실습 운영을 구분.1–7/11–14주 정상 이론·토론만.9/10실제 현장방문·8시험·15조건부 보강·16기말발표는 보류, field 주제/과제 브리핑을 실제 교외출석과 혼동0.', 1107: '수업 전체3시간 이론·토론·현장실습 운영을 구분.1–7/11–14주 정상 이론·토론만.9/10실제 현장방문·8시험·15조건부 보강·16기말발표는 보류, field 주제/과제 브리핑을 실제 교외출석과 혼동0.', 1108: '수업 전 글 읽기/강의실 모둠 토론 및 주차별 이론·발표. holiday 대비 remote/field는 조건부만.1–7/9–15 정상 그룹, 시험·휴일 제외.', 1109: '주차표의 literal 대면 날짜11개만.10/7 특강은 장소·시각 미정,12/10 방문은 native 요일 아님. 시험/녹화/휴일 제외; 다른요일 또는 보강시각 생성0.', 1110: '대면 기본과 각주 정상 수업 이론·토론 확인. 미리 읽기/영상 자료는 예습이며 전체 녹화 운영 아님.1111 토요일4/5주는 명시녹화 휴일로 제외;8시험/15보강/16시험은 보류. 재직자 제한 원문 보존.', 1111: '대면 기본과 각주 정상 수업 이론·토론 확인. 미리 읽기/영상 자료는 예습이며 전체 녹화 운영 아님.1111 토요일4/5주는 명시녹화 휴일로 제외;8시험/15보강/16시험은 보류. 재직자 제한 원문 보존.', 1112: '대면 기본과 각주 정상 수업 이론·토론 확인. 미리 읽기/영상 자료는 예습이며 전체 녹화 운영 아님.1111 토요일4/5주는 명시녹화 휴일로 제외;8시험/15보강/16시험은 보류. 재직자 제한 원문 보존.', 1113: '매주 대면 강의와 미리 보는 녹화 영상 후 수업시간 질의응답 명시.1–7/9–14만. 영상시청은 사전학습, 생물학과 수강불가 학교문구·전체 원문 보존.8중간15기말16공란 보류.', 1114: '대면 기본과 Flipped 사전영상 후 강의실 보충강의 명시.1–7/9–14만.8시험/15조건부보강/16시험 제외; 뇌영상 교육주제를 원격수업과 혼동0.', 1115: '판서·설명 중심 강의, 온라인은 명시 휴일보강 조건부 녹화만.1–7/9–14 이론강의,8/15/16시험 제외. 우주유튜브 등 권장 자료는 전체원격0.', 1116: '각주 실제 대면1/2/3/6/7/10/11/12/15만.4/5/9/13 주1회 녹화 시각 생성0,14휴강·8/16시험 보류.', 1117: '현재 native 전체만 확인. 계획서0, currentOperatingCorrection 전체를 원래대로 보존. 근거 없이 과거 철회 취소0.', 1118: '주차마다1/2 강의 모두 대면 명시.1–7/9–14 정상 그룹과8주2번째(목10/22) 및16주2번째(목12/17) 자체 대면 강의만 시험기간 예외. 인체발생/운동계통/소화기 동영상은 대면 수업 내 자료.15보강은 미확정 제외; 시험1번째 시각 생성0.', 1119: '보강만 비동기 가능이라 원칙적 이론강의와 영상 자료를 구분하나, 온라인강의 별도선택 및 실제 대면 배정 직접명시 없음. 이번 좁은 후보 보류.', 1120: '대면 기본 외 일부 비실시간 실제 운영 문구 있으나 구체 배정 없음.4주 현장09/19와주차 범위 충돌 보존.6주 live online 특강은 금10/9 휴일에 실제 자체 literal 날짜가 없어 임의생성0. 전체 이번 후보 보류.', 1121: '각주 명시 대면만.6/7/11주 및12주11/19 녹화 제외.8주 현장 예정과 휴강/16시험 제외.12주11/17 대면만; 원문 시험12/15 10:30–11:30은 강의 HH로 생성0.', 1122: '온라인 주차 시청 인정기간 강의로 native 고정HH 없음. 명시 별도 시험 시각은 정규 VOD 강의 HH로 생성0. 전 수강 제한·재수강 변경사항 보존하여 held 유지.', 1123: '대면 기본/휴일만 비실시간,1–7/9–14 강독·토론.8대체과제/15보강/16시험 제외. 교재·시/생태 주제는 운영과 구분.', 1124: '대면 기본+1/3/5/7/9–15 정규 이론·토론·발표.2주 캠퍼스 탐방 현장·4휴일·6개별 현장·8/16시험은 제외.15주 자체 프로젝트 발표 정상 범위, 추정 보강일 생성0.', 1125: '대면 원칙 중1/2주 이론강의와14토론·15발표만.3/5/7/9–13 실제 현장·탐조·혼합실습 그룹은 별도시간배정 미확인 보류. 날씨변경/장비조건 원문 보존.', 1126: '대면 기본·추석만 녹화,1–7/9–14 정상 강독.8/16주 시험+주제 혼합은 개별 전체강의 확정 미확인으로 보류.15 보강없음.9/24 녹화 시각 생성0.', 1127: '자체 화요일1–7/9–14 정상 이론·강좌 소개 및 토론, 목요일1/2주 조구성·배분과14주 토론만. 나머지 분임별 실제 현장 위치·날짜·운영 미배정으로 보류. 목10/8 한글날 휴업이라고 학교 원문이 쓰여 있어 교정·타요일 이동0.15평가·시험 제외.', 1128: '6개 교수 wholeplans 전부 확인. 이병태 계획 주차표에1–4 이병태/5 김예진/6 허유미/7–8 조은아/9–11 전호근/12–15 조영욱 실제 담당 명시. 해당 교수별 대면 원칙 또는 영상 선행 후 매주 강의실 토의 명시와 own HH가 일치. 각 분야 방법 차이·선행 녹화·평가 차이 보존.8주 정상 강의 명시10/22 예외,4주휴일 제외,16시험 보류. 강좌주제 일부14/15변형을 시간/방식 상충으로 오해0.', 1129: '대면 기본이고 필요시 온라인이라는 조건부 문구만. 현재1–7/9–15 이론·팀발표, 휴일/8·16시험제외. 중간고사 없다는 설명과8주표시험은 선택 없이8주held. 자료영상/기술주제와 실제 remote를 구분.', 1130: '교실 이론·발표·실습 정상1/2/4–7/10–14만.3주 단합대회/9주 야외수업 혼합은 실제 물리 배정 미확인으로 보류.9/24동영상 시각0,8·15·16시험 제외. 학교출결/과제 문구 전체보존.'}
groupWeeks={1103: {0: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]}, 1104: {0: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15]}, 1106: {0: [1, 2, 3, 4, 5, 6, 7, 11, 12, 13, 14]}, 1107: {0: [1, 2, 3, 4, 5, 6, 7, 11, 12, 13, 14]}, 1108: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1109: {0: [2, 3, 6, 7, 10, 13], 1: [1, 5, 9, 13, 15]}, 1110: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1111: {0: [1, 2, 3, 6, 7, 9, 10, 11, 12, 13, 14]}, 1112: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1113: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1114: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1115: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1116: {0: [1, 2, 3, 6, 7, 10, 11, 12, 15], 1: [1, 2, 3, 6, 7, 10, 11, 12, 15]}, 1118: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 8, 16]}, 1121: {0: [1, 2, 3, 4, 5, 9, 10, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 9, 10, 13, 14, 15]}, 1123: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1124: {0: [1, 3, 5, 7, 9, 10, 11, 12, 13, 14, 15]}, 1125: {0: [1, 2, 14, 15]}, 1126: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1127: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1: [1, 2, 14]}, 1128: {0: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]}, 1129: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1130: {0: [1, 2, 4, 5, 6, 7, 10, 11, 12, 13, 14], 1: [1, 2, 4, 5, 6, 7, 10, 11, 12, 13, 14]}}
groupPlan={1103: {0: 0}, 1104: {0: 0}, 1106: {0: 0}, 1107: {0: 0}, 1108: {0: 0, 1: 0}, 1109: {0: 0, 1: 0}, 1110: {0: 0}, 1111: {0: 0}, 1112: {0: 0}, 1113: {0: 0, 1: 0}, 1114: {0: 0, 1: 0}, 1115: {0: 0}, 1116: {0: 0, 1: 0}, 1118: {0: 0, 1: 0}, 1121: {0: 0, 1: 0}, 1123: {0: 0, 1: 0}, 1124: {0: 0}, 1125: {0: 0}, 1126: {0: 0, 1: 0}, 1127: {0: 0, 1: 0}, 1128: {0: 2}, 1129: {0: 0}, 1130: {0: 0, 1: 0}}
allowedWeekdays={};exceptDates={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
examExceptions={1103: {'2026-10-21'}, 1104: {'2026-10-26'}, 1118: {'2026-12-17', '2026-10-22'}, 1128: {'2026-10-22'}}
allowedNativeGroups={1103: [0], 1104: [0], 1106: [0], 1107: [0], 1108: [0, 1], 1109: [0, 1], 1110: [0], 1111: [0], 1112: [0], 1113: [0, 1], 1114: [0, 1], 1115: [0], 1116: [0, 1], 1118: [0, 1], 1121: [0, 1], 1123: [0, 1], 1124: [0], 1125: [0], 1126: [0, 1], 1127: [0, 1], 1128: [0], 1129: [0], 1130: [0, 1]}
calendarPlan={1103: 0, 1104: 0, 1106: 0, 1107: 0, 1108: 0, 1109: 0, 1110: 0, 1111: 0, 1112: 0, 1113: 0, 1114: 0, 1115: 0, 1116: 0, 1118: 0, 1121: 0, 1123: 0, 1124: 0, 1125: 0, 1126: 0, 1127: 0, 1128: 2, 1129: 0, 1130: 0}
assert len(HH)==23 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-1101];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
 assert native and not re.sub(r'[\s,]','',slot.sub('',c['sourceSchedule']))
 assert [('월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()) for m in native]==HH[n] or False,(n,c['sourceSchedule'],HH[n])
 if False:
  native=native[1:]
  assert [('월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()) for m in native]==HH[n]
 for plan,z in zip(plans,x['plans']):
  assert plan['campus']=={'seoul':'서울','global':'국제'}[c['campus']];assert plan['header']==['2026학년도 2학기 강의계획서'] and plan['lectureCode']==c['sourceEducationalVariants'][0]['lecture_cd']
  assert plan['queriedProfessorName'] in [v['teach_na'] for v in c['sourceEducationalVariants']]
  basic=next(s['rows'] for s in plan['educationalSections'] if s['section']=='기본정보');assert [r[1] for r in basic if r[0]=='학수번호']==[plan['lectureCode']]
  clocks=[r[1] for r in basic if r[0]=='강의시간강의실']
  normal=re.sub(r'\s+','',clocks[0] if clocks else '')
  if re.search(r"[월화수목금토일]\d{2}:\d{2}-",normal):
   for i,m in enumerate(native):
    if n in allowedNativeGroups and i not in allowedNativeGroups[n]:continue
    assert m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5] in normal and re.sub(r'\s+','',m[6]) in normal,(n,normal)
  shas[z['file']]=hashlib.sha256(pathlib.Path(z['file']).read_bytes()).hexdigest()
 rows=next(s['rows'] for s in plans[calendarPlan.get(n,0)]['educationalSections'] if s['section']=='주별강의내용');own={int(r[0][:-1]):r for r in rows if r and re.fullmatch(r'\d+주',r[0])};spans=[]
 for w in ws:
  r=own[w];a,b,z,d=map(int,re.fullmatch(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)',r[1]).groups());spans.append((dt.date(2026,a,b),dt.date(2026,z,d),r))
 def permitted(day):
  if day.isoformat() in exceptDates.get(n,set()) or (day.isoformat() in closed and day.isoformat() not in holidayExceptions.get(n,set())):return False
  if n in explicitDates and day.isoformat() not in explicitDates[n]:return False
  return day.isoformat() in examExceptions.get(n,set()) or (not dt.date(2026,10,20)<=day<=dt.date(2026,10,26) and not dt.date(2026,12,15)<=day<=dt.date(2026,12,21))
 def actualRoom(r,base):
  w=int(r[0][:-1]);room=roomOverride.get(n,{}).get(w,base)
  if w in roomOverride.get(n,{}):assert room in ' '.join(r),(n,w,room)
  if any(k[0] in roomUnconfirmedWeekdays.get(n,set()) and k[3]==base for k in HH[n]):room=''
  return room
 ownGroupProof=[]
 for gi,pi in groupPlan[n].items():
  pl=plans[pi];bas=next(z['rows']for z in pl['educationalSections']if z['section']=='기본정보');clock=next(r[1]for r in bas if r[0]=='강의시간강의실');m=native[gi];hh=m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5];assert pl['queriedProfessorName']+' '+hh in clock,(n,gi,clock)
  pr=next(z['rows']for z in pl['educationalSections']if z['section']=='주별강의내용');gr={int(r[0][:-1]):r for r in pr if r and re.fullmatch(r'\d+주',r[0])}
  for ww in groupWeeks[n][gi]:assert gr[ww][1]==own[ww][1],(n,gi,ww)
  ownGroupProof.append({'nativeGroupIndex':gi,'ownProfessorPlanIndex':pi,'ownProfessor':pl['queriedProfessorName'],'ownBasicClockLiteral':clock,'ownPhysicalWeeklyRowsLiteral':[gr[w]for w in groupWeeks[n][gi]]})
 meetings=[];independent=[]
 for ni,m in enumerate(native):
  if n in allowedNativeGroups and ni not in allowedNativeGroups[n]:continue
  if n in allowedWeekdays and ('월화수목금토일'.index(m[1])+1) not in allowedWeekdays[n]:continue
  wd='월화수목금토일'.index(m[1])+1
  for a,b,r in spans:
   if int(r[0][:-1]) not in groupWeeks.get(n,{}).get(ni,ws):continue
   day=a
   while day<=b:
    if day.isoweekday()==wd and permitted(day):meetings.append({'date':day.isoformat(),'weekday':wd,'startMinute':int(m[2])*60+int(m[3]),'endMinute':int(m[4])*60+int(m[5]),'classroom':actualRoom(r,m[6].strip())})
    day+=dt.timedelta(days=1)
 for a,b,r in spans:
  for ni,(wd,st,en,room) in enumerate(HH[n]):
   if n in allowedNativeGroups and ni not in allowedNativeGroups[n]:continue
   if n in allowedWeekdays and wd not in allowedWeekdays[n]:continue
   if int(r[0][:-1]) not in groupWeeks.get(n,{}).get(ni,ws):continue
   day=a+dt.timedelta(days=(wd-a.isoweekday())%7)
   while day<=b:
    if permitted(day):independent.append((day.isoformat(),wd,st,en,actualRoom(r,room)))
    day+=dt.timedelta(days=7)
 assert len(set(independent))==len(meetings);assert set(independent)=={(r['date'],r['weekday'],r['startMinute'],r['endMinute'],r['classroom']) for r in meetings}
 selected[c['sourceId']]=meetings;count+=len(meetings)
 proof.append({'ownProfessorGroupProof':ownGroupProof,'packetOrdinal':n,'sourceId':c['sourceId'],'wholePlans':plans,'nativeClock':c['sourceSchedule'],'ownCampus':plans[0]['campus'],'literalNativeHH':HH[n],'allowedPhysicalWeeksLiteral':ws,'physicalRowsLiteral':[r for a,b,r in spans],'semanticReason':reasons[n],'explicitUnscheduledDatesLiteral':sorted(exceptDates.get(n,set())),'independentDates':sorted({k[0] for k in independent}),'literalIndependentMeetings':[list(k) for k in sorted(independent)],'ownExamNormalExceptionsLiteral':sorted(examExceptions.get(n,set())),'ownHolidayNormalExceptionsLiteral':sorted(holidayExceptions.get(n,set())),'ownExplicitDatesLiteral':sorted(explicitDates.get(n,set())),'ownRoomOverridesLiteral':roomOverride.get(n,{}),'roomUnconfirmedWeekdaysLiteral':sorted(roomUnconfirmedWeekdays.get(n,set())),'allowedWeekdaysLiteral':sorted(allowedWeekdays.get(n,set())),'allowedNativeGroupsLiteral':sorted(allowedNativeGroups.get(n,set(range(len(native))))),'ownGroupWeeksLiteral':groupWeeks.get(n,{}),'calendarPlanIndex':calendarPlan.get(n,0),'newDateCount':len(meetings),'previousResearchDepartmentRemarks':c['departmentRemarks'],'remoteHoursGenerated':0})
for campus in ['seoul','global']:
 old=json.load(open(P.parent/'packet038-reviewed30'/f'khu-{campus}-2026-2.packet038-physical-groups-prepared.json'));(P/f'packet039-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside039'}

 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet039-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet039-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2946,'baselineDates':55033,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2946+len(selected),'totalDates':55033+count})
