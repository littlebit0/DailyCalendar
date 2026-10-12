#!/usr/bin/env python3
"""Import audited Yongin course rows, preserving real clocks and unresolved dates.

Inputs retain original PDF table rows and all split-row meetings; never infer a
weekly attendance schedule for an intensive or mixed-mode course.
"""
import argparse
import json
from pathlib import Path
import re

DAYS='월화수목금토일'
CLOCK=re.compile(r'([월화수목금토일])(\d{2}):(\d{2})[-~](\d{2}):(\d{2})')


def text(value):
    return '' if value is None else str(value).strip()


def parse_clock(raw,room):
    value=re.sub(r'\s+','',raw)
    groups=list(CLOCK.finditer(value))
    if not groups or CLOCK.sub('',value):raise ValueError('Unrecognized Yongin actual clock')
    result=[]
    for m in groups:
        sh,sm,eh,em=map(int,m.groups()[1:]);start,end=sh*60+sm,eh*60+em
        if max(sh,eh)>23 or max(sm,em)>59 or start>=end:raise ValueError('Invalid Yongin actual clock')
        result.append({'weekday':DAYS.index(m[1])+1,'startMinute':start,'endMinute':end,'classroom':text(room).replace('\n','')})
    return result


def parse_records(payload,closures,year,semester,expected_core):
    if (payload.get('academicYear'),payload.get('semester')) != (year,semester):
        raise ValueError('Wrong Yongin publication year/term')
    records=payload['records']
    if len(records)!=expected_core or len({r['codeSection'] for r in records})!=len(records):
        raise ValueError('Incomplete or duplicate Yongin core scope')
    closed=set()
    for row in closures:
        if not re.fullmatch(r'\d{6}[A-Z]\d{2}',row['rawCode']):raise ValueError('Invalid Yongin closure code')
        closed.add((row['courseCode'],row['section']))
    if not closed or len(closed)!=len(closures):raise ValueError('Empty/duplicate Yongin closure scope')
    courses=[];removed=set();unresolved=[]
    for row in records:
        code,section=row['codeSection'].split('-')
        if not re.fullmatch(r'[A-Z0-9]{6}',code) or not re.fullmatch(r'\d{2}',section):raise ValueError('Invalid Yongin identity')
        if (code,section) in closed:removed.add((code,section));continue
        credits=re.fullmatch(r'(\d+)\((\d*)\)',row['creditsCapacity'])
        if not credits or not row['name'] or not row['classification'] or not row['department']:raise ValueError('Invalid Yongin academic row')
        slots=[s for meeting in row['meetings'] for s in parse_clock(meeting['rawTime'],meeting['rawRoom'])]
        note=re.sub(r'\n[\d·]+\s+(?:교필|교선|전공|기전|교직)[^\n]*\Z','',row['notes']).strip()
        blocked=bool(re.search(r'집중수업|수업일정은|추후 결정|9~15주차',note))
        if blocked:unresolved.append(row['codeSection'])
        course={'sourceId':f'yongin/main/{year}/{semester}/{code}/{section}','universityId':'yongin','campus':'main',
                'academicYear':year,'semester':semester,'courseCode':code,'section':section,
                'courseName':row['name'].replace('\n',''),'professor':', '.join(row['professors']),
                'credits':int(credits[1]),'sourceSchedule':'\n'.join(m['rawTime'] for m in row['meetings']),
                'sourceClassroom':'\n'.join(dict.fromkeys(m['rawRoom'] or '' for m in row['meetings'])),
                'scheduleStatus':'unrecognized' if blocked else 'scheduled' if slots else 'unscheduled',
                'schedules':[] if blocked else slots,'departments':[row['department']],
                'departmentCredits':{row['department']:int(credits[1])},
                'departmentClassifications':{row['department']:row['classification']},
                'departmentRemarks':{row['department']:'\n'.join(v for v in [note,'수강대상: '+row['target'] if row['target'] else '',
                 '학년: '+text(row['grade']) if row['grade'] else '',
                 '실제 수업일자 미공개: 별도 확인 필요' if blocked else ''] if v)}}
        courses.append(course)
    remote=payload['remote']
    if len(remote)!=22 or len({r['rawCode'] for r in remote})!=22:raise ValueError('Incomplete Yongin OCU/KCU scope')
    for row in remote:
        if not re.fullmatch(r'[WK]\d{5}[A-Z]\d{2}',row['rawCode']):raise ValueError('Invalid Yongin consortium code')
        raw=row['rawCode'];code,section=raw[:6],raw[-2:];department=row['department']
        # Actual official table has no weekly attendance clock. Online exams
        # require separately published schedules; no asynchronous-mode guess.
        courses.append({'sourceId':f'yongin/main/{year}/{semester}/{code}/{section}','universityId':'yongin','campus':'main',
            'academicYear':year,'semester':semester,'courseCode':code,'section':section,'courseName':row['name'],
            'professor':row['professor'],'credits':row['credits'],'sourceSchedule':'','sourceClassroom':'',
            'scheduleStatus':'unscheduled','schedules':[],'departments':[department],
            'departmentCredits':{department:row['credits']},'departmentClassifications':{department:row['classification']},
            'departmentRemarks':{department:f'공식 학수번호: {raw}\n'+row['notes']+'\n공개 표에 정기 수업시각 없음. 시험 일시는 별도 공지 확인 필요'}})
    if len({c['sourceId'] for c in courses})!=len(courses):raise ValueError('Duplicate final Yongin identity')
    return courses,{'coreRows':len(records),'consortiumRows':len(remote),'closedKeysExcluded':sorted(removed),
                    'closedKeysAbsentFromSnapshot':sorted(closed-removed),'unresolvedActualDateCourses':unresolved}


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--records',type=Path,required=True)
    parser.add_argument('--closures',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--year',type=int,required=True)
    parser.add_argument('--semester',choices=['1','2'],required=True)
    parser.add_argument('--expected-core',type=int,required=True)
    parser.add_argument('--published-date',required=True)
    parser.add_argument('--source-url',required=True)
    args=parser.parse_args()
    courses,audit=parse_records(json.loads(args.records.read_text()),json.loads(args.closures.read_text()),args.year,args.semester,args.expected_core)
    result={'schemaVersion':1,'universityId':'yongin','campus':'main','academicYear':args.year,'semester':args.semester,
            'publishedDate':args.published_date,'sourceUrl':args.source_url,'completionClaim':False,'audit':audit,
            'remainingVerification':['unpublished intensive and mixed-mode actual teaching dates','campus building mapping','all current notice changes reflected'], 'courses':courses}
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(len(courses),audit)
