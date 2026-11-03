"""Research-only normalization; preserve unverified operations as blocked rows."""
from collections import Counter
import argparse
from datetime import date
import json
from pathlib import Path
import re
ROOT = Path(__file__).parent
DAYS = '월화수목금토일'
CAMPUS = {'chuncheon':'춘천','samcheok':'삼척','dogye':'도계','gangneung':'강릉','wonju':'원주'}
CLOCK_A = {i:(540+(i-1)*90,615+(i-1)*90) for i in range(1,7)}
SERVICE_AUDIT = json.loads((ROOT / 'kangwon-gw-service-whole-institution-clock-audit.json').read_text())
if SERVICE_AUDIT['courseCount'] != 135 or SERVICE_AUDIT['verifiedCount'] != 135:
    raise ValueError('Incomplete service institution clock audit')
SERVICE = {
    row['section']: (row['weekday'], row['startMinute'], row['endMinute'])
    for row in SERVICE_AUDIT['programRows'] if row['verified']
}
SERVICE_NOTES = {row['section']: row['sourceProgramText'] for row in SERVICE_AUDIT['programRows']}
SERVICE_INSTITUTIONS = {row['section']: ' / '.join(row['institutionNameHeaders'])
                        for row in SERVICE_AUDIT['programRows']}


def parse_groups(source, embedded, room, allow_zero=False):
    result=[];cursor=0
    while cursor<len(source):
        rest=source[cursor:]
        separator=re.match(r'[\s,]*',rest);cursor+=separator.end()
        if cursor==len(source):break
        match=re.match(r'([월화수목금토일])\s*,?\s*((?:A?\d{1,2})(?:\s*,\s*A?\d{1,2})*)',source[cursor:])
        if not match:raise ValueError('unparsed_source_clock')
        day=match[1];periods=re.sub(r'\s+','',match[2]).split(',');cursor+=match.end()
        classroom=room
        if embedded and cursor<len(source) and source[cursor]=='(':
            start=cursor+1;depth=1;cursor+=1
            while cursor<len(source) and depth:
                if source[cursor]=='(':depth+=1
                if source[cursor]==')':depth-=1
                cursor+=1
            if depth:raise ValueError('unbalanced_source_classroom')
            classroom=source[start:cursor-1]
        slots=[]
        for period in periods:
            if period.startswith('A'):
                number=int(period[1:])
                if number not in CLOCK_A:raise ValueError('unverified_source_period')
                start,end=CLOCK_A[number]
                kind='A'
            else:
                number=int(period)
                if not (1<=number<=14 or number==0 and allow_zero):raise ValueError('unverified_source_period')
                start,end=480+number*60,530+number*60
                kind='ordinary'
            slots.append((start,end,kind,number))
        # One published group can include its scheduled recess. Never bridge
        # nonadjacent periods or merge different source classroom groups.
        slots.sort();chunks=[]
        for start,end,kind,number in slots:
            if chunks and chunks[-1][2]==kind and number==chunks[-1][3]+1:
                chunks[-1]=(chunks[-1][0],end,kind,number)
            else:chunks.append((start,end,kind,number))
        result += [{'weekday':DAYS.index(day)+1,'startMinute':s,'endMinute':e,'classroom':classroom or ''} for s,e,_,_ in chunks]
    return result


def normalize(rows):
    active=[r for r in rows if not r['closed']]
    if len(rows)!=5915 or len(active)!=5761:raise ValueError('Incomplete current whole undergraduate scope')
    keys=[(r['campus'],r['code'],r['section']) for r in rows]
    if len(set(keys))!=5915:raise ValueError('Duplicate source identity')
    courses=[];problems=[]
    for row in active:
        campus=row['campus'];department=row['department'] or row['sourceCollege'] or '개설소속 미게시'
        if campus not in CAMPUS:raise ValueError('Unknown published campus')
        reasons=[];schedules=[];source=row['sourceSchedule']
        try:schedules=parse_groups(source,row['classroomEmbedded'],row.get('classroom',''),campus in {'gangneung','wonju'})
        except ValueError as error:reasons.append(str(error))
        if not source:reasons.append('source_time_unpublished')
        if row['remote']:reasons.append('remote_grid_exam_slots_actual_delivery_unverified')
        if '집중' in row['remarks']:reasons.append('concentrated_actual_dates_unpublished')
        if '현장실습' in row['remarks']+' '+row['name']:reasons.append('individual_field_placement_dates_unpublished')
        if re.search(r'임상실습|사회봉사|교육봉사',row['name']):reasons.append('clinical_or_service_actual_operation_requires_plan')
        period=None
        if row['code']=='14207025':
            if row['section'] in SERVICE:
                day,start,end=SERVICE[row['section']]
                # The catalog classroom is an academic administration/lecture
                # room; it does not establish the field activity's location.
                schedules=[{'weekday':day,'startMinute':start,'endMinute':end,'classroom':''}]
                reasons=[];period={'startDate':'2026-09-14','endDate':'2026-12-04'}
            else:reasons.append('service_program_individual_clock_pending')
        if reasons:schedules=[];problems.append({'campus':campus,'code':row['code'],'section':row['section'],'reasons':reasons})
        remarks='\n'.join(x for x in [row['remarks'], '수강대상: '+row['target'] if row['target'] else '',
                                  '실제 수업시간·운영기간 미확인: 시간표 추가 불가' if reasons else '',
                                  '기관 실습 일정만 확인됨. 오리엔테이션·특강·평가회 예정일은 자동 추가하지 않음' if period else '',
                                  SERVICE_NOTES.get(row['section'], '') if row['code']=='14207025' else ''] if x)
        if period:
            remarks += '\n봉사기관: ' + SERVICE_INSTITUTIONS[row['section']]
            remarks += '\n원본 교내 강의실은 기관 활동 장소로 적용하지 않음. 활동 장소는 기관 안내 확인.'
        course={'sourceId':f"kangwon/{campus}/2026/2/{row['code']}/{row['section']}",
                'universityId':'kangwon','campus':campus,'academicYear':2026,'semester':'2',
                'courseCode':row['code'],'section':row['section'],'courseName':row['name'],
                'professor':row['professor'],'credits':row['credits'],'sourceSchedule':source,
                'sourceClassroom':row.get('classroom','') if not row['classroomEmbedded'] else source,
                'scheduleStatus':'unrecognized' if reasons else 'scheduled','schedules':schedules,
                'departments':[department],'departmentCredits':{department:row['credits']},
                'departmentClassifications':{department:row['classification']},'departmentRemarks':{department:remarks}}
        if period:course['period']=period
        courses.append(course)
    return courses,problems


if __name__=='__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--asset-dir', type=Path)
    args = parser.parse_args()
    rows=json.loads((ROOT/'kangwon-current-whole-source-rows.json').read_text())
    courses,problems=normalize(rows)
    for campus,name in CAMPUS.items():
        payload={'schemaVersion':2,'universityId':'kangwon','campus':campus,'campusName':name,
                 'academicYear':2026,'semester':'2','publishedDate':'2026-10-07',
                 'sourceUrl':'https://www.kangwon.ac.kr/ko/bbs/720/list.do','completionClaim':False,
                 'period':{'startDate':'2026-09-01','endDate':'2026-12-21'},
                 'courses':[c for c in courses if c['campus']==campus]}
        (ROOT/f'kangwon-{campus}-2026-2.candidate.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n')
        if args.asset_dir:
            args.asset_dir.mkdir(parents=True, exist_ok=True)
            payload['sourceCollectedDate'] = '2026-10-07'
            (args.asset_dir/f'kangwon-{campus}-2026-2.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n')
    audit={'courseCount':len(courses),'scheduleStatusCounts':dict(Counter(c['scheduleStatus'] for c in courses)),
           'individualUnresolved':problems,'completionClaim':False,'productionModified':False}
    (ROOT/'kangwon-normalized-candidate-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
    print(audit['courseCount'],audit['scheduleStatusCounts'])
