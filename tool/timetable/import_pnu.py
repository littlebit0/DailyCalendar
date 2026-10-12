#!/usr/bin/env python3
"""Import complete anonymous PNU undergraduate results with current restrictions.

Campus locations come from published room labels, not department-name guesses.
Online/external/unspecified locations retain a separate shared group. The source
schedule is always retained; asynchronous cyber placeholders do not become timed
weekly classes. Actual 50/75/100-minute durations are preserved for the existing
half-hour timetable rendering policy.
"""
import argparse,json,re
from pathlib import Path
from html import unescape
DAYS='월화수목금토일'
CAMPUS_NAMES={'busan':'부산캠퍼스','yangsan':'양산캠퍼스','miryang':'밀양캠퍼스','ami':'아미캠퍼스','shared':'온라인·외부·위치 미지정','multiple':'여러 캠퍼스'}

def clean(value):
    return re.sub(r'\s+',' ',re.sub('<[^>]+>',' ',unescape(value or ''))).strip()

def meetings(text, asynchronous=False):
    result=[];locations=set()
    for part in re.split(r',\s*(?=[월화수목금토일]\s)',clean(text)):
        if not part:continue
        if re.fullmatch('[월화수목금토일] 사이버수업',part):continue
        m=re.fullmatch(r'([월화수목금토일])\s+(\d{2}):(\d{2})(?:-(\d{2}):(\d{2})|\((\d+)\))\s*(.+)',part)
        if m is None:raise ValueError('Unrecognized PNU schedule: '+part)
        day=DAYS.index(m[1])+1;hour=int(m[2]);minute=int(m[3]);start=hour*60+minute
        if hour>23 or minute>59:raise ValueError('Invalid PNU start time')
        if m[6]:end=start+int(m[6])
        else:
            if int(m[4])>23 or int(m[5])>59:raise ValueError('Invalid PNU end time')
            end=int(m[4])*60+int(m[5])
        if end<=start or end>1440:raise ValueError('Invalid PNU duration')
        room=m[7].strip()
        # '(외부)' takes precedence over embedded strings, including the
        # published malformed URL containing 양산Y / 밀양M substitutions.
        if room.startswith('(외부)'):campus='shared'
        elif room.startswith('양산'):campus='yangsan'
        elif room.startswith('밀양'):campus='miryang'
        elif room.startswith('아미'):campus='ami'
        elif re.match(r'\d{3}-',room):campus='busan'
        else:raise ValueError('Unverified PNU classroom campus: '+room)
        locations.add(campus)
        if not asynchronous:
            previous=next((m for m in result if (m['weekday'],m['startMinute'],m['endMinute'])==(day,start,end)),None)
            if previous is None:
                result.append({'weekday':day,'startMinute':start,'endMinute':end,'classroom':room})
            elif room not in previous['classroom'].split(' / '):
                previous['classroom']+=' / '+room
    campuses=locations-{'shared'}
    campus=next(iter(campuses)) if len(campuses)==1 else 'multiple' if campuses else 'shared'
    return result,campus

def parse_rows(rows,year=2026,semester='2'):
    result=[];ids=set()
    for row in rows:
        if row['SYEAR']!=str(year) or row['TERM_GCD']!='0020' or row['COURSE_COLL_GRAD_GCD']!='0001':raise ValueError('Wrong PNU undergraduate term')
        code,section=row['SUBJ_NO'],row['CLASS_NO']
        if not re.fullmatch('[A-Z]+[0-9]+',code) or not re.fullmatch('[0-9]{3}',section):raise ValueError('Invalid PNU identity')
        if (code,section) in ids:raise ValueError('Duplicate PNU identity')
        ids.add((code,section))
        title=clean(row['SUBJ_NM']);dept=re.sub(r'\s*\([0-9| \-]+\)$','',clean(row['MNG_DEPT_NM']));credits=float(row['CRDT'])
        if not title or not dept or not 0<=credits<=30:raise ValueError('Invalid PNU course metadata')
        if 'restriction' not in row:raise ValueError('Missing current PNU restriction')
        schedule=clean(row['TIMETABLE_SUMMARY_INFO']);remote=clean(row['ALL_CYBER'])
        scheduled,campus=meetings(schedule,'비실시간' in remote)
        remarks=' · '.join(dict.fromkeys(clean(row.get(k)) for k in ['REMARK','restriction','ALL_CYBER','NATIVE_LANG_NM'] if clean(row.get(k))))
        if '사이버수업' in schedule and '사이버수업' not in remarks:remarks=' · '.join(filter(None,[remarks,'비동기 사이버수업: '+schedule]))
        result.append({'sourceId':f'pnu/{campus}/{year}/{semester}/{code}/{section}','universityId':'pnu','campus':campus,'academicYear':year,'semester':semester,
            'courseCode':code,'section':section,'courseName':title,'professor':clean(row['PROF_NM']),'credits':credits,
            'sourceSchedule':schedule,'sourceClassroom':' / '.join(dict.fromkeys(m['classroom'] for m in scheduled)),
            'scheduleStatus':'scheduled' if scheduled else 'unscheduled','schedules':scheduled,
            'departments':[dept],'departmentCredits':{dept:credits},'departmentClassifications':{dept:clean(row['SUBJ_GCD_NM'])},'departmentRemarks':{dept:remarks}})
    if not result:raise ValueError('Empty PNU catalog')
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--raw',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--checked-at',required=True);a=p.parse_args()
    manifest=json.loads((a.raw/'manifest.json').read_text());rows=json.loads((a.raw/'courses.json').read_text())
    if manifest.get('complete') is not True or set(manifest['categoryCounts'])!={'1','2','3','4','5'} or manifest['total']!=len(rows) or sum(manifest['categoryCounts'].values())!=len(rows):raise ValueError('Incomplete PNU collection')
    courses=parse_rows(rows,manifest['year'],manifest['semester']);a.output.mkdir(parents=True,exist_ok=True)
    for campus in sorted({c['campus'] for c in courses}):
        selected=[c for c in courses if c['campus']==campus]
        (a.output/f'pnu-{campus}-2026-2.json').write_text(json.dumps({'schemaVersion':1,'universityId':'pnu','campus':campus,'campusName':CAMPUS_NAMES[campus],'academicYear':manifest['year'],'semester':manifest['semester'],'publishedDate':a.checked_at,'sourceUrl':manifest['sourceUrl'],'courses':selected},ensure_ascii=False,indent=2)+'\n')
        print(campus,len(selected),sum(bool(c['schedules']) for c in selected))
