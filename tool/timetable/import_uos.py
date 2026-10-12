#!/usr/bin/env python3
"""Import UOS's public undergraduate XLS/XLSX attachment.

Source is the official CA2 course notice, not private WISE/enrollment login.
The attachment does not publish professors or times for every course; preserve
empty fields rather than inventing them. Public day slots 1..10 are hourly from
09:00. UOS notices independently show slot11 at19:00 and slot12 at20:00.
Observed slots13..15 remain unverified; their whole courses are retained with
no meetings until an official mapping is confirmed. Do not use the separate
45-minute night numbering.
Retain every source schedule. The complete attachment is not enabled in Daily.
"""
import argparse
from datetime import date
import json
from pathlib import Path
import re

DAYS = '월화수목금토일'


def meetings(text):
    if not text.strip():
        return [], 'unscheduled'
    result = []
    # Commas also occur inside classroom numbers; only a following weekday
    # starts another meeting (e.g. /11-501,2,금[1,2]/39-B127).
    parts = re.split(r',(?=[월화수목금토일]\[)', text)
    for part in parts:
        match = re.fullmatch(r'([월화수목금토일])\[([0-9,]+)\]/(.+)', part.strip())
        if not match:
            raise ValueError('Unrecognized UOS course schedule')
        slots = [int(v) for v in match[2].split(',')]
        if len(slots) != len(set(slots)) or any(not 1 <= v <= 12 for v in slots):
            raise ValueError('Unverified UOS period')
        weekday = DAYS.index(match[1]) + 1
        for slot in sorted(slots):
            start = 540 + (slot - 1)*60
            prior = result[-1] if result else None
            if prior and prior['weekday'] == weekday and prior['classroom'] == match[3] and prior['endMinute'] + 10 == start:
                prior['endMinute'] = start + 50
            else:
                result.append({'weekday': weekday, 'startMinute': start,
                    'endMinute': start + 50, 'classroom': match[3]})
    if any(a['weekday'] == b['weekday'] and a['startMinute'] < b['endMinute']
           and b['startMinute'] < a['endMinute']
           for index, a in enumerate(result) for b in result[index + 1:]):
        raise ValueError('Ambiguous simultaneous UOS source rooms')
    return result, 'scheduled'


def parse_rows(rows, year, semester):
    if not rows or rows[0][4:7] != ['교과번호', '분반', '교과목명']:
        raise ValueError('Unexpected UOS sheet header')
    courses = []
    identities = set()
    for row in rows[1:]:
        if len(row) != 22 or not isinstance(row[0], (int, float)):
            raise ValueError('Unexpected UOS row')
        department, classification, area = row[1:4]
        code, section, title = row[4:7]
        if not isinstance(code, str) or not re.fullmatch(r'\d{5}', code) or not isinstance(section, str) or not re.fullmatch(r'\d{2}', section) or not all(isinstance(v,str) and v.strip() for v in [title,department,classification]):
            raise ValueError('Invalid UOS course identity')
        credits = row[8]
        if not isinstance(credits,(int,float)) or not 0 <= credits <= 30:
            raise ValueError('Invalid UOS credits')
        if row[9] not in ['주간', '계약']:
            raise ValueError('Unverified UOS night-period encoding')
        period = None
        if row[12] != '(~)':
            match = re.fullmatch(r'A형 \d+주차\((\d{8})~(\d{8})\)', row[12] or '')
            if not match:
                raise ValueError('Unrecognized UOS concentrated period')
            dates = [date(int(v[:4]), int(v[4:6]), int(v[6:])) for v in match.groups()]
            if dates[0] > dates[1] or any(v.year != year for v in dates):
                raise ValueError('Invalid UOS concentrated period')
            period = {'startDate': dates[0].isoformat(), 'endDate': dates[1].isoformat()}
        identity = f'uos/main/{year}/{semester}/{code}/{section}'
        if identity in identities:
            raise ValueError('Duplicate UOS course')
        identities.add(identity)
        source_schedule = row[11] or ''
        if not isinstance(source_schedule, str):
            raise ValueError('Invalid UOS source schedule')
        clock_error = None
        try:
            parsed, status = meetings(source_schedule)
        except ValueError as error:
            # Retain the whole course and raw source, but never invent late
            # periods or partially add an unparsed source schedule.
            parsed, status, clock_error = [], 'unrecognized', str(error)
        if period:
            # The current actual-operation notice uses different attendance
            # dates. Keep administrative bounds as metadata, never as proof
            # that the registration grid repeats throughout this interval.
            parsed, status = [], 'unrecognized'
        remarks = []
        if area: remarks.append('세부영역: '+area)
        if row[7]: remarks.append('대상학년: '+', '.join(str(int(row[7]))))
        if row[9] == '계약': remarks.append('계약학과')
        if row[10]: remarks.append(row[10])
        if period:
            remarks.append('집중수업 등록기간: '+row[12])
            remarks.append('실제 출석일·수업시각 별도 확인 필요: 시간표 추가 불가')
        if clock_error: remarks.append('학교 원본 수업시간의 시각 미확인: 시간표 추가 불가')
        if status == 'unscheduled': remarks.append('학교 원본에 수업시간·강의실이 미입력되어 있습니다.')
        for label,value in zip(['타학과 수강','복수전공','부전공','융복합 과목','학점교류'],row[17:22]):
            if value in ['', None]: continue
            if value not in ['Y','N']: raise ValueError('Unexpected UOS eligibility flag')
            remarks.append(label+': '+('가능' if value=='Y' else '불가'))
        courses.append({'sourceId':identity,'universityId':'uos','campus':'main',
            'academicYear':year,'semester':semester,'courseCode':code,'section':section,
            'courseName':title,'professor':'','credits':credits,'sourceSchedule':source_schedule,
            'sourceClassroom':' / '.join(dict.fromkeys(r['classroom'] for r in parsed)),
            'scheduleStatus':status,'schedules':parsed,'departments':[department],
            'departmentCredits':{department:credits},
            'departmentClassifications':{department:classification},
            'departmentRemarks':{department:'\n'.join(remarks)},
            **({'sourceAdministrativePeriod': period} if period else {})})
    if not courses: raise ValueError('Empty UOS course catalog')
    return courses


def apply_operating_proof(courses, proof):
    """Apply exact current educational proof, never a title-based guess."""
    records = proof['records']
    if proof['term'] != '2026-2' or proof['recordCount'] != 33 or len(records) != 33:
        raise ValueError('Incomplete UOS operating proof')
    by_key = {c['courseCode']+'-'+c['section']: c for c in courses}
    seen = set()
    descriptions = {
        'explicitAsynchronousMetadataOnly': '비대면 온라인 비실시간 수업. 원본 시간표 슬롯을 정기 수업으로 추가하지 않음.',
        'externalOnlineCreditRecognitionMetadataOnly': '외부 온라인 강좌 이수·이수증 제출에 따른 특별학점 인정. 원본 슬롯은 실제 정기 수업 시각으로 적용하지 않음.',
        'priorSummerCompletionCreditRecognitionMetadataOnly': '여름방학 사전 이수 후 2학기 학점 취득. 가을 정기 수업으로 반복하지 않음.',
        'unrecognizedRequiredIndividualAssignment': '기본교육 날짜 선택·소양교육 필수 참석·그룹코칭 개별 배정. 전체 실제 출석 일정 미확인: 시간표 추가 불가.',
        'unrecognizedCurrentOperationAndClock': '실제 운영일·시각 미확인: 시간표 추가 불가.',
    }
    for record in records:
        key = record['courseKey']
        if key in seen or key not in by_key or record['decision'] not in descriptions:
            raise ValueError('Unexpected UOS operating identity or decision')
        seen.add(key)
        course = by_key[key]
        if (record['title'], record['credits'], record['category'], record['originalSchedule']) != (
                course['courseName'], course['credits'], next(iter(course['departmentClassifications'].values())), course['sourceSchedule']):
            raise ValueError('UOS operating proof does not match current source')
        course['schedules'] = []
        course['scheduleStatus'] = 'unrecognized' if record['decision'].startswith('unrecognized') else 'unscheduled'
        for department in course['departmentRemarks']:
            if course['scheduleStatus'] == 'unscheduled':
                course['departmentRemarks'][department] = course['departmentRemarks'][department].replace(
                    '학교 원본 수업시간의 시각 미확인: 시간표 추가 불가', '').strip()
            course['departmentRemarks'][department] += '\n' + descriptions[record['decision']]
            course['departmentRemarks'][department] += '\n공식 운영 안내: ' + record['source']
    return courses


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--year',type=int,required=True)
    parser.add_argument('--semester',choices=['1','2','여름','겨울'],required=True)
    parser.add_argument('--source-url',required=True)
    parser.add_argument('--published-date',required=True)
    parser.add_argument('--operating-proof', type=Path)
    args = parser.parse_args()
    if args.input.read_bytes()[:2] == b'PK':
        import openpyxl
        book = openpyxl.load_workbook(args.input, read_only=True, data_only=True)
        rows = [list(row) for row in book.worksheets[0].iter_rows(values_only=True)
                if any(value is not None for value in row)]
        book.close()
    else:
        import xlrd
        book = xlrd.open_workbook(args.input)
        sheet = book.sheet_by_index(0)
        rows = [sheet.row_values(i) for i in range(sheet.nrows)]
    courses = parse_rows(rows,args.year,args.semester)
    if args.operating_proof:
        courses = apply_operating_proof(courses, json.loads(args.operating_proof.read_text()))
    dataset = {'schemaVersion':1,'universityId':'uos','campus':'main',
        'academicYear':args.year,'semester':args.semester,'publishedDate':args.published_date,
        'sourceUrl':args.source_url,'courses':courses}
    args.output.write_text(json.dumps(dataset,ensure_ascii=False,indent=2)+'\n')
    print(f'{len(courses)} unique courses; {sum(c["scheduleStatus"]=="scheduled" for c in courses)} scheduled')

if __name__ == '__main__':
    main()
