"""Whole official KSNU package conversion; no production registration.

Keep late closure/currency, circled/late clock and intensive dates explicit.
"""
import datetime as dt
import json
import re
from collections import Counter,defaultdict
from pathlib import Path
ROOT=Path(__file__).parent
DAYS='월화수목금토일'


def parse_numeric_clock(raw):
    if re.search('[①-⑳]',raw):raise ValueError('원문 원문자 교시(① 등)의 실제 시각 미확인')
    result=[];cursor=0
    for match in re.finditer(r'([^\[\]]+)\[([^\[\]]+)\]',raw):
        if raw[cursor:match.start()].strip():raise ValueError('원문 강의실 구성 미확인')
        components=match[1].strip()
        if cursor and components.startswith(','):
            components=components[1:].strip()
        for part in components.split(','):
            m=re.fullmatch(r'([월화수목금토일])\s*(\d+(?:\s+\d+)*)',part.strip())
            if not m:raise ValueError('원문 요일·교시 구성 미확인')
            values=[int(v) for v in m[2].split()]
            if len(set(values))!=len(values) or any(v<1 or v>10 for v in values):raise ValueError('공식 현재 교시 시각표는 1~10교시만 제시')
            groups=[]
            for value in sorted(values):
                if groups and value==groups[-1][-1]+1:groups[-1].append(value)
                else:groups.append([value])
            for group in groups:
                original=490+group[0]*60
                result.append({'weekday':DAYS.index(m[1])+1,'startMinute':(original//30)*30,'originalStartMinute':original,'endMinute':540+group[-1]*60,'classroom':match[2].strip()})
        cursor=match.end()
    if not result or raw[cursor:].strip():raise ValueError('원문 출석 시각 구성을 완전히 확인할 수 없음')
    for i,a in enumerate(result):
        for b in result[i+1:]:
            if a['weekday']==b['weekday'] and max(a['startMinute'],b['startMinute'])<min(a['endMinute'],b['endMinute']):raise ValueError('원문 교시 구성 중복')
    return result


def ordinary_dates(meetings):
    holidays={dt.date(2026,9,24),dt.date(2026,9,25),dt.date(2026,10,5),dt.date(2026,10,9)}
    makeup={dt.date(2026,12,7):1,dt.date(2026,12,8):5,dt.date(2026,12,9):5,dt.date(2026,12,10):4}
    result=[];date=dt.date(2026,8,31)
    while date<=dt.date(2026,12,17):
        if date not in holidays:
            source_day=makeup.get(date,date.isoweekday())
            for meeting in meetings:
                if meeting['weekday']==source_day:
                    result.append({**meeting,'date':date.isoformat(),'weekday':date.isoweekday(),'deliveryMode':'inPerson'})
        date+=dt.timedelta(days=1)
    return result


def actual_rows():
    for number in [2,3,4,5]:
        data=json.loads((ROOT/f'kunsan-2026-2-attachment-{number}-rows.json').read_text())
        sheets={'전체':data['전체']} if number==3 else data
        for sheet,rows in sheets.items():
            header=next(r for r in rows if any(str(v).replace(' ','')=='학수번호' for v in r))
            headers=[re.sub(r'\s+','',str(v or '')) for v in header]
            for index,row in enumerate(rows,1):
                values={key:value for key,value in zip(headers,row) if key}
                code=str(values.get('학수번호') or '')
                if not re.fullmatch(r'\d{6}',code):continue
                section=str(values.get('분반') or '')
                if not re.fullmatch(r'\d{2}',section):raise ValueError('Actual section must remain source two-digit value')
                yield {'file':number,'sheet':sheet,'rowNumber':index,'values':values,'code':code,'section':section}


def prepare():
    grouped=defaultdict(list)
    for source in actual_rows():grouped[(source['code'],source['section'])].append(source)
    if len(grouped)!=1718 or sum(map(len,grouped.values()))!=2039:raise ValueError('Whole actual source scope changed')
    courses=[];conflicts=[]
    for (code,section),sources in grouped.items():
        values=[s['values'] for s in sources]
        def strings(key):return list(dict.fromkeys(str(v[key]).strip() for v in values if v.get(key) is not None and str(v[key]).strip()))
        names=strings('교과목명');credits={float(v['학점']) for v in values if v.get('학점') is not None}
        if len(credits)!=1:raise ValueError('Conflicting actual credit values')
        raw_times=strings('시간표');methods=strings('대면/비대면');professors=strings('담당교원');classes=strings('이수구분')
        departments=[];deptclasses=defaultdict(list);deptremarks=defaultdict(list)
        for source in sources:
            v=source['values'];dept=str(v.get('전공') or v.get('학과(부)') or v.get('MCD과정') or v.get('MD과정') or v.get('학부') or '').strip()
            if dept=='전공없음':dept=str(v.get('학과(부)') or v.get('대학') or '').strip()
            if dept and dept not in departments:departments.append(dept)
            if dept and v.get('이수구분') and v['이수구분'] not in deptclasses[dept]:deptclasses[dept].append(v['이수구분'])
            for key in ['비고','팀티칭','대상학년,학과(부)','강의','구분']:
                if v.get(key) is not None and str(v[key]).strip():
                    text=f'{key}: {v[key]}'
                    if text not in deptremarks[dept]:deptremarks[dept].append(text)
        remarks=' / '.join(dict.fromkeys(text for entries in deptremarks.values() for text in entries))
        raw_time=raw_times[0] if raw_times else ''
        reasons=[];review=[];dated=[]
        if len({re.sub(r'\s+','',n) for n in names})!=1:reasons.append('동일 실제 학수번호·분반의 원문 과목명 상충')
        if len(raw_times)>1:reasons.append('동일 실제 학수번호·분반의 원문 시간표 상충')
        if re.search(r'집중강의|현장.*실습|인턴|스키|스노보드|승마|골프중급|전공연계진로', ' '.join(names)+' '+raw_time+' '+remarks):reasons.append('집중·현장 수업의 실제 날짜·출석 시각 미확인')
        jst=any(s['sheet']=='JST공유대학' for s in sources)
        ocu=all(s['sheet']=='OCU·KCU컨소시엄' for s in sources)
        if jst:reasons.append('JST 공개 목록에 실제 시간표·담당교원 미게시')
        if raw_time and methods!=['대면']:reasons.append('원격·혼합 운영의 실제 동시 출석 방식 미확인')
        if raw_time and not reasons:
            try:review=parse_numeric_clock(raw_time);dated=ordinary_dates(review)
            except ValueError as e:reasons.append(str(e))
        if reasons:status='unrecognized'
        elif ocu:status='untimed'
        elif dated:status='scheduled'
        else:status='untimed'
        if reasons:conflicts.append({'courseCode':code,'section':section,'reasons':reasons,'sourceSchedule':raw_time})
        rooms=re.findall(r'\[([^\]]+)\]',raw_time)
        campus='saemangeum' if rooms and all(r.startswith('캠퍼스관-') for r in rooms) else 'unknown'
        courses.append({'sourceId':f'kunsan/{campus}/2026/2/{code}/{section}','universityId':'kunsan','campus':campus,'academicYear':2026,'semester':'2','courseCode':code,'section':section,'courseName':names[0],'sourceNames':names,'credits':next(iter(credits)),'professor':' / '.join(professors),'departments':departments,'classification':' / '.join(classes),'departmentCredits':{d:next(iter(credits)) for d in departments},'departmentClassifications':{d:' / '.join(c) for d,c in deptclasses.items()},'departmentRemarks':{d:' / '.join(r) for d,r in deptremarks.items()},'remarks':remarks+(' / ' if remarks and reasons else '')+' / '.join(reasons),'sourceSchedule':raw_time,'sourceClassroom':' / '.join(dict.fromkeys(rooms)),'sourceTeachingMethods':methods,'scheduleStatus':status,'schedules':dated if not reasons else [],'sourceOccurrences':[{'file':s['file'],'sheet':s['sheet'],'row':s['rowNumber']} for s in sources]})
    return {'schemaVersion':2,'productionReady':False,'completionClaim':False,'finalActiveScopeVerified':False,'campusScopeVerified':False,'courses':courses,'counts':dict(Counter(c['scheduleStatus'] for c in courses)),'campusCounts':dict(Counter(c['campus'] for c in courses)),'individualBlocked':conflicts,'sourceBoundary':'Whole currently served package re-fetched identical; September4/9 closure changes not publicly corroborated. Circled practical or period11+ clocks remain blocked. Only explicit numeric1–10 ordinary in-person slots converted; whole ordinary term and four makeup substitutions from current guide.'}

if __name__=='__main__':
    result=prepare();(ROOT/'kunsan-current-whole-normalized-review-unregistered.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(len(result['courses']),result['counts'],result['campusCounts'])
