#!/usr/bin/env python3
"""Import complete public INHA department/other filter results.

Half-hour period boundaries are published by the same course search menu.
Keep asynchronous web lectures visible without inventing a weekly meeting.
"""
import argparse
import json
from pathlib import Path
import re

DAYS = '월화수목금토일'


def meetings(text, encoded, time_options):
    clock = {}
    for code, label in time_options:
        match = re.fullmatch(r'D([1-6])T([1-9A-O])', code)
        display = re.fullmatch(r'([월화수목금토])(\d+)\((\d{2}):(\d{2})\)', label)
        if match and display:
            day, slot = int(match[1]), int(display[2])
            minute = int(display[3])*60+int(display[4])
            if DAYS[day-1] != display[1] or not 1 <= slot <= 24 or minute != 540+(slot-1)*30:
                raise ValueError('Unexpected INHA public period table')
            clock[(day,slot)] = minute
    if len(clock) != 144:
        raise ValueError('Incomplete INHA six-day period table')
    published = set()
    groups = re.findall(r'D([0-7])((?:T\d+)+)', encoded)
    truncated = len(encoded) == 50
    if ''.join('D'+d+t for d,t in groups) != encoded and not truncated:
        raise ValueError('Unrecognized INHA encoded schedule')
    for day, periods in groups:
        for slot in re.findall(r'T(\d+)',periods):
            if day != '0': published.add((int(day),int(slot)))
    parsed = set()
    slots = []
    for part in text.split('/'):
        part = part.strip()
        boundary = part.find('(')
        times = part[:boundary] if boundary >= 0 else part
        room = part[boundary+1:] if boundary >= 0 else ''
        if room.endswith(')'): room = room[:-1]
        chunks = re.findall(r'([월화수목금토일셀])([0-9,]+)',times)
        if ''.join(day+periods for day,periods in chunks) != times:
            raise ValueError('Unrecognized INHA displayed schedule')
        for day, periods in chunks:
            if day == '셀': continue
            weekday = DAYS.index(day)+1
            for value in periods.rstrip(',').split(','):
                slot = int(value)
                # The public menu enumerates 1..24 with a continuous 30-minute
                # cadence. Two published laboratory rows extend to 28/32.
                # Extend that verified cadence only through the observed 32;
                # never clamp an overnight class to the last visible option.
                if not 1 <= weekday <= 6 or not 1 <= slot <= 32:
                    raise ValueError('Unverified INHA period')
                parsed.add((weekday,slot))
                start = 540+(slot-1)*30
                actual_day = weekday if start < 1440 else weekday+1
                slots.append((actual_day,start % 1440,room))
    reconstructed = ''.join('D'+str(day)+''.join('T'+str(slot) for d,slot in sorted(parsed) if d==day)
                            for day in sorted({d for d,_ in parsed}))
    # TIME_DATA is clipped at 50 characters in long clinical/design rows.
    # Use the complete visible schedule only when its exact prefix agrees.
    if parsed != published and not (truncated and reconstructed.startswith(encoded)):
        raise ValueError('INHA displayed and encoded times disagree')
    result = []
    for day, start, room in sorted(set(slots)):
        previous = result[-1] if result else None
        if previous and previous['weekday']==day and previous['classroom']==room and previous['endMinute']==start:
            previous['endMinute']=start+30
        else:
            result.append({'weekday':day,'startMinute':start,'endMinute':start+30,'classroom':room})
    return result


def parse_responses(responses, year, semester):
    courses = {}
    for response in responses:
        if response['term'] != f'{year} 학년도 {semester}학기':
            raise ValueError('Wrong INHA published term')
        department = response['label'].strip()
        if not department: raise ValueError('Missing INHA filter label')
        for row in response['rows']:
            if len(row)!=14: raise ValueError('Unexpected INHA row shape')
            identity = re.fullmatch(r'([A-Za-z0-9]+)-(\d+)',row[0])
            if identity is None or not row[2].strip():
                raise ValueError('Invalid INHA course identity')
            credits = float(row[4])
            if not 0 <= credits <= 30: raise ValueError('Invalid INHA credits')
            scheduled = meetings(row[6],row[12],response['timeOptions'])
            code, section = identity.groups()
            source_id = f'inha/main/{year}/{semester}/{code}/{section}'
            current = {'sourceId':source_id,'universityId':'inha','campus':'main',
                'academicYear':year,'semester':semester,'courseCode':code,
                'section':section,'courseName':row[2],'professor':row[7],
                'credits':credits,'sourceSchedule':row[6],
                'sourceClassroom':' / '.join(dict.fromkeys(m['classroom'] for m in scheduled if m['classroom'])),
                'scheduleStatus':'scheduled' if scheduled else 'unscheduled',
                'schedules':scheduled,'departments':[department],
                'departmentCredits':{department:credits},
                'departmentClassifications':{department:row[5]},
                'departmentRemarks':{department:row[9]}}
            previous = courses.get(source_id)
            if previous is None:
                courses[source_id]=current
            else:
                for field in ['courseName','professor','credits','sourceSchedule','schedules']:
                    if current[field] != previous[field]:
                        raise ValueError(f'Conflicting INHA course {source_id}: {field}')
                if department not in previous['departments']:
                    previous['departments'].append(department)
                for field in ['departmentCredits','departmentClassifications','departmentRemarks']:
                    previous[field].update(current[field])
    if not courses: raise ValueError('Empty INHA catalog')
    return list(courses.values())


def load_complete(directory):
    manifest=json.loads((directory/'manifest.json').read_text())
    if manifest.get('complete') is not True: raise ValueError('Incomplete INHA collection')
    queries=manifest['queries']
    if len({(q['kind'],q['code']) for q in queries})!=len(queries):
        raise ValueError('Duplicate INHA filters')
    responses=[]
    for query in queries:
        if query['kind'] not in ['department','other'] or not re.fullmatch(r'\d+',query['code']):
            raise ValueError('Invalid INHA filter identity')
        response=json.loads((directory/(query['kind']+'-'+query['code']+'.json')).read_text())
        if any(response[k]!=query[k] for k in ['kind','code','label']):
            raise ValueError('Wrong INHA query result')
        responses.append(response)
    if not any(q['kind']=='department' for q in queries) or not any(q['kind']=='other' for q in queries):
        raise ValueError('Missing INHA course scope')
    return manifest, parse_responses(responses,manifest['year'],manifest['semester'])


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--raw',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--checked-at',required=True)
    args=parser.parse_args()
    manifest,courses=load_complete(args.raw)
    args.output.write_text(json.dumps({'schemaVersion':1,'universityId':'inha',
        'campus':'main','academicYear':manifest['year'],'semester':manifest['semester'],
        'publishedDate':args.checked_at,'sourceUrl':manifest['sourceUrl'],
        'courses':courses},ensure_ascii=False,indent=2)+'\n')
    print('INHA courses',len(courses),'scheduled',sum(bool(c['schedules']) for c in courses))
