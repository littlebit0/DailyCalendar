"""2026-10-24 수강편람 재조회에서 실제로 바뀐 강의실만 반영(시각은 그대로).
기존 11311 정정과 같은 방식: originalEducationalRecord는 보존, 표시·일정 강의실과 currentOfficialClassroomCorrection을 고친다.
시각·강의실 짝은 원문 suupTimes·suupRoomNms 같은 순서(기존 변환 규칙). 이미 반영된 강좌는 건너뛴다."""
import json,sys,re
CH={
 'hanyang/erica/2026-2/24136':('화(09:00-10:30),목(10:30-12:00)','ERICA 제1공학관 203 강의실,ERICA 제1공학관 203 강의실','ERICA 컨퍼런스홀 201 강의실,ERICA 컨퍼런스홀 101 강의실','제1공학관 203·203→컨퍼런스홀 201(화)·101(목)'),
 'hanyang/seoul/2026-2/10351':('목(16:00-17:30),목(17:30-19:00)','서울 재성토목관 201강의실,서울 재성토목관 201강의실','서울 재성토목관 103강의실,서울 재성토목관 103강의실','재성토목관 201→103'),
}
pat=re.compile(r'([월화수목금토일])\((\d\d):(\d\d)-(\d\d):(\d\d)\)')
for p in sys.argv[1:]:
  d=json.load(open(p,encoding='utf-8'));n=0
  for c in d['courses']:
    if c['sourceId'] not in CH or 'currentOfficialClassroomCorrection' in c['metadata']: continue
    sch,old,new,desc=CH[c['sourceId']]
    assert c['sourceSchedule']==sch and c['sourceClassroom']==old
    slot={}
    for m,room in zip(pat.finditer(sch),new.split(',')):
      slot[('월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]))]=room.strip()
    oldrooms={r.strip() for r in old.split(',')}
    c['sourceClassroom']=new
    for sl in c['schedules']+c['metadata']['verifiedUndatedPublishedClockRoomSlots']:
      assert sl['classroom'] in oldrooms; sl['classroom']=slot[(sl['weekday'],sl['startMinute'])]
    note=f' / 2026-10-24 공개 수강편람 재조회 강의실 변경: {desc}. 현재 표시를 교정하며 원래 공개 강의실은 메타데이터에 보존합니다.'
    c['remarks']+=note
    for k in c['departmentRemarks']: c['departmentRemarks'][k]+=note
    c['metadata']['currentOfficialClassroomCorrection']={'originalSourceClassroom':old,'changedSourceClassroom':new,'effectiveCensusDate':'2026-10-24','sourceURL':'https://portal.hanyang.ac.kr/sugang/SgscAct/findSuupSearchSugangSiganpyo.do','sourceAccess':'robots.txt Disallow: / 경로를 사용자 결정에 따라 직접 조회','currentTerm':'2026-2','sourceScheduleUnchanged':True}
    n+=1
  open(p,'w',encoding='utf-8').write(json.dumps(d,ensure_ascii=False,indent=2)+'\n');print(p,n)
