"""Preserve whole actual public offerings; project only three reviewed regular plans."""
import collections
import datetime as dt
import hashlib
import html
import json
import pathlib
import re
P = pathlib.Path(__file__).resolve().parent
URL = 'https://welcome.dgist.ac.kr/ucs/ucsqProfRespSbjtInq/index.do'
variants = collections.defaultdict(list)
for curriculum in ['2020', '2024', '2014']:
    for row in json.loads((P / f'dgist2026-2-{curriculum}-current-recheck-20261008.json').read_text()):
        variants[(row['SBJT_NO'],row['CLSS_NO'])].append((curriculum,row))
plans = {(x['code'],x['section']):x for x in json.loads((P / 'dgist-three-current-plan-recheck-20261008.json').read_text())}
for x in json.loads((P / 'dgist-two-additional-plan-recheck-20261008.json').read_text()):
    plans[(x['code'],x['section'])]=x
assert len(variants) == 569
clock = re.compile(r'([월화수목금토일])(\d\d):(\d\d)-(\d\d):(\d\d)\(([^()]*)\)')
start, end = dt.date(2026,8,24),dt.date(2026,12,11)
closed = {dt.date(2026,9,24),dt.date(2026,9,25),dt.date(2026,10,5),dt.date(2026,10,9)}
exam = [(dt.date(2026,10,12),dt.date(2026,10,16)),(dt.date(2026,12,7),end)]
courses = []
for key, values in variants.items():
    row = values[0][1]
    assert all(x['TLSN_TIME']==row['TLSN_TIME'] and x['PNT']==row['PNT'] and x['PROF_NM']==row['PROF_NM'] for _,x in values)
    notes = []
    for curriculum,x in values:
        notes.append(f"{curriculum} 교육과정: {x['SBJT_NM']} · {x['CPTN_NM']}")
        for field,label in [('REMK','비고'),('SUB_SBJT_NO_CHK','선수과목'),('FORS_SBJT_INFM','선수학습'),('SUB_SBJT_NO_INFO','동일과목'),('TRACK_LIST','트랙')]:
            if x.get(field): notes.append(f"{curriculum} {label}: {html.unescape(str(x[field]))}")
    if row.get('ENG_LT_YN')=='Y': notes.append('영어강의: Y')
    c = {'sourceId':f'dgist/unknown/2026/2/{key[0]}-{key[1]}','campus':'unknown','academicYear':2026,'semester':'2','courseCode':key[0],'section':key[1],'courseName':row['SBJT_NM'],'professor':row['PROF_NM'],'credits':float(row['PNT']),'departments':[row['ASGN_SUST_NM']],'departmentCredits':{row['ASGN_SUST_NM']:float(row['PNT'])},'classification':row['CPTN_NM'] if len({x['CPTN_NM'] for _,x in values})==1 else '', 'remarks':'\n'.join(dict.fromkeys(notes)), 'sourceSchedule':row['TLSN_TIME'],'sourceEducationalMetadata':{'curriculumVariants':[{'curriculum':y,'fields':x} for y,x in values]},'scheduleStatus':'unrecognized','schedules':[]}
    if key in plans:
        proof = plans[key]['fields']
        assert proof['INFO'].replace(' ','')==row['TLSN_TIME'].replace(' ','')
        assert clock.sub('',row['TLSN_TIME']).replace(',','').strip()==''
        schedules = []
        for m in clock.finditer(row['TLSN_TIME']):
            day,h,minute,eh,em,room=m.groups()
            weekday='월화수목금토일'.index(day)+1
            date=start
            while date<=end:
                if date.isoweekday()==weekday and date not in closed and not any(a<=date<=b for a,b in exam):
                    schedules.append({'weekday':weekday,'startMinute':int(h)*60+int(minute),'endMinute':int(eh)*60+int(em),'classroom':room.strip(),'date':date.isoformat()})
                date+=dt.timedelta(days=1)
        schedules.sort(key=lambda x:(x['date'],x['startMinute']))
        assert schedules
        c.update(scheduleStatus='scheduled',schedules=schedules,period={'startDate':start.isoformat(),'endDate':end.isoformat()},scheduleEvidenceKind='publishedRegularPlan',actualAttendanceConfirmed=False,individualWeeklyOperationConfirmed=key[0]!='BE204')
        c['remarks']+='\n학교 공시의 정규 수업 계획입니다. 시험 주간·공휴일은 제외했으며 실제 시험·보강 시각은 별도 확인이 필요합니다.'
        if key[0]=='BE101a':c['remarks']+='\n준비물: 개인 노트북, Python 개발 환경, LMS 접속 환경. 온라인 학습 자료와 과제는 수업 자체의 원격 전환을 뜻하지 않습니다.'
        if key[0]=='BE201':c['remarks']+='\n선수학습 권장: Python 프로그래밍, 선형대수와 미적분.'
        if key[0]=='BE204':c['remarks']+='\n주차별 내용이 일부만 게시된 학교 공시 계획입니다. 공학용 계산기가 필요할 수 있습니다.'
        if key == ('BE206','04'):c['remarks']+='\n실험 계획: ELVIS·LabVIEW 및 회로 측정 실습. 창의실험과 발표는 게시된 주차 계획을 따릅니다.'
        if key == ('BR202','01'):c['remarks']+='\n이론 강의와 토론 수업. 휴대폰은 끄거나 무음으로 하고 노트북·태블릿은 수업 활동에만 사용합니다.'
        c['sourceOperatingPlan']=proof
    else:c['remarks']+='\n실제 주차별 운영 검증 전으로 시간표 자동 추가를 보류합니다.'
    c['departmentRemarks']={row['ASGN_SUST_NM']:c.pop('remarks')}
    c['sourceClassroom']=', '.join(dict.fromkeys(m.group(6).strip() for m in clock.finditer(row['TLSN_TIME'])))
    courses.append(c)
output={'schemaVersion':2,'universityId':'dgist','campus':'unknown','campusName':'위치 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-10-08','sourceUrl':URL,'completionClaim':False,'wholeOperatingAuditFinished':False,'courses':courses}
file=P/'dgist-unknown-2026-2.five-reviewed-next.json'
file.write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
audit={'candidate':file.name,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'wholePublicOfferings':len(courses),'reviewedRegularPlans':len(plans),'datedMeetings':sum(len(x['schedules']) for x in courses),'held':len(courses)-len(plans),'wholeCurrentListsUnchanged':True,'classificationVariantsPreserved':True,'regularDateStart':str(start),'regularDateEnd':str(end),'examWeekClocksUnknownExcluded':[[str(a),str(b)] for a,b in exam],'currentFullOperatingApproval':False,'productionRegistered':False,'completionClaim':False}
(P/'dgist-five-reviewed-next-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(audit,ensure_ascii=False))
