#!/usr/bin/env python3
"""Normalize official Sangmyung timetable PDFs. Requires pdfplumber.

Usage: python import_sangmyung.py --campus seoul --year 2026 --semester 2
  --pdf SOURCE.pdf --source-url URL --published-date YYYY-MM-DD --output OUTPUT.json
Fails on unfamiliar rows, period notation or conflicting cross-listed sections.
Lecture modes are deliberately absent: users choose them when adding a course.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

DAYS = '월화수목금토일'
SCHEDULE = re.compile(r'([월화수목금토일])([0-9A-I]+(?:,[0-9A-I]+)*)\(([^()]*)\)')
CLASSIFICATIONS = {'1전선', '1전심', '1교직', '교선', '교필', '일선', '1MD'}
TABLE_HEADER = ('No', '학년', '이수구분', '학수번호', '교과목명', '학점',
                '이론시간', '실습시간', '교양영역', '강의시간(강의실)', '분반',
                '담당교수', '비고')


def classification(raw):
    """Preserve the source curriculum classification, never infer from a title."""
    value = re.sub(r'\s+', '', raw)
    if value not in CLASSIFICATIONS:
        raise ValueError(f'Unknown curriculum classification: {raw}')
    return value

def meeting_times(raw):
    raw = re.sub(r'\s+', '', raw)
    if not raw or SCHEDULE.sub('', raw):
        raise ValueError(f'Unknown schedule notation: {raw}')
    meetings = []
    for match in SCHEDULE.finditer(raw):
        day, periods, room = match.groups()
        previous = None
        for period in periods.split(','):
            if period.isdecimal() and 0 <= int(period) <= 15:
                start = 480 + int(period) * 60
                end = start + 50
            elif len(period) == 1 and period in 'ABCDEFGHI':
                start = 480 + 'ABCDEFGHI'.index(period) * 90
                end = start + 75
            else:
                raise ValueError(f'Unknown period: {period}')
            if previous and previous['endMinute'] + 10 == start:
                previous['endMinute'] = end
            else:
                previous = {'weekday': DAYS.index(day)+1, 'startMinute': start,
                            'endMinute': end, 'classroom': room}
                meetings.append(previous)
    return sorted(meetings, key=lambda m: (m['weekday'],m['startMinute'],m['endMinute'],m['classroom']))

def extract(pdf, campus, year, semester, source_url, published_date):
    import pdfplumber
    courses = {}
    rows = 0
    with pdfplumber.open(pdf) as document:
        for page_number, page in enumerate(document.pages, 1):
            lines = page.extract_text().splitlines()
            if not lines or f'{year}학년도' not in lines[0] or f'{semester}학기' not in lines[0]:
                raise ValueError(f'Unexpected page heading: {page_number}')
            department = lines[1].strip()
            tables = page.extract_tables()
            if len(tables) != 1:
                raise ValueError(f'Expected one table on page {page_number}')
            header = tuple(re.sub(r'\s+', '', value or '') for value in tables[0][0])
            if header != TABLE_HEADER:
                raise ValueError(f'Unexpected table columns on page {page_number}: {header}')
            for row in tables[0][1:]:
                if len(row) != 13 or not row[0] or not row[0].isdigit():
                    raise ValueError(f'Unexpected row on page {page_number}: {row}')
                rows += 1
                code, name, credits, schedule, section, professor = [row[i] for i in (3,4,5,9,10,11)]
                curriculum = classification(row[2])
                # This is the official final "비고" column. Keep its internal
                # whitespace/newlines, including course eligibility restrictions.
                remarks = row[12] or ''
                if not re.fullmatch(r'[A-Z]{4}[0-9]{4}', code) or not section.isdecimal():
                    raise ValueError(f'Invalid course identity on page {page_number}')
                source_id = f'smu/{campus}/{year}/{semester}/{code}/{int(section)}'
                course = {'sourceId':source_id, 'universityId':'smu', 'campus':campus,
                          'academicYear':year, 'semester':semester, 'courseCode':code,
                          'courseName':name.replace('\n',''), 'section':str(int(section)),
                          'professor':professor.replace('\n',''), 'credits':float(credits),
                          'schedules':meeting_times(schedule)}
                if source_id in courses:
                    previous = courses[source_id]
                    if {k:v for k,v in previous.items() if k not in ('departments','sourcePages','departmentCredits','departmentClassifications','departmentRemarks','credits')} != {k:v for k,v in course.items() if k != 'credits'}:
                        raise ValueError(f'Conflicting cross-listed section: {source_id}')
                    if (department in previous['departmentClassifications'] and
                            previous['departmentClassifications'][department] != curriculum):
                        raise ValueError(f'Conflicting department classification: {source_id}')
                    previous['departmentClassifications'][department] = curriculum
                    if (department in previous['departmentRemarks'] and
                            previous['departmentRemarks'][department] != remarks):
                        raise ValueError(f'Conflicting department remarks: {source_id}')
                    previous['departmentRemarks'][department] = remarks
                    previous['departmentCredits'][department] = course['credits']
                    if previous['credits'] != course['credits']: previous['credits'] = None
                    if department not in previous['departments']: previous['departments'].append(department)
                    previous['sourcePages'].append(page_number)
                else:
                    course.update(departments=[department],sourcePages=[page_number],departmentCredits={department:course['credits']},departmentClassifications={department:curriculum},departmentRemarks={department:remarks})
                    courses[source_id] = course
    return {'schemaVersion':1,'universityId':'smu','campus':campus,'academicYear':year,
            'semester':semester,'sourceUrl':source_url,'publishedDate':published_date,
            'sourceSha256':hashlib.sha256(Path(pdf).read_bytes()).hexdigest(),
            'sourceRowCount':rows,'courses':list(courses.values())}

if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--campus',choices=['seoul','cheonan'],required=True)
    p.add_argument('--year',type=int,required=True)
    for name in ['semester','pdf','source-url','published-date','output']: p.add_argument('--'+name,required=True)
    a=p.parse_args();result=extract(a.pdf,a.campus,a.year,a.semester,a.source_url,a.published_date)
    Path(a.output).write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n')
    print(a.campus,'rows',result['sourceRowCount'],'unique sections',len(result['courses']))
