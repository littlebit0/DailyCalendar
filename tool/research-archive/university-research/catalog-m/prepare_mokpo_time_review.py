"""Educational-only current-source time review, never registration-ready events.
Period1-18 are published on the official public timetable menu; actual current
nursing time table additionally confirms19-26. Dates and makeup substitutions
are separately unverified and no weekly review is an actual imported event.
"""
from pathlib import Path
import json,re,collections
P=Path(__file__).parent
DAYS={day:index for index,day in enumerate('월화수목금토일',1)}
def parse_clock(raw):
    if not raw:return []
    result=[];cursor=0
    for match in re.finditer(r'([월화수목금토일])([0-9]+(?:,[0-9]+)*)',raw):
        if raw[cursor:match.start()].strip():raise ValueError('unrecognized raw weekday/period separator')
        periods=[int(v) for v in match[2].split(',')]
        if len(set(periods))!=len(periods) or any(v<1 or v>26 for v in periods):
            raise ValueError('unsupported or duplicate actual period')
        groups=[]
        for period in sorted(periods):
            if groups and groups[-1][-1]+1==period:groups[-1].append(period)
            else:groups.append([period])
        for group in groups:
            result.append({'weekday':DAYS[match[1]],'startMinute':540+(group[0]-1)*30,'endMinute':540+group[-1]*30,'originalPeriods':group})
        cursor=match.end()
    if not result or raw[cursor:].strip():raise ValueError('unrecognized complete raw period string')
    return result

def prepare():
    rows=json.loads((P/'mokpo-current-four-year-research-educational-20261008.json').read_text())
    campus=json.loads((P/'mokpo-current-source-campus-review-20261008.json').read_text())
    loc={(r['courseCode'],r['section']):r['campus'] for r in campus['courses']}
    notes=json.loads((P/'mokpo-concentrated-explicit-audit.json').read_text())['cases']
    special={r['course']:r['note'] for r in notes}
    nursing=json.loads((P/'mokpo-current-nursing-grade2-campus-grid-review-20261008.json').read_text())
    nursing_matches={(r['GYOGWAMOK_CD'],r['BUNBAN']):r for r in nursing['courses']}
    online=json.loads((P/'mokpo-current-missing-time-explicit-online-review-20261008.json').read_text())
    online_ids={(r['courseCode'],r['section']) for r in online['courses']}
    out=[]
    for row in rows:
        code=row['GYOGWAMOK_CD'];section=row['BUNBAN'];key=code+'-'+section
        raw=row.get('BIGO_TIME');blocks=[];clock=[];status='clockReviewed'
        if not raw:
            if 'OCU' in row['HAKGWA_NM']:status='explicitOcuUntimed'
            elif (code,section) in online_ids:status='explicitOnlineUntimed'
            else:status='unrecognized';blocks.append('Actual source time missing; representative-course alias cannot be inferred.')
        else:
            try:clock=parse_clock(raw)
            except ValueError as error:blocks.append(str(error));status='unrecognized'
        if '간호' in row['HAKGWA_NM']:
            matched=nursing_matches.get((code,section))
            if not matched or matched['BIGO_TIME']!=raw or matched['GYOGWAMOK_NM']!=row['GYOGWAMOK_NM']:
                blocks.append('Current official nursing campus/practice table takes precedence; exact course/section/date/time reconciliation pending.')
                status='unrecognized'
        if key in special:
            blocks.append('Explicit actual concentrated attendance note; exact operating dates/times pending.')
            status='unrecognized'
        out.append({'courseCode':code,'section':section,'courseName':row['GYOGWAMOK_NM'],'departmentCode':row['HAKGWA_CD'],'department':row['HAKGWA_NM'],'classification':row['ISU_GBNM'],'credits':row['HAKJEOM'],'professor':row.get('BIGO_GYOSU',''),'campus':loc[(code,section)],'sourceTime':raw,'sourceClassroom':row.get('BIGO_GANGUISIL'),'clockReview':clock,'reviewStatus':status,'individualBlockedReasons':blocks,'sourceConcentratedNote':special.get(key),'actualDatedMeetings':[]})
    return {'checkedAt':'2026-10-08','productionReady':False,'completionClaim':False,'actualOperatingDatesVerified':False,'actualMakeupSubstitutionsVerified':False,'finalActiveScopeVerified':False,'source':'official current anonymous UNCO04 query','requestedScopeSource':'mokpo-current-four-year-scope-audit-20261008.json','counts':dict(collections.Counter(r['reviewStatus'] for r in out)),'ordinaryRecurrenceWindow':{'start':'2026-09-01','endInclusive':'2026-12-07','source':'https://www.mokpo.ac.kr/schdulmanage/www/1/mokpoMainSchdul.do','sourceFile':'mokpo-current-ordinary-calendar-20261008.html','excludedLaterWindow':'2026-12-08 through 2026-12-11 school holiday makeup; 2026-12-14 through 2026-12-18 final examinations','arbitraryNationalHolidayRemovals':[],'holidayOperatingPolicyReviewPending':True,'reason':'Published regular holiday policy permits exceptional lectures/practicals. Specific actual date/substitution instructions must be verified before production import.'},'warning':'clockReviewed means source clocks reconciled, not actual attendance dates. Current school-directed public catalogue covers the whole requested scope; missing closure flag alone is not evidence that ordinary courses are unavailable. No production events created.','courses':out}
if __name__=='__main__':
    result=prepare();(P/'mokpo-current-whole-time-review-unregistered.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(len(result['courses']),result['counts'])
