#!/usr/bin/env python3
"""Read TUK's official general/fusion PDF snapshots without guessing periods.

The published July snapshot is not proof of all current active undergraduate
courses. Output explicitly records outstanding scope/latest-time checks; the
caller must not activate university support from this snapshot alone.
"""
import argparse
import json
from pathlib import Path
import re

DAYS = '월화수목금토일'
CLOCK = re.compile(r'([월화수목금토일])\[([^]]+)\](\d{2}):(\d{2})~(\d{2}):(\d{2})')
HEADER = ['학년', '이수구분(구이수구분)', '교과목명', '학수번호', '분반',
          '학점(설계)', '시수', '교수명', '강의시간', '수강인원/정원',
          '부전공', '복수전공', '융합전공운영학과', '평가구분', '수업진행구분CE,PBL']


def compact(value):
    return re.sub(r'\s+', '', value or '')


def meetings(schedule):
    value = compact(schedule)
    if not value:
        return []
    groups = list(CLOCK.finditer(value))
    room_text = CLOCK.sub('', value)
    if not groups or not re.fullmatch(r'\([^()]*\)', room_text):
        raise ValueError('Unrecognized TUK clock/room syntax')
    rooms = room_text[1:-1].split(',')
    if len(rooms) not in (1, len(groups)) or not all(rooms):
        raise ValueError('Ambiguous TUK classroom mapping')
    slots = []
    for index, group in enumerate(groups):
        sh, sm, eh, em = map(int, group.groups()[2:])
        start, end = sh*60+sm, eh*60+em
        if min(sh, eh) < 0 or max(sh, eh) > 23 or max(sm, em) > 59 or start >= end:
            raise ValueError('Invalid TUK clock range')
        slots.append({'weekday': DAYS.index(group[1])+1, 'startMinute': start,
                      'endMinute': end, 'classroom': rooms[0] if len(rooms) == 1 else rooms[index]})
    if len({(s['weekday'],s['startMinute'],s['endMinute']) for s in slots}) != len(slots):
        raise ValueError('Duplicate TUK meeting')
    return slots


def parse_documents(documents, closures, year, semester):
    if any(len(r) != 8 or not re.fullmatch(r'[A-Z]{3}[A-Z0-9]{5,6}', r[1]) or not re.fullmatch(r'\d{2}', r[2]) for r in closures):
        raise ValueError('Invalid TUK closure identity')
    closed = {(r[1], r[2]) for r in closures}
    if not closures or len(closed) != len(closures):
        raise ValueError('Empty or duplicate TUK closure list')
    courses, count, removed = {}, 0, set()
    for document in documents:
        tables, departments = document['tables'], document['departments']
        if [t['page'] for t in tables] != list(range(1, len(tables)+1)) or any(t['table'] != 0 for t in tables):
            raise ValueError('Incomplete TUK document pages')
        for table in tables:
            department = departments[str(table['page'])]
            if not department or [compact(v) for v in table['rows'][0]] != HEADER:
                raise ValueError('Invalid TUK department/header')
            grade = ''
            for row in table['rows'][1:]:
                count += 1
                if len(row) != 15:
                    raise ValueError('Invalid TUK row width')
                grade = compact(row[0]) or grade
                code, section = compact(row[3]), compact(row[4])
                if not re.fullmatch(r'[A-Z]{3}[A-Z0-9]{5,6}', code) or not re.fullmatch(r'\d{2}', section) or not row[2]:
                    raise ValueError('Invalid TUK course identity')
                if (code, section) in closed:
                    removed.add((code, section)); continue
                credit_match = re.fullmatch(r'(\d+(?:\.\d+)?)\((\d+(?:\.\d+)?)\)', compact(row[5]))
                if not credit_match:
                    raise ValueError('Invalid TUK credit/design-credit notation')
                credits = float(credit_match[1])
                parsed = meetings(row[8])
                # Published field research/practice and service placeholder clocks
                # do not establish actual attendance dates. Retain source evidence
                # and block weekly scheduling until separately published dates exist.
                unresolved = compact(row[2]).startswith(('ER(', '현장실습')) or compact(row[2]) == '사회봉사'
                slots = [] if unresolved else parsed
                status = 'unrecognized' if unresolved else 'scheduled' if slots else 'unscheduled'
                remark_fields = [(grade, '학년'), (row[5], '학점(설계)'), (row[6], '시수'),
                                 (row[1], '공식 이수구분(구이수구분)'), (row[10], '부전공'),
                                 (row[11], '복수전공'), (row[12], '융합전공 운영학과'),
                                 (row[13], '평가구분'), (row[14], '수업진행구분')]
                remark = '\n'.join(f'{label}: {v}' for v,label in remark_fields if v)
                if compact(row[2]).startswith('EH'):
                    remark += '\nEH: 소속학과 수강 원칙, 타학과 후순위·담당교수 승인 필요(공식 수강안내)'
                if unresolved:
                    remark += '\n실제 현장연구/사회봉사 수업 기간·일자는 별도 확인 필요'
                key = (code, section)
                candidate = {'sourceId':f'tuk/main/{year}/{semester}/{code}/{section}',
                             'universityId':'tuk','campus':'main','academicYear':year,'semester':semester,
                             'courseCode':code,'section':section,'courseName':re.sub(r'\s*\n\s*', '', row[2]).strip(),
                             'professor':compact(row[7]),'credits':credits,'sourceSchedule':row[8] or '',
                             'sourceClassroom':', '.join(dict.fromkeys(s['classroom'] for s in parsed)),
                             'scheduleStatus':status,'schedules':slots,'departments':[],
                             'departmentCredits':{},'departmentClassifications':{},'departmentRemarks':{}}
                course = courses.setdefault(key, candidate)
                for field in ('courseName','professor','credits','schedules','scheduleStatus'):
                    if (compact(course[field]) != compact(candidate[field]) if field == 'courseName' else course[field] != candidate[field]):
                        raise ValueError(f'Conflicting cross-listed TUK {field}: {key}')
                classification = compact(row[1]).split('(',1)[0]
                if department in course['departments']:
                    if course['departmentClassifications'][department] != classification:
                        raise ValueError('Conflicting department-specific TUK classification')
                    # A shared class can appear in multiple year curricula of
                    # one department. Preserve each published row's conditions.
                    if remark not in course['departmentRemarks'][department].split('\n추가 공개행:\n'):
                        course['departmentRemarks'][department] += '\n추가 공개행:\n' + remark
                else:
                    course['departments'].append(department)
                    course['departmentCredits'][department] = credits
                    course['departmentClassifications'][department] = classification
                    course['departmentRemarks'][department] = remark
    return list(courses.values()), {'sourceRows':count,'excludedClosedKeys':sorted(removed),
                                   'closureKeysNotInSnapshot':sorted(closed-removed)}


def extract_document(path, year, semester):
    import pdfplumber
    tables, departments = [], {}
    with pdfplumber.open(path) as document:
        for number, page in enumerate(document.pages, 1):
            heading = page.crop((0,0,page.width,110)).extract_text() or ''
            match = re.match(r'(.+?)\s*\(수강년도:\s*(\d+)\s*학\s*기:\s*(\d+)\)', heading,re.S)
            extracted = page.extract_tables()
            if not match or (int(match[2]),match[3]) != (year,semester) or len(extracted) != 1:
                raise ValueError('Wrong TUK year/term or ambiguous PDF table')
            departments[str(number)] = compact(match[1])
            tables.append({'page':number,'table':0,'rows':extracted[0]})
    return {'tables':tables,'departments':departments}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--general', type=Path, required=True)
    parser.add_argument('--fusion', type=Path, required=True)
    parser.add_argument('--closures', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--year', type=int, required=True)
    parser.add_argument('--semester', choices=['1','2'], required=True)
    parser.add_argument('--expected-source-rows', type=int, required=True)
    parser.add_argument('--published-date', required=True)
    parser.add_argument('--source-url', required=True)
    args = parser.parse_args()
    documents = [extract_document(p,args.year,args.semester) for p in (args.general,args.fusion)]
    courses,audit = parse_documents(documents,json.loads(args.closures.read_text()),args.year,args.semester)
    if audit['sourceRows'] != args.expected_source_rows:
        raise ValueError('Incomplete TUK source row coverage')
    result = {'schemaVersion':1,'universityId':'tuk','campus':'main','academicYear':args.year,
              'semester':args.semester,'publishedDate':args.published_date,'sourceUrl':args.source_url,
              'sourceDocuments':[args.general.name,args.fusion.name],
              'closureDocument':args.closures.name,
              'completionClaim':False,'remainingVerification':['latest time/room changes after snapshot',
              'company talent college separately operated curricula', 'actual field/service teaching dates',
              'first/second campus course location mapping'], 'audit':audit,'courses':courses}
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(len(courses), audit)
