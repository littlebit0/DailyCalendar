"""Research-only conservative weekly reservations, retaining existing dated plans."""
import copy, datetime as dt, hashlib, json, re
from pathlib import Path
OUT=Path(__file__).resolve().parent
screen=json.loads((OUT/'khu-native-plan-screen.json').read_text())
shortlist={d['sourceId']:d for d in screen['decisions'] if d['ordinaryReviewShortlistOnly']}
SLOT=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
EXCEPTION=re.compile(r'시험|고사|추석|공휴일|연휴|휴강|휴일|midterm|final\s*(exam|test)|no\s*class|holiday|vacation',re.I)
CLOSED={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
BEGIN=dt.date(2026,9,1);END=dt.date(2026,12,21)
GLOBAL_EXAMS=[(dt.date(2026,10,20),dt.date(2026,10,26)),(dt.date(2026,12,15),dt.date(2026,12,21))]
proofs=[];datasets=[]
NOTE=('현재 공식 공개 주간 요일·시작/끝 시각·강의실과 학교 자체 2026-2 학기 범위의 정규 예약 계획입니다. 실제 출석·개별 휴강 확정이 아닙니다. 개별 날짜가 미게시라는 이유만으로 정규 예약을 보류하지 않았습니다. 원문 캠퍼스(서울/국제)·수강 대상·이수구분·학점·교수·비고를 보존합니다. 학교 중간시험10/20~26·기말시험12/15~21, 공휴일 및 원문 계획의 별도 시험·휴일 주차는 보수적으로 예약 보류하며 개별 시험·보강을 추정하지 않습니다. 공개 집중·비동기·혼합·실습/개별 배정·시각/실 충돌은 별도 보류합니다. 사용자 강의방식 선택은 실제 원격 운영의 증명이 아닙니다.')
for original in sorted(OUT.glob('baseline-khu-*2026-2.json')):
    baseline=json.loads(original.read_text()); candidate=copy.deepcopy(baseline);added=0
    for course in candidate['courses']:
        if course['sourceId'] not in shortlist:continue
        decision=shortlist[course['sourceId']];slots=[]
        for m in SLOT.finditer(course['sourceSchedule']):
            weekday='월화수목금토일'.index(m[1])+1;start=int(m[2])*60+int(m[3]);end=int(m[4])*60+int(m[5]);room=m[6].strip();slots.append((weekday,start,end,room))
        assert slots and all(r and 0<=a<b<=1440 for _,a,b,r in slots)
        excluded=list(GLOBAL_EXAMS);source_exceptions=[]
        for proof in decision['planProofs']:
            plan=json.loads(Path(proof['file']).read_text())
            for section in plan['educationalSections']:
                if section['section']!='주별강의내용':continue
                for row in section['rows']:
                    if len(row)<3 or not re.fullmatch(r'\d+주',row[0]) or not EXCEPTION.search(' '.join(row[2:])):continue
                    interval=re.fullmatch(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)',row[1]);assert interval,(course['sourceId'],row)
                    a,b,c,d=map(int,interval.groups());start=dt.date(2026,a,b);end=dt.date(2026,c,d);assert BEGIN<=start<=end<=END
                    excluded.append((start,end));source_exceptions.append({'sourcePlan':proof['file'],'row':row,'reservationExcludedRange':[start.isoformat(),end.isoformat()]})
        meetings=[]
        for weekday,start,end,room in slots:
            day=BEGIN
            while day<=END:
                if day.isoweekday()==weekday and day.isoformat() not in CLOSED and not any(a<=day<=b for a,b in excluded):meetings.append({'date':day.isoformat(),'weekday':weekday,'startMinute':start,'endMinute':end,'classroom':room})
                day+=dt.timedelta(days=1)
        assert meetings
        course['schedules']=meetings;course['scheduleStatus']='scheduled'
        for department,note in course['departmentRemarks'].items():
            course['departmentRemarks'][department]=note.replace('강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.',NOTE)
        course['reservationEvidence']={'kind':'officialCurrentOrdinaryWeeklyReservation','individualDatedAttendanceConfirmed':False,'currentNativeCampus':{'seoul':'서울','global':'국제'}[course['campus']],'sourcePlanExceptionRanges':source_exceptions}
        proofs.append({**decision,'plannedReservations':len(meetings),'sourceExceptionRanges':source_exceptions,'eligibleOnlyForConservativeOrdinaryReservation':True,'actualAttendanceConfirmed':False});added+=1
    old={c['sourceId']:c for c in baseline['courses']};assert all(c==old[c['sourceId']] for c in candidate['courses'] if c['sourceId'] not in shortlist)
    assert len({c['sourceId'] for c in candidate['courses']})==len(old)
    candidate.update({'researchOnly':True,'completionClaim':False,'wholeOperatingReviewComplete':False,'actualAttendanceConfirmed':False,'verificationScope':'Existing fifty dated offering records unchanged. Additional conservative ordinary weekly reservations; exact attendance, current cumulative closures and future changes unconfirmed.'})
    name=f"khu-{candidate['campus']}-2026-2.ordinary-reservation-research-v1-20261008.json";b=(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n').encode();(OUT/name).write_bytes(b)
    datasets.append({'file':name,'sha256':hashlib.sha256(b).hexdigest(),'courses':len(old),'existingScheduled':sum(bool(c['schedules']) for c in baseline['courses']),'addedOrdinary':added,'scheduled':sum(bool(c['schedules']) for c in candidate['courses']),'meetings':sum(len(c['schedules']) for c in candidate['courses']),'baselineSHA256':hashlib.sha256(original.read_bytes()).hexdigest()})
report={'completionClaim':False,'productionEdited':False,'sdkUsed':False,'actualModelValidationPending':True,'datasets':datasets,'addedOrdinary':len(proofs),'proofs':proofs}
(OUT/'khu-ordinary-reservation-v1-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in report.items() if k!='proofs'})
