"""Five individually reviewed public dated plans; no general weekly expansion."""
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
ROOT = Path(__file__).resolve().parent
source = json.loads((ROOT/'changwon-current-educational-rows-20261008.json').read_text())
byid = {}
for r in source:
    byid.setdefault((r['code'],r['section']), []).append(r)
# Explicitly printed teacher-plan dates; source conflicts/field visits/exam clocks held.
selected = {
 'EDA0077': ('09-02 09-09 09-16 09-23 09-30 10-07 10-14 10-21 11-04 11-11 11-18 11-25 12-02 12-09', 540,720,'11209'),
 'EDA0093': ('09-01 09-08 09-15 09-22 09-29 10-06 10-13 10-20 10-27 11-10 11-17 12-01',900,1080,'11306'),
 'EDA0108': ('09-02 09-09 09-16 09-23 09-30 10-07 10-14 10-21 11-04 11-11 11-18 11-25 12-02',780,960,'11209'),
 'EDA0112': ('09-03 09-10 09-17 10-01 10-08 10-15 10-22 10-29 11-05 11-12 11-19 11-26 12-03',600,780,'11306'),
 'GEA7537': ('09-01 09-08 09-29 10-06 10-13 10-20',900,1080,'81101'),
}
notes={
 'EDA0077':'10월28일 현장조사는 현장 시각·장소 미확인으로 제외했습니다. 11월3일·12월8일 과제 마감은 수업으로 생성하지 않았습니다. 12월9일 워크숍은 개별 계획의 명시된 날짜이며 공통 보강주만으로 제외하지 않았습니다.',
 'EDA0093':'11월3일 견학 시각·장소와11월24일 임시휴강 예정/수업계획 충돌은 보류했습니다. 12월15일 종합평가는 실제 출석 시각 미확인으로 제외했습니다.',
 'EDA0108':'9월16일 명시된 종료14:30을 적용했습니다. 10월28일은 계획에 없으므로 추가하지 않았습니다. 12월9일 기말 발표는 주차14·16 중복 기재와 실제 시험 시각 미확인으로 보류했습니다.',
 'EDA0112':'9월24일 수업은 계획의10월1일로, 원래10월1일 주제는10월8일로 옮겨졌습니다. 10월8일 중복 주제는 출석 일정을 중복 생성하지 않았습니다. 11월19일은 수능 임시휴강 예정1AB(09~10)와 수업 시작10시가 겹치지 않습니다. 12월17일 과제 제출은 실제 수업으로 생성하지 않았습니다.',
 'GEA7537':'집중이수의 명시된 여섯 이론 수업 날짜와10월23~25일 금·토·일 현장 운영의 명시된9개 시각만 반영했습니다. 현장 운영 장소는 원문에 없어 비워 두었습니다. 담당교수는 주차별 원문에 보존했습니다. 나머지 주간 반복은 생성하지 않았습니다.'
}
common='현재 공개된 수업 계획이며 실제 출석 확인을 의미하지 않습니다. 학기 경계는9월1일 개강~12월21일 동계방학 직전12월20일로 산정했으며 마지막 수업 날짜를 임의 생성하지 않았습니다. 교시1A~9B의30분 표시는 공개 시간표 예약 블록이며 실제50분/75분 강의 길이는 추정하지 않았습니다. 비고의 학과확인 공개 상세가 비어 있어 수강 가능 소속은 학교에서 재확인해야 합니다.'
rows=[];cases=[];files={}
for (code,section), records in sorted(byid.items()):
    r=records[0]; dept=r['openingDepartment']; meetings=[]; education={ 'originalPublicRows':records, 'actualAttendanceConfirmed':False, 'wholeOperatingReviewComplete':False }
    if code in selected and section=='00':
        p=ROOT/'public-plans-20261008'/f'{code}-{section}.json';plan=json.loads(p.read_text());files[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest()
        assert plan['fields']['학수번호']==code and plan['fields']['분반']==section
        assert plan['fields']['강의시간(장소)']==r['schedule']
        assert plan['fields']['수업운영방식']=='대면'
        education['currentPublicPlan']=plan
        dates,start,end,room=selected[code]
        for md in dates.split():
            date=dt.date.fromisoformat('2026-'+md); a,b=start,end;place=room;kind='publishedNominalReservation'
            if (code,md) in [('EDA0077','10-21'),('EDA0093','10-20'),('EDA0112','10-22')]:
                expected={'EDA0077':(600,660),'EDA0093':(900,960),'EDA0112':(600,660)}[code];a,b=expected;kind='explicitExamAppointment'
                clock=plan['fields']['시험일시'];assert f'2026.{md.replace("-", ".")}' in clock;assert f'{a//60:02d}:{a%60:02d}' in clock and f'{b//60:02d}:{b%60:02d}' in clock
            if code=='EDA0108' and md=='09-16':b=870;kind='explicitEndOverride';assert '~14:30' in str(plan['weekly'])
            m=dict(date=date.isoformat(),weekday=date.isoweekday(),startMinute=a,endMinute=b,classroom=place,deliveryMode='inPerson');meetings.append(m);cases.append(dict(code=code,section=section,kind=kind,meeting=m))
        if code=='GEA7537':
            for day in [23,24,25]:
                date=dt.date(2026,10,day)
                for start in [540,720,900]:
                    m=dict(date=date.isoformat(),weekday=date.isoweekday(),startMinute=start,endMinute=start+180,classroom='',deliveryMode='inPerson');meetings.append(m);cases.append(dict(code=code,section=section,kind='explicitFieldClockUnpublishedLocation',meeting=m))
        assert len({(m['date'],m['startMinute'],m['endMinute']) for m in meetings})==len(meetings)
        note=notes[code]+'\n'+common
    else:
        note='일반·집중·원격 수업의 개별 날짜·시각 운영을 아직 확인 중입니다. 공개 원문 정보는 검색에 보존하며 임의로 전체 학기 반복을 생성하지 않았습니다.\n'+common
    remarks='\n'.join(f'{label}: {r[key]}' for label,key in [('수강 가능 학년·학과','eligibleYearDepartment'),('개설 소속','openingDepartment'),('학점/이론·실습','theoryPractice'),('학점교류','exchangePermission'),('강의진행','lectureType'),('수업운영','deliveryMode'),('시험 안내','examNotes')] if r[key])+'\n'+note
    rows.append(dict(sourceId=f'changwon/unknown/2026/2/{code}-{section}',universityId='changwon',campus='unknown',academicYear=2026,semester='2',courseCode=code,section=section,courseName=education.get('currentPublicPlan',{}).get('fields',{}).get('교과목명',r['title']),professor=r['professor'],credits=float(r['credits']),departmentCredits={dept:float(r['credits'])},classification=r['classification'],departments=[dept],departmentClassifications={dept:r['classification']},departmentRemarks={dept:remarks},sourceSchedule=r['schedule'],sourceClassroom='',scheduleStatus='scheduled' if meetings else ('unscheduled' if not r['schedule'] else 'unrecognized'),schedules=meetings,period=dict(startDate='2026-09-01',endDate='2026-12-20'),sourceEducation=education,remarks=remarks))
dataset=dict(schemaVersion=2,universityId='changwon',campus='unknown',campusName='캠퍼스 미확인',academicYear=2026,semester='2',publishedDate='2026-10-08',publishedDateMeaning='Current anonymous public retrieval date',sourceUrl='https://chains.changwon.ac.kr/cnu/haksa/open_subject/open_index_manager.php',researchOnly=True,productionRegistered=False,completionClaim=False,courses=rows)
p=ROOT/'changwon-unknown-2026-2.five-dated-v1.json';p.write_text(json.dumps(dataset,ensure_ascii=False,indent=2)+'\n')
audit=dict(nativeRows=len(rows),scheduled=sum(bool(r['schedules']) for r in rows),datedMeetings=len(cases),heldOrUntimed=sum(not r['schedules'] for r in rows),cases=cases,reviewedPlanHashes=files,candidateSHA256=hashlib.sha256(p.read_bytes()).hexdigest(),completionClaim=False,wholeOperatingReviewComplete=False,permanentlyImpossible=False,periodBoundary='day before published winter break, not a printed last teaching date')
(ROOT/'changwon-five-dated-v1-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in audit.items() if k not in ['cases','reviewedPlanHashes']})
