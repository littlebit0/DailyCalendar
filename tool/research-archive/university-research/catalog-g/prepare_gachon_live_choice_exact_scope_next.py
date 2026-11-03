"""Two actual current live plans: explicit no-class weeks and explicit holiday class."""
import collections, copy, datetime as dt, hashlib, json
from pathlib import Path
from prepare_gachon_dated_regular_candidate import HOLIDAYS, NOTE
from validate_gachon_individual_weekly_period import current_period_weekly_rows_consistent
ROOT=Path(__file__).resolve().parent
def read(name):
    return json.loads((ROOT/name).read_text())
def main():
    reports={r['sourceRow']['HAKSU_NO']:r for r in read('gachon-full-operating-report-audit.json')['reports']}
    bases={c['officialOfferingCode']:c for c in read('gachon-full-normalized-source-candidates.json')['courses']}
    audit={'completionClaim':False,'productionRegistered':False,'currentFullCollectionComplete':True,'currentFullOperatingApprovalComplete':False,'excludedNationalHolidays':sorted(HOLIDAYS),'datasets':[],'promoted':[],'productionProjectionPermitted':'validated2873PublishedPlansOnly','previousManifest':'gachon-published-regular-2870-school-plan-next-sha-manifest-20261008.json','reviewPolicy':'15290012 actualstudentphysical/Zoomchoice retains usermode and literalvirtualroom;11396001 no-class weeks8/15 omitted;05271001 explicit September24 same-time live class overrides general holiday closure only for this exact source course/date.'}
    for campus in ['global','medical']:
        original=read(f'gachon-{campus}-2026-2.published-regular-2870-school-plan-next-20261008.json')
        data=copy.deepcopy(original)
        for c in data['courses']:
            code=c['courseCode']+c['section']
            if code not in {'11396001','05271001','15290012'}:continue
            assert c['scheduleStatus']=='unrecognized'
            r,b=reports[code],bases[code]
            assert all(r['report'][k] for k in ['headerCourseCodeMatches','currentTermMatches','catalogProfessorAppearsInReport'])
            assert current_period_weekly_rows_consistent(r,b)
            assert b['deliveryMode']=='liveOnline' and '실시간화상강의' in r['sourceRow']['SUBJECT_NM_KOR']
            assert not any(w['operatingContextLimitReached'] or w['operatingContextTruncationDetected'] for w in r['weeklyRows'])
            blocks=copy.deepcopy(b['schedules'])
            omitted=[w for w in r['weeklyRows'] if code=='11396001' and w['week'] in [8,15]]
            if code=='11396001':
                assert len(b['publishedActualSlots'])==1 and not blocks
                slot=b['publishedActualSlots'][0]
                assert (slot['weekday'],slot['period'],slot['startMinute'],slot['endMinute'])==(2,10,1080,1130)
                blocks=[{'weekday':2,'startMinute':1080,'endMinute':1130,'classroom':b['rawRoom'],'deliveryMode':'liveOnline'}]
                assert all(any('수업없음' in s for s in w['operatingContexts']) for w in omitted)
            elif code=='05271001':
                assert any('9/24 동일한 시간 진행' in s for w in r['weeklyRows'] if w['week']==4 for s in w['operatingContexts'])
                assert [(x['weekday'],x['startMinute'],x['endMinute']) for x in blocks]==[(4,660,770)]
            else:
                assert '직접 수강' in r['teachingMethodEducationalExcerpt'] and '501호' in r['teachingMethodEducationalExcerpt'] and 'Zoom 실시간' in r['teachingMethodEducationalExcerpt']
                for block in blocks: block.pop('deliveryMode',None)
                c.pop('deliveryMode',None)
            ranges=[tuple(dt.date(2026,*map(int,w[k].split('/'))) for k in ['startMonthDay','endMonthDay']) for w in omitted]
            meetings=[]
            start,end=(dt.date.fromisoformat(c['period'][k]) for k in ['startDate','endDate'])
            for block in blocks:
                day=start
                while day<=end:
                    special=code=='05271001' and day.isoformat()=='2026-09-24'
                    if day.isoweekday()==block['weekday'] and (day.isoformat() not in HOLIDAYS or special) and not any(a<=day<=z for a,z in ranges):
                        meetings.append({k:v for k,v in {**block,'date':day.isoformat()}.items() if k not in ['firstPeriod','lastPeriod']})
                    day+=dt.timedelta(days=1)
            prior=copy.deepcopy(c['departmentRemarks'])
            auto='수업 운영 미확인: 공개 수업 계획의 날짜·시간·수업 방식을 확인 중입니다.'
            remarks={d:'\n'.join([*(s for s in text.split('\n') if s!=auto),NOTE]) for d,text in prior.items()}
            extra='8주차(2026-10-20~2026-10-26)·15주차(2026-12-08~2026-12-14)는 수업 없음·과제 제출로 명시되어 자동 수업 일정에서 제외했습니다.' if code=='11396001' else '2026-09-24는 휴일이지만 현재 4주차 계획에 동일한 시간 진행이 명시되어 목요일11:00~12:50 실시간 강의 계획을 보존했습니다. 별도 시험 시각은 생성하지 않았습니다.'
            if code=='15290012': extra='학교 제목은 실시간화상강의이며 현재 계획은 학생이 반도체대학501호 대면 수강 또는Zoom 실시간 수강을 선택할 수 있도록 명시합니다. 수업추가 시 실제 이용할 방식을 선택하세요. 원 시간표의 가상 강의실 표기는 그대로 보존했습니다.'
            remarks={d:text+'\n'+extra for d,text in remarks.items()}
            c.update(scheduleStatus='scheduled',schedules=meetings,unresolvedReasons=[],departmentRemarks=remarks,sourceDepartmentRemarks=prior,sourceEducation={'projection':'publishedRegularTimetable','actualAttendanceConfirmed':False,'sourceDeliveryMode':'hybridStudentChoiceUnknownDefault' if code=='15290012' else 'liveOnlineFromOfficialTitleAndCurrentPlan','sourceCampusExplicit':'20','holidayProof':'gachon-current-undergraduate-holiday-rule-20261008.json:Article13','calendarProof':'gachon-current-fall-calendar-boundary-proof-20261008.json','omittedUnresolvedAssessmentWeeks':omitted,'explicitHolidayClassDate':'2026-09-24' if code=='05271001' else None})
            audit['promoted'].append({'sourceId':c['sourceId'],'offering':code,'campus':campus,'period':c['period'],'datedMeetingCount':len(meetings),'originalClockBlocks':blocks,'omittedUnresolvedAssessmentWeeks':omitted,'holidayOverrideContext':[s for w in r['weeklyRows'] if w['week']==4 for s in w['operatingContexts']] if code=='05271001' else []})
        data['currentFullOperatingAuditFinished']=False
        name=f'gachon-{campus}-2026-2.published-regular-2873-live-choice-exact-scope-next-20261008.json'
        out=ROOT/name;assert not out.exists();out.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
        audit['datasets'].append({'file':name,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'campus':campus,'courseCount':len(data['courses']),'counts':dict(collections.Counter(c['scheduleStatus'] for c in data['courses'])),'datedMeetingCount':sum(len(c['schedules']) for c in data['courses'])})
    assert len(audit['promoted'])==3
    audit['scheduledCount']=sum(d['counts']['scheduled'] for d in audit['datasets']);assert audit['scheduledCount']==2873
    audit['datedMeetingCount']=sum(d['datedMeetingCount'] for d in audit['datasets'])
    for kind,value in [('audit',audit),('sha-manifest',{k:v for k,v in audit.items() if k!='promoted'})]:
        out=ROOT/f'gachon-published-regular-2873-live-choice-exact-scope-next-{kind}-20261008.json';assert not out.exists();out.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in audit.items() if k!='promoted'}))
if __name__=='__main__':main()
