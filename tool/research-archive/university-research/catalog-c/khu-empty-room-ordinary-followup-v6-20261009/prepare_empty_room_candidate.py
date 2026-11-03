# -*- coding: utf-8 -*-
from pathlib import Path
import copy,datetime as dt,hashlib,json,re,collections
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[3]
SRC=ROOT/'work/university-research/catalog-c/khu-ordinary-reservation-v2-20261008/current-native-operating-screen.json'
D={d['sourceId']:d for d in json.loads(SRC.read_text())['decisions']}
BASE={campus:ROOT/f'assets/timetable/khu-{campus}-2026-2.json' for campus in ['seoul','global']}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
originals={k:json.loads(p.read_text()) for k,p in BASE.items()}
rows=[r for v in originals.values() for r in v['courses']]
subset=[r for r in rows if not r['schedules'] and D.get(r['sourceId'],{}).get('screenReasons')==['nativeClockRoomMissingOrInvalid']]
assert len(subset)==73
SELECTED={0,1,3,4,5,10,11,18,19,20,21,24,25,26,31,32,38,39,40,41,42,43,49,50,51,52,53,54,55,56,60,61,62,63,64,65,66,68,70,71,72}
# Explicitly reviewed selectors refer to the independently saved ordered 73-row native census.
REASONS={2:'Student-designed personal experimental schedule; exact individualized allocation not published',6:'Individual research project in professor laboratory',7:'Individual research project in professor laboratory',8:'Each student designs their own experiment/research',9:'Self-directed research under advisor; personal allocation unpublished',12:'One-to-one feedback and independent self-chosen project',13:'Individual research and advisor interviews',14:'Published Chinese museum/site field trip, dates unallocated',15:'Published Tuesday professor meeting conflicts with native Saturday',16:'Published Tuesday professor meeting conflicts with native Saturday',17:'Research paper requiring professor permission; individual allocation remains unknown',22:'Explicit individual research through professor seminars; allocation unpublished',23:'Explicit individual research and separately held weekly experimental consultation',27:'Thesis groups and departmental approval; group allocation unspecified',28:'Explicit no actual class; automatic pass when comprehensive-design passed',29:'Explicit weekly one-to-one individual mentoring',30:'Explicit weekly one-to-one individual mentoring',33:'Independent research in advisor laboratory',34:'Individual advisor/assistant laboratory projects',35:'Independent research in advisor laboratory',36:'Independent research in advisor laboratory',37:'Explicit individual instruction in weekly plan',44:'Explicit professor one-to-one individual research',45:'Explicit professor one-to-one individual research',46:'Explicit professor one-to-one individual research',47:'Explicit professor one-to-one individual research',48:'Professor coordinates independent student research in weekly source',57:'Explicit source class time irrelevant and individually assigned placement',58:'Graduate laboratory placement/training allocation unpublished',59:'Assigned departmental laboratory thesis work',67:'Explicit team-by-team separately agreed interview times',69:'Explicit meeting time to be agreed with supervisor'}
assert SELECTED|set(REASONS)==set(range(73)) and not SELECTED&set(REASONS)
SLOT=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(([^()]*)\)')
DATE=re.compile(r'(\d+)/(\d+)\s*~\s*(\d+)/(\d+)')
EX=re.compile(r'시험|고사|중간평가|기말평가|종합평가|최종평가|보강|추석|휴강|휴일|midterm|final\s*(exam|test)',re.I)
CLOSED={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
TERM=(dt.date(2026,9,1),dt.date(2026,12,21))
CAL=ROOT/'work/university-research/catalog-u/khu-current-calendar-period-proof-20261008.json'
assert '동계 방학' in CAL.read_text()
reviews=[];proofs=[];selected={};inputs={str(SRC.relative_to(ROOT)):sha(SRC),str(CAL.relative_to(ROOT)):sha(CAL)}
for i,c in enumerate(subset):
    pr=[]; exclusions=[(dt.date(2026,10,20),dt.date(2026,10,26)),(dt.date(2026,12,15),dt.date(2026,12,21))]
    for record in D[c['sourceId']]['planProofs']:
        path=Path(record['file']);plan=json.loads(path.read_text());inputs[str(path.relative_to(ROOT))]=sha(path)
        assert plan['header']==['2026학년도 2학기 강의계획서']
        assert plan['lectureCode']==c['sourceEducationalVariants'][0]['lecture_cd']
        assert plan['queriedProfessorName'] in {v['teach_na'] for v in c['sourceEducationalVariants']}
        basic=next(s for s in plan['educationalSections'] if s['section']=='기본정보')
        clock=' '.join(str(rr) for rr in basic['rows'] if rr[0]=='강의시간강의실')
        for m in SLOT.finditer(c['sourceSchedule']):
            assert m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5] in re.sub(r'\s','',clock)
        for section in plan['educationalSections']:
            if section['section']!='주별강의내용':continue
            for row in section['rows']:
                if len(row)<3 or not re.fullmatch(r'\d+주',row[0]):continue
                match=DATE.fullmatch(row[1]);assert match
                a,b,z,d=map(int,match.groups());first,last=dt.date(2026,a,b),dt.date(2026,z,d)
                assert TERM[0]<=first<=last<=TERM[1]
                text=' '.join(row[2:]).strip()
                if (not text and row[0]=='16주') or EX.search(text):exclusions.append((first,last))
        pr.append({'file':str(path.relative_to(ROOT)),'SHA256':sha(path),'wholeOriginalEducationalPlan':plan})
    assert pr
    early=i in (71,72)
    if early:exclusions.append((dt.date(2026,10,20),TERM[1]))
    reviews.append({'censusIndex':i,'sourceId':c['sourceId'],'selected':i in SELECTED,'decision':'Current native+plan exact weekday/HH match; no conflicting individual allocation; empty rooms preserved' if i in SELECTED else REASONS[i],'sourceOriginalCourse':c,'currentOwnPlanProofs':pr,'heldRanges':[[a.isoformat(),b.isoformat()] for a,b in exclusions],'scopeNote':'Early first7weeks only; later two-professor outdoor/field content allocation mismatch held' if early else ''})
    if i not in SELECTED:continue
    slots=[('월화수목금토일'.index(m[1])+1,int(m[2])*60+int(m[3]),int(m[4])*60+int(m[5]),m[6].strip()) for m in SLOT.finditer(c['sourceSchedule'])]
    assert slots and all(a<b for _,a,b,_ in slots)
    meetings=[];day=TERM[0]
    while day<=TERM[1]:
        if day.isoformat() not in CLOSED and not any(a<=day<=b for a,b in exclusions):
            for weekday,a,b,room in slots:
                if day.isoweekday()==weekday:meetings.append({'date':day.isoformat(),'weekday':weekday,'startMinute':a,'endMinute':b,'classroom':room})
        day+=dt.timedelta(days=1)
    assert meetings, (i,c['sourceId'])
    selected[c['sourceId']]=meetings
    proofs.append({'sourceId':c['sourceId'],'nativeLiteralSchedule':c['sourceSchedule'],'nativeLiteralRoom':c['sourceClassroom'],'directSlots':[list(s) for s in slots],'literalDatedMeetings':meetings,'exclusions':[[a.isoformat(),b.isoformat()] for a,b in exclusions],'censusIndex':i})
totals=[]
for campus,old in originals.items():
    new=copy.deepcopy(old)
    for c in new['courses']:
        if c['sourceId'] not in selected:continue
        c['schedules']=selected[c['sourceId']];c['scheduleStatus']='scheduled'
        note='현재 2026-2 원문과 자체 계획서의 정규 요일·HH:mm에 따른 예약 계획. 강의실 미게시 구간은 빈값 그대로이며 다른 실/건물을 추정하지 않습니다. 원문 실습·연구·세미나 조건은 보존하며 개인별 출석·운영 완료 주장이 아닙니다. 학교 휴일/시험범위 및 원문 평가·보강·내용 미게시16주 구간은 보류하고 사용자 수업방식 선택 3종을 유지합니다.'
        if c['courseCode']=='GEE1638':note+=' 조깅과워킹은 두 교수의 후반 야외·현장 주차 원문 차이 때문에 9/1–10/19 앞부분만 예약합니다.'
        if c['courseCode']=='PREME2025':note+=' 원문 9/15–9/21 추석 표기는 실제 달력과 충돌하므로 그 원문 범위도 추가 보류하며 실제 휴일로 수정하지 않습니다.'
        c['departmentRemarks']={k:v+'\n'+note for k,v in c['departmentRemarks'].items()}
        c['semanticOperatingReview']={'priorHoldReason':'nativeClockRoomMissingOrInvalid','sourceSnapshot':'2026-10-08','roomUnpublished':True,'actualAttendanceConfirmed':False,'meaning':'Known native clock exactly corroborated by own current plan; original empty classroom retained; no title-only special-class exclusion.'}
    prior={c['sourceId']:c for c in old['courses']}
    assert all(c==prior[c['sourceId']] for c in new['courses'] if c['sourceId'] not in selected)
    new.update({'researchOnly':True,'completionClaim':False,'actualModelValidationPending':True,'productionIntegrationEnabled':False,'semanticReviewRevision':'v6-20261009'})
    new.pop('actualModelValidation',None)
    (OUT/f'khu-{campus}-2026-2.empty-room-research-v6-20261009.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
    totals.append({'campus':campus,'native':len(new['courses']),'scheduled':sum(bool(c['schedules']) for c in new['courses']),'dates':sum(len(c['schedules']) for c in new['courses'])})
proof={'currentNative':4666,'currentScheduled':1906,'currentDates':35970,'emptyRoomOnlyReviewed':73,'eligibleNewCourses':len(selected),'newDates':sum(map(len,selected.values())),'heldReviewed':73-len(selected),'datasets':totals,'proofs':proofs,'baselineSHA256':{str(p.relative_to(ROOT)):sha(p) for p in BASE.values()},'sourceInputsSHA256':inputs,'allOtherFullObjectsUnchanged':4666-len(selected),'allPrior1906DatesUnchanged':True,'actualModelValidationPending':True,'sdkUsed':False,'productChanged':False,'completionClaim':False,'impossibleClaim':False}
(OUT/'independent-native-clock-date-proof.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
(OUT/'all73-individual-operating-source-review.json').write_text(json.dumps({'reviews':reviews,'candidateReviewedScope':len(reviews),'SDKUsed':False},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:proof[k] for k in ['eligibleNewCourses','newDates','heldReviewed','datasets']},ensure_ascii=False))
