# coding: utf-8
import json,pathlib,hashlib,re,copy,datetime as dt
P=pathlib.Path(__file__).parent
xs=json.load(open(P/'packet037-30-full-source-prepared.json'))
W=[1,2,3,4,5,6,7,9,10,11,12,13,14,15]
HH={1041: [(4, 1170, 1305, '호701')], 1042: [(2, 720, 795, '청710'), (4, 720, 795, '청710')], 1043: [(2, 810, 885, '청710'), (4, 810, 885, '청710')], 1044: [(2, 810, 885, '청308'), (4, 810, 885, '청308')], 1045: [(2, 900, 975, '청713'), (4, 900, 975, '청713')], 1046: [(2, 720, 795, '청711'), (4, 720, 795, '청711')], 1047: [(2, 900, 975, '청711'), (4, 900, 975, '청711')], 1048: [(2, 990, 1065, '청712'), (4, 990, 1065, '청712')], 1049: [(2, 900, 975, '청706'), (4, 900, 975, '청706')], 1053: [(1, 810, 885, '청207'), (3, 810, 885, '청207')], 1054: [(1, 900, 975, '청207'), (3, 900, 975, '청207')], 1058: [(5, 720, 885, '청203')], 1061: [(2, 900, 975, '청207'), (4, 900, 975, '청207')], 1062: [(2, 900, 975, '청207'), (4, 900, 975, '청207')], 1063: [(1, 720, 795, '청207'), (3, 720, 795, '청207')], 1064: [(1, 720, 795, '청207'), (3, 720, 795, '청207')], 1065: [(1, 630, 705, '청309'), (3, 630, 705, '청309')], 1066: [(1, 630, 705, '청309'), (3, 630, 705, '청309')], 1067: [(1, 630, 705, '청307'), (3, 630, 705, '청307')], 1068: [(1, 630, 705, '청307'), (3, 630, 705, '청307')], 1069: [(2, 720, 795, '청207'), (4, 720, 795, '청207')], 1070: [(2, 720, 795, '청207'), (4, 720, 795, '청207')]}
weeks={1041: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11], 1042: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1043: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1049: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1044: [1, 2, 3, 4, 5, 6, 7, 9, 11, 12, 13, 14], 1045: [1, 2, 3, 4, 5, 6, 7, 9, 11, 12, 13, 14], 1046: [1, 2, 3, 6, 7, 10, 12, 13, 14], 1047: [1, 2, 3, 6, 7, 10, 12, 13, 14], 1048: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], 1053: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], 1054: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], 1058: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14], 1061: [2, 4, 5, 6, 9, 11, 12, 14, 15], 1062: [2, 4, 5, 6, 9, 10, 12, 13, 15], 1063: [1, 2, 4, 6, 7, 10, 11, 12, 15], 1064: [1, 2, 3, 5, 7, 10, 11, 12, 15], 1065: [1, 2, 4, 6, 7, 9, 10, 11, 14], 1066: [1, 2, 3, 5, 6, 9, 10, 12, 13, 15], 1067: [1, 2, 3, 5, 6, 9, 10, 11, 13, 15], 1068: [1, 2, 4, 6, 7, 9, 10, 11, 13, 14], 1069: [1, 2, 4, 6, 7, 9, 11, 12, 14, 15], 1070: [1, 2, 3, 5, 7, 9, 10, 12, 13, 15]}
reasons={1041: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.', 1042: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.', 1043: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.', 1044: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.', 1045: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.', 1046: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.', 1047: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.', 1048: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.', 1049: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.', 1050: '현재 계획서 기본정보 외 전체 교육 공란. native HH만으로 운영을 생성하지 않고 보류.', 1051: '현재 계획서 기본정보 외 전체 교육 공란. native HH만으로 운영을 생성하지 않고 보류.', 1052: '명시 플립러닝 동영상+강의실 운영이나 날짜별 physical 그룹 배정 미확인, 특강 HH 미확인. 보류.', 1053: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.', 1054: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.', 1055: '팀티칭 전체 현재 원문을 읽었으나 담당별 실제 날짜 배정/명시 날짜 순서·방식 상충 우선순위를 추가 검토 중. 임의 선택 없이 이번 후보 보류.', 1056: '팀티칭 전체 현재 원문을 읽었으나 담당별 실제 날짜 배정/명시 날짜 순서·방식 상충 우선순위를 추가 검토 중. 임의 선택 없이 이번 후보 보류.', 1057: '현재 native 전체만, 계획서 캐시0. 기존 currentOperatingCorrection 철회 0.', 1058: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.', 1059: '팀티칭 전체 현재 원문을 읽었으나 담당별 실제 날짜 배정/명시 날짜 순서·방식 상충 우선순위를 추가 검토 중. 임의 선택 없이 이번 후보 보류.', 1060: '팀티칭 전체 현재 원문을 읽었으나 담당별 실제 날짜 배정/명시 날짜 순서·방식 상충 우선순위를 추가 검토 중. 임의 선택 없이 이번 후보 보류.', 1061: '두 교수 current literal 날짜·대면 운영 일치 그룹만. 과거 9월2일(월) 최초 출석 문구와 현재 9월1일(화) 날짜 상충은 Sept1 제외하여 보존; 시험/특강/관람 제외. S30 Dec10 대면/영상 상충도 제외.', 1062: '두 교수 current literal 날짜·대면 운영 일치 그룹만. 과거 9월2일(월) 최초 출석 문구와 현재 9월1일(화) 날짜 상충은 Sept1 제외하여 보존; 시험/특강/관람 제외. S30 Dec10 대면/영상 상충도 제외.', 1063: '학교 자체 전반부/후반부 담당 계획 우선순위 원문을 보존. 이번에는 두 교수 실제 같은 날짜·대면 배정이 일치한 그룹만, 상충된 후반부 날짜는 별도 후속 검토로 유지. 평가·특강·방문 시각 생성 0.', 1064: '학교 자체 전반부/후반부 담당 계획 우선순위 원문을 보존. 이번에는 두 교수 실제 같은 날짜·대면 배정이 일치한 그룹만, 상충된 후반부 날짜는 별도 후속 검토로 유지. 평가·특강·방문 시각 생성 0.', 1065: 'Nov23 대면/녹화 상충 제외, 다른 두 교수 literal 대면 날짜 일치 그룹9만.', 1066: 'Dec7 대면/녹화 상충 제외, 다른 두 교수 literal 대면 날짜 일치 그룹10만.', 1067: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.', 1068: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.', 1069: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.', 1070: '자체 현재 전체 원문과 교수/분반/HH/각 주차 운영을 실제 읽음. 명시 대면 정상 그룹만 좁게 검토; 원문 이수·대상 제한, 녹화/평가/외부/개별 배정 및 상충은 모두 보존.'}
groupWeeks={1041: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11]}, 1042: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1043: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1049: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]}, 1044: {0: [1, 2, 3, 4, 5, 6, 7, 9, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 11, 12, 13, 14]}, 1045: {0: [1, 2, 3, 4, 5, 6, 7, 9, 11, 12, 13, 14], 1: [1, 2, 3, 4, 5, 6, 7, 9, 11, 12, 13, 14]}, 1046: {0: [1, 2, 3, 6, 7, 10, 12, 13, 14], 1: [1, 2, 3, 6, 7, 10, 12, 13, 14]}, 1047: {0: [1, 2, 3, 6, 7, 10, 12, 13, 14], 1: [1, 2, 3, 6, 7, 10, 12, 13, 14]}, 1048: {0: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], 1: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]}, 1053: {1: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]}, 1054: {1: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]}, 1058: {0: [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14]}, 1061: {0: [2, 4, 5, 6, 9, 11, 14, 15], 1: [2, 12]}, 1062: {0: [2, 4, 5, 6, 9, 12, 15], 1: [2, 10, 13]}, 1063: {0: [2], 1: [1, 4, 6, 7, 10, 11, 12, 15]}, 1064: {0: [3, 7, 10, 11, 12, 15], 1: [1, 2, 5]}, 1065: {0: [2, 11, 14], 1: [1, 4, 6, 7, 9, 10]}, 1066: {0: [3, 6, 10, 13], 1: [1, 2, 5, 9, 12, 15]}, 1067: {0: [3, 6, 10, 11, 13], 1: [1, 2, 5, 9, 15]}, 1068: {0: [2, 11, 14], 1: [1, 4, 6, 7, 9, 10, 13]}, 1069: {0: [1, 4, 6, 7, 9, 11, 14], 1: [2, 12, 15]}, 1070: {0: [1, 2, 9, 12, 15], 1: [3, 5, 7, 10, 13]}}
groupPlan={1041: {0: 0}, 1042: {0: 0, 1: 0}, 1043: {0: 0, 1: 0}, 1049: {0: 0, 1: 0}, 1044: {0: 0, 1: 0}, 1045: {0: 0, 1: 0}, 1046: {0: 0, 1: 0}, 1047: {0: 0, 1: 0}, 1048: {0: 0, 1: 0}, 1053: {1: 0}, 1054: {1: 0}, 1058: {0: 0}, 1061: {0: 0, 1: 0}, 1062: {0: 0, 1: 0}, 1063: {0: 0, 1: 0}, 1064: {0: 1, 1: 1}, 1065: {0: 0, 1: 0}, 1066: {0: 0, 1: 0}, 1067: {0: 0, 1: 0}, 1068: {0: 0, 1: 0}, 1069: {0: 0, 1: 0}, 1070: {0: 0, 1: 0}}
allowedWeekdays={};exceptDates={};holidayExceptions={};explicitDates={};roomOverride={};roomUnconfirmedWeekdays={}
examExceptions={1048: {'2026-10-22', '2026-10-20'}, 1053: {'2026-10-21'}, 1054: {'2026-10-21'}}
allowedNativeGroups={1041: [0], 1042: [0, 1], 1043: [0, 1], 1049: [0, 1], 1044: [0, 1], 1045: [0, 1], 1046: [0, 1], 1047: [0, 1], 1048: [0, 1], 1053: [1], 1054: [1], 1058: [0], 1061: [0, 1], 1062: [0, 1], 1063: [0, 1], 1064: [0, 1], 1065: [0, 1], 1066: [0, 1], 1067: [0, 1], 1068: [0, 1], 1069: [0, 1], 1070: [0, 1]}
calendarPlan={1041: 0, 1042: 0, 1043: 0, 1044: 0, 1045: 0, 1046: 0, 1047: 0, 1048: 0, 1049: 0, 1053: 0, 1054: 0, 1058: 0, 1061: 0, 1062: 0, 1063: 0, 1064: 1, 1065: 0, 1066: 0, 1067: 0, 1068: 0, 1069: 0, 1070: 0}
assert len(HH)==22 and len(reasons)==30
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
warning='강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.'
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
proof=[];selected={};count=0;shas={}
for n,ws in sorted(weeks.items()):
 x=xs[n-1041];c=x['originalWholeObject'];plans=[z['originalWholeEducationPlan'] for z in x['plans']];native=list(slot.finditer(c['sourceSchedule']))
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
 old=json.load(open(P.parent/'packet036-reviewed30'/f'khu-{campus}-2026-2.packet036-physical-groups-prepared.json'));(P/f'packet037-prior-{campus}-whole.json').write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n');new=copy.deepcopy(old)
 for c in new['courses']:
  if c['sourceId'] not in selected:continue
  assert not c['schedules'];c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled';c['sourcePartialCoverage']=True
  note='현재 2026-2 개별 강의계획서의 명시 대면 기본과 원문 날짜를 대조한 부분만 예약합니다. 공휴일·시험·명시 원격·별도 운영은 배치하지 않으며, 자체 원문에서 정상수업으로 확인된 시험기간 중 예외 날짜만 별도 근거로 예약합니다. 원문 전체 운영·이수 제한·과제 및 예외는 별도 기록에 보존합니다. 사용자 강의 방식은 유지하며 실제 출석·최신 폐강/변경 전체 확인 완료는 아닙니다.'
  c['departmentRemarks']={k:v.replace(warning+'\n','').replace(warning,'').replace('현재 원문 수업방법 표의 온라인강의가 별도 선택됨(자료실 e-campus와 별개). 날짜별 실시간/녹화 배정 미공개로 이전 일반예약을 새 카탈로그 후보에서 보류합니다. 기존 개인 저장 시간표·Drive 데이터 변경 없음.','')+'\n'+note for k,v in c['departmentRemarks'].items()};c['semanticOperatingReview']={'sourcePartialCoverage':True,'publishedPhysicalWeekScopeOnly':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-08','packet':'outside037'}

 oldmap={c['sourceId']:c for c in old['courses']};assert all(c==oldmap[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
 (P/f'khu-{campus}-2026-2.packet037-physical-groups-prepared.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
(P/'packet037-independent-proof.json').write_text(json.dumps({'completionClaim':False,'SDKExecutions':0,'addedCount':len(selected),'addedDates':count,'proofs':proof,'originalPlanSHA256':shas,'baselineScheduled':2915,'baselineDates':54621,'rawCampusClockPeriodAndAllOriginalFieldsPreserved':True},ensure_ascii=False,indent=2)+'\n');print({'newCourses':len(selected),'newDates':count,'totalCourses':2915+len(selected),'totalDates':54621+count})
