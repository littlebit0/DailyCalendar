#!/usr/bin/env python3
"""Convert verified public educational rows; does not activate school support."""
import argparse
import datetime
import json
from pathlib import Path
import re

DAY_LABELS = '월화수목금토일'
DAYS = {'MONDAY':1,'TUESDAY':2,'WEDNESDAY':3,'THURSDAY':4,'FRIDAY':5,'SATURDAY':6,'SUNDAY':7}


def meetings_for(row):
    slots = []
    for item in row['schedule']['lectureTimes']:
        weekday = DAYS[item['dayOfWeek']]
        for endpoint in ('start', 'end'):
            clock = item[endpoint]
            if not (isinstance(clock['hour'], int) and isinstance(clock['minute'], int)
                    and 0 <= clock['hour'] <= 23 and 0 <= clock['minute'] <= 59):
                raise ValueError('Invalid published clock components')
        start = item['start']['hour'] * 60 + item['start']['minute']
        end = item['end']['hour'] * 60 + item['end']['minute']
        if not (0 <= start < end <= 1440) or item['minutes'] != end-start:
            raise ValueError('Invalid published clock')
        slots.append((weekday, start, end, item.get('classRoomName') or ''))
    merged = []
    for day,start,end,room in sorted(set(slots)):
        if merged and merged[-1]['weekday']==day:
            previous = merged[-1]
            if start < previous['endMinute']:
                raise ValueError('Overlapping published rooms or clocks')
            if start == previous['endMinute'] and room == previous['classroom']:
                previous['endMinute'] = end
                continue
        merged.append({'weekday':day,'startMinute':start,'endMinute':end,'classroom':room})
    return merged


def dated_meetings_for(row, proof, weekly_source=None):
    if (proof['courseKey'] != row['id'] or proof['subjectId'] != row['subjectId']
            or proof['section'] != row['classSequence']
            or proof['title'] != row['subjectNm']):
        raise ValueError('Dated plan and offering identity disagree')
    source_dates = set()
    if weekly_source is not None:
        if (weekly_source['current2026-2Header'] is not True
                or weekly_source['subjectId'] != row['subjectId']
                or weekly_source['section'] != row['classSequence']
                or weekly_source['title'] != row['subjectNm']):
            raise ValueError('Wrong directly published weekly plan identity')
        source_dates = {(item['week'], date) for item in weekly_source['weeklyRows']
                        for date in item['dates']}
    anchors = proof.get('anchorEvidence')
    start = datetime.date(2026, 9, 1)
    if anchors is not None:
        start = datetime.date.fromisoformat(anchors['semesterStart'])
        week8 = datetime.date.fromisoformat(anchors['week8'][0])
        week15 = datetime.date.fromisoformat(anchors['week15'][0])
        if week8 != start + datetime.timedelta(weeks=7) or week15 != start + datetime.timedelta(weeks=14):
            raise ValueError('Dated plan official week anchors disagree')
    elif not source_dates:
        raise ValueError('Missing directly printed dates or official week evidence')
    actual = {
        (DAYS[item['dayOfWeek']],
         item['start']['hour'] * 60 + item['start']['minute'],
         item['end']['hour'] * 60 + item['end']['minute'],
         item.get('classRoomName') or '')
        for item in row['schedule']['lectureTimes']
    }
    actual.update((m['weekday'], m['startMinute'], m['endMinute'], m['classroom'])
                  for m in meetings_for(row))
    slots = []
    seen = set()
    for item in proof['dateMeetings']:
        date = datetime.date.fromisoformat(item['date'])
        week = (date - start).days // 7 + 1
        identity = (item['weekday'], item['startMinute'], item['endMinute'], item['room'])
        verified_online_clock = (
            item.get('deliveryMode') == 'liveOnline' and item['room'] == ''
            and ((week == 14 and '실시간' in proof.get('week14DeliveryEvidence', ''))
                 or (source_dates and re.search(r'zoom|줌|화상',
                     ' '.join(item.get('sourcePhrases', [])), re.IGNORECASE)))
            and (*identity[:3], item.get('catalogRoom')) in actual)
        if (date.isoformat() != item['date'] or date.weekday() + 1 != item['weekday']
                or not 1 <= week <= proof.get('semesterWeeksConsidered', 15)
                or week != item['officialWeek'] or week in proof.get('noClassWeeks', [])
                or week in proof.get('noTimedMeetingWeeks', [])
                or (source_dates and (week, item['date']) not in source_dates)
                or (identity not in actual and not verified_online_clock)):
            raise ValueError('Dated session lacks actual clock or official week proof')
        mode = item.get('deliveryMode')
        # The research helper's default onsite label is not explicit source
        # evidence. Preserve the user's mode unless a published mode is given.
        if mode == 'onsite':
            mode = None
        if mode not in (None, 'inPerson', 'liveOnline'):
            raise ValueError('Unverified dated attendance mode')
        key = (item['date'], *identity)
        if key in seen:
            raise ValueError('Duplicate dated session')
        seen.add(key)
        slot = {'date': item['date'], 'weekday': item['weekday'],
                'startMinute': item['startMinute'], 'endMinute': item['endMinute'],
                'classroom': item['room']}
        if mode is not None:
            slot['deliveryMode'] = mode
        slots.append(slot)
    merged = []
    for slot in sorted(slots, key=lambda m: (m['date'], m['startMinute'])):
        previous = merged[-1] if merged else None
        if previous and previous['date'] == slot['date']:
            if slot['startMinute'] < previous['endMinute']:
                raise ValueError('Overlapping dated sessions')
            if (slot['startMinute'] == previous['endMinute']
                    and slot['classroom'] == previous['classroom']
                    and slot.get('deliveryMode') == previous.get('deliveryMode')):
                previous['endMinute'] = slot['endMinute']
                continue
        merged.append(slot)
    if not merged:
        raise ValueError('Empty dated attendance proof')
    return merged


def convert(rows, dictionary, short_periods, verified_department_names=None,
            dated_proofs=None, weekly_sources=None):
    departments = {r['deptCd']:r['deptNm'] for r in dictionary['departmentList']}
    verified_by_course = {}
    for proof in verified_department_names or []:
        if not proof['name'] or not proof['sourceEvidence'] or not proof['courseKeys']:
            raise ValueError('Incomplete actual department evidence')
        for key in proof['courseKeys']:
            identity = (proof['departmentCode'], key)
            if identity in verified_by_course:
                raise ValueError('Duplicate actual department evidence')
            verified_by_course[identity] = proof['name']
    categories = {r['cmmnCdVal']:r['cdValNm'] for r in dictionary['commonCdList'] if r['cmmnCd']=='SCUR0100'}
    short = {r['code']:r for r in short_periods}
    dated = {r['courseKey']: r for r in dated_proofs or []}
    if len(dated) != len(dated_proofs or []):
        raise ValueError('Duplicate dated offering proof')
    weekly = {(r['subjectId'], r['section']): r for r in weekly_sources or []}
    if len(weekly) != len(weekly_sources or []):
        raise ValueError('Duplicate directly published weekly source')
    result = []
    ids = set()
    unresolved = []
    for row in rows:
        if row['standardDeptCode'] != '20000' or row['closed']:
            continue
        if row['year'] != '2026' and row['year'] != 2026:
            raise ValueError('Wrong published year')
        if row['semesterCode'] != '20':raise ValueError('Wrong published semester')
        code = row['subjectId']
        section = row['classSequence']
        if not isinstance(code,str) or not isinstance(section,str) or not code or not section:
            raise ValueError('Missing published identity')
        key=f'{code}-{section}'
        if key in ids:raise ValueError('Duplicate course section')
        ids.add(key)
        department_code=row['assignedDepartmentCode']
        # A code is preserved as a code when the published dictionary has no name.
        department=departments.get(department_code,
            verified_by_course.get((department_code, row['id']), department_code))
        category=categories[row['categoryCode']]
        original_meetings=meetings_for(row)
        notes=[row['remark'] or '']
        proof = dated.get(row['id'])
        unverified_dated = proof is not None and (
            proof.get('unresolvedWeeks') or proof.get('allAttendanceWeeksVerified') is False)
        blocked=(key in short and short[key].get('conflict')) or (row['type'] in {'FieldTraining','SocialService'} and original_meetings) or unverified_dated
        if blocked:
            unresolved.append(key)
            notes.append('실제 적용 수업일·기간 확인 필요: 진행 방식도 확인 전에는 공개 시각을 학기 전체에 반복하지 않음')
            if proof and proof.get('unresolvedReason'):
                notes.append(proof['unresolvedReason'])
        if department == department_code:notes.append(f'공식 학과 코드: {department_code} (학과명 미게시)')
        source_schedule='\n'.join(f"{DAY_LABELS[m['weekday']-1]}요일 {m['startMinute']//60:02}:{m['startMinute']%60:02}~{m['endMinute']//60:02}:{m['endMinute']%60:02}" for m in original_meetings)
        course={'sourceId':f'kookmin/main/2026/2/{code}/{section}','universityId':'kookmin','campus':'main',
            'academicYear':2026,'semester':'2','courseCode':code,'section':section,'courseName':row['subjectNm'],
            'professor':row['professorName'] or '', 'credits':row['credits']['credit'],
            'sourceSchedule':source_schedule,'sourceClassroom':'\n'.join(dict.fromkeys(m['classroom'] for m in original_meetings if m['classroom'])),
            'scheduleStatus':'unrecognized' if blocked else 'scheduled' if original_meetings else 'unscheduled',
            'schedules':[] if blocked else original_meetings,'departments':[department],
            'departmentCredits':{department:row['credits']['credit']},'departmentClassifications':{department:category},
            'departmentRemarks':{department:'\n'.join(n for n in notes if n)}}
        if key in short and short[key].get('verifiedEnd'):
            end=datetime.date.fromisoformat(short[key]['verifiedEnd'])
            if not datetime.date(2026,9,1)<=end<=datetime.date(2026,12,31):raise ValueError('Invalid actual short period')
            course['period']={'startDate':'2026-09-01','endDate':end.isoformat()}
        if proof is not None and not unverified_dated:
            if blocked:
                raise ValueError('Contradictory unresolved and dated offering')
            course['schedules'] = dated_meetings_for(
                row, proof, weekly.get((code, section)))
            course['scheduleStatus'] = 'scheduled'
            course['departmentRemarks'][department] += (
                '\n공식 주차 범위와 강의계획서의 수업 없는 주를 대조한 날짜별 수업')
        result.append(course)
    return result, unresolved


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--research-root',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();root=args.research_root
    rows=json.loads((root/'kookmin-current-college-scope.json').read_text())['records']+json.loads((root/'kookmin-current-unmapped-department-courses.json').read_text())['records']
    courses, unresolved=convert(rows,json.loads((root/'kookmin-commoncodes.json').read_text()),json.loads((root/'kookmin-concentrated-periods.json').read_text()),
        json.loads((root/'kookmin-verified-department-names.json').read_text()),
        json.loads((root/'kookmin-special-dated-meeting-candidates.json').read_text())
        + json.loads((root/'kookmin-general-operating-meeting-candidates.json').read_text()),
        json.loads((root/'kookmin-current-weekly-operating-rows.json').read_text()))
    result={'schemaVersion':2,'researchOnly':True,'productionReady':False,'completionClaim':False,
      'universityId':'kookmin','campus':'main','academicYear':2026,'semester':'2','publishedDate':'2026-10-07',
      'sourceUrl':'https://sugang.kookmin.ac.kr/front/enrollment/course-catalog','courses':courses,
      'unresolvedActualPeriod':unresolved,'remaining':['campus/building scope','special and concentrated operation','actual department40053name','source short period and semester corroboration']}
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('Current undergraduate courses',len(courses),'unresolved actual periods',len(unresolved))
