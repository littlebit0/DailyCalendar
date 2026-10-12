#!/usr/bin/env python3
"""Prepare the official July2026 HKNU workbook with unverified changes separated.

Academic identities include the published opening department because HKNU reuses
code-section pairs for distinct departmental classes. No name-only update is
applied and no attendance time is invented for counseling or field practice.
"""
import argparse
import json
from pathlib import Path
import re
from urllib.parse import quote

DAYS = '월화수목금토일'
RANGE = re.compile(r'\(([월화수목금토일])\)\s*(\d+(?:\.5)?)~(\d+(?:\.5)?)')
NIGHT = {10:(1080,1125),11:(1125,1170),12:(1175,1220),
         13:(1220,1265),14:(1270,1315),15:(1315,1360)}
COUNSELING = '인성교육및상담24'
FIELD = re.compile(r'현장실습|산업의료원|동계스포츠|보육실습|사전실습|개인상담실습')


def text(value):
    return '' if value is None else str(value).strip()


def clocks(raw, room):
    """Return only source-verified slots; reject a whole unresolved course range.

    Day .5 is an inclusive30min slot, documented by the official2024 guide and
    corroborated by explicit2026 civil course hours. Current integer night times
    come from both campus workbooks. Only exact13–15.5 night range has additional
    explicit official clock evidence; other night fractions are unresolved.
    """
    parts = text(raw).split(' / ')
    meetings = []
    for part in parts:
        match = RANGE.fullmatch(part)
        if match is None:
            return [], '시간표 표기 해석 미확정'
        day, first, last = match.groups()
        first, last = float(first), float(last)
        if first > last:
            raise ValueError('Reversed HKNU period')
        if 1 <= first <= last <= 9.5:
            start = 540 + int((first - 1) * 60)
            end = 540 + int((last - 1) * 60) + 30
        elif first == 13 and last == 15.5:
            start, end = 1220, 1360
        elif first.is_integer() and last.is_integer() and 10 <= first <= last <= 15:
            start, end = NIGHT[int(first)][0], NIGHT[int(last)][1]
        else:
            return [], '야간 소수 교시 또는 주야간 교차 시각 미확정'
        if start >= end:
            raise ValueError('Invalid HKNU attendance clock')
        meetings.append({'weekday':DAYS.index(day)+1, 'startMinute':start,
                         'endMinute':end, 'classroom':room})
    return meetings, ''


def parse_records(payload, expected_counts=None):
    if payload.get('academicYear') != 2026 or payload.get('semester') != '2':
        raise ValueError('Unexpected HKNU year/semester')
    expected_counts = expected_counts or {'anseong':1210,'pyeongtaek':277}
    courses, audit = [], {'sourceRowsByCampus':{}, 'unresolvedClock':[],
        'counseling':[], 'unresolvedPracticeDates':[]}
    identities = set()
    for campus, rows in payload['campuses'].items():
        if campus not in expected_counts or len(rows) != expected_counts[campus]:
            raise ValueError('Incomplete HKNU campus coverage')
        audit['sourceRowsByCampus'][campus] = len(rows)
        for row in rows:
            code, section = text(row['과목코드']), text(row['분반'])
            department = text(row['개설전공']) or text(row['개설학부'])
            name, classification = text(row['과목명']), text(row['이수구분'])
            if not re.fullmatch(r'\d{10}',code) or not re.fullmatch(r'[A-Z]\d{2}',section):
                raise ValueError('Invalid actual HKNU code/section')
            if not department or not name or not classification:
                raise ValueError('Missing HKNU academic identity')
            source_id = f'hknu/{campus}/2026/2/{code}/{section}/{quote(department,safe="")}'
            if source_id in identities:
                raise ValueError('Duplicate HKNU department identity')
            identities.add(source_id)
            credits = row['학점']
            if not isinstance(credits,(int,float)) or isinstance(credits,bool) or not 0 <= credits <= 30:
                raise ValueError('Invalid HKNU credits')
            theory, practice = text(row['이론강의실']), text(row['실습강의실'])
            room = ' / '.join(dict.fromkeys(v for v in (theory,practice) if v))
            if any(v in room for v in ('(평캠)', '(안캠)')):
                if ('(안캠)' if campus == 'pyeongtaek' else '(평캠)') in room:
                    raise ValueError('Opposite-campus room in official campus sheet')
            raw = text(row['시간표'])
            slots, reason = clocks(raw,room)
            status = 'unrecognized' if reason else 'scheduled'
            if name == COUNSELING:
                slots, status = [], 'unscheduled'
                reason = '상담 실제 일정은 담당교수와 협의: 원문 교시는 반복 일정으로 적용하지 않음'
                audit['counseling'].append(source_id)
            elif FIELD.search(name):
                slots, status = [], 'unrecognized'
                reason = '현장·집중 실습의 실제 시행기간 미확정: 원문 교시를 학기 전체로 반복하지 않음'
                audit['unresolvedPracticeDates'].append(source_id)
            elif reason:
                audit['unresolvedClock'].append({'sourceId':source_id,'rawSchedule':raw})
            note = '\n'.join(v for v in [reason,
                '학년: '+text(row['학년']), '학습구분: '+text(row['주/야']),
                '공식 개설학부: '+text(row['개설학부']),
                '교육과정코드: '+text(row.get('교육과정코드')) if row.get('교육과정코드') else '',
                '영역: '+text(row['영역']) if row['영역'] else '',
                '교직여부: '+text(row.get('교직여부')) if row.get('교직여부') else '',
                '장애지원: '+text(row.get('장애지원여부')) if row.get('장애지원여부') else '',
                '영어수업: '+text(row.get('영어수업여부')) if row.get('영어수업여부') else '',
                '최대수강학점 제외여부: '+text(row.get('최대수강학점제외여부')),
                '이론/실습/설계 시수: '+ '/'.join(text(row[k]) for k in ('이론','실습','설계')),
                '트랙: '+text(row.get('트랙명'))+' '+text(row.get('트랙이수구분'))
                    if row.get('트랙명') or row.get('트랙이수구분') else '',
                '복수전공 트랙: '+text(row.get('복수전공트랙명'))+' '+text(row.get('복수전공트랙이수구분'))
                    if row.get('복수전공트랙명') or row.get('복수전공트랙이수구분') else ''
                ] if v)
            courses.append({'sourceId':source_id,'universityId':'hknu','campus':campus,
                'academicYear':2026,'semester':'2','courseCode':code,'section':section,
                'courseName':name,'professor':text(row['교수명']),'credits':credits,
                'sourceSchedule':raw,'sourceClassroom':room,'scheduleStatus':status,
                'schedules':slots,'departments':[department],
                'departmentCredits':{department:credits},
                'departmentClassifications':{department:classification},
                'departmentRemarks':{department:note}})
    if set(payload['campuses']) != set(expected_counts):
        raise ValueError('Missing HKNU campus')
    audit['countsByStatus'] = {s:sum(c['scheduleStatus']==s for c in courses)
                               for s in ('scheduled','unscheduled','unrecognized')}
    return courses,audit


def extract_workbook(path, campus):
    from openpyxl import load_workbook
    workbook = load_workbook(path,data_only=True)
    sheet = workbook.worksheets[0]
    source = list(sheet.values)
    label = '안성' if campus == 'anseong' else '평택'
    if text(source[0][0]) != f'2026-2학기 {label}캠퍼스 시간표 (2026.7.14.자)':
        raise ValueError('Unexpected HKNU workbook publication')
    expected_clock = {p:(540+(p-1)*60,590+(p-1)*60) for p in range(1,10)}
    expected_clock.update(NIGHT)
    printed_clock = {}
    for row in workbook['교시별 수업시간'].values:
        if isinstance(row[1],int):
            raw = text(row[2]).replace('：',':')
            match = re.fullmatch(r'(\d{2}):(\d{2})\s*-\s*(\d{2}):(\d{2})',raw)
            if match is None or row[1] in printed_clock:
                raise ValueError('Invalid HKNU printed clock table')
            sh,sm,eh,em = map(int,match.groups())
            printed_clock[row[1]] = (sh*60+sm,eh*60+em)
    if printed_clock != expected_clock:
        raise ValueError('Changed HKNU official clock: review source before importing')
    headers = [re.sub(r'\s+','',text(value)) for value in source[2]]
    if len(set(headers)) != len(headers) or '과목코드' not in headers:
        raise ValueError('Invalid HKNU workbook header')
    rows = [dict(zip(headers,row)) for row in source[3:]]
    if source[1][1] != len(rows) or [int(row['No']) for row in rows] != list(range(1,len(rows)+1)):
        raise ValueError('Incomplete HKNU published sequence')
    return rows


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--anseong',type=Path,required=True)
    parser.add_argument('--pyeongtaek',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    payload = {'academicYear':2026,'semester':'2','campuses':{
        'anseong':extract_workbook(args.anseong,'anseong'),
        'pyeongtaek':extract_workbook(args.pyeongtaek,'pyeongtaek')}}
    courses,audit = parse_records(payload)
    result = {'schemaVersion':1,'universityId':'hknu','academicYear':2026,'semester':'2',
        'publishedDate':'2026-07-14','sourceUrl':'https://www.hknu.ac.kr/bbs/hkhuman/620/97264/artclView.do',
        'completionClaim':False,'productionReady':False,'audit':audit,
        'generalTeachingPeriod':{'start':'2026-09-01','endInclusive':'2026-12-21',
            'sourceUrl':'https://www.hknu.ac.kr/kor/464/subview.do',
            'scope':'General semester only, not counseling or field/intensive actual dates'},
        'remainingVerification':['Current340 general course changes lack exact course codes',
            'Final34 closure list lacks exact course codes','All university changes since July14',
            'Night fractional periods and individual practice dates'], 'courses':courses}
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(len(courses),audit['countsByStatus'])
