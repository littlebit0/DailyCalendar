"""Deprecated parser2 research snapshot; use tool/timetable/import_hansung.py.

This file is retained as historical evidence only. It must not regenerate current
candidates or override the canonical parser4 identity and operating checks.
"""
raise RuntimeError("Historical parser2 helper disabled; use tool/timetable/import_hansung.py with current parser4 proofs")

"""Whole source metadata plus strict current operating review; never activation."""
import collections
import html
import json
from pathlib import Path
import re
import hansung_clock

ROOT=Path(__file__).resolve().parent


def clean(value):
    return re.sub(r'\s+',' ',html.unescape(str(value or ''))).strip()


def prepare():
    rows=json.loads((ROOT/'hansung-current-full-educational-rows.json').read_text())
    groups=collections.defaultdict(list)
    for row in rows:groups[(row['kwamokcode'],row['bunban'])].append(row)
    courses=[];reasons=collections.Counter()
    neutral=set(json.loads((ROOT/'hansung-reviewed-neutral-operating-lines.json').read_text())['lines'])
    intensive={'GEN0993','GEN1031','P010143','P010167','P017023','T030132','V020036','V070078','V076015','Y030038'}
    for (code,section),variants in groups.items():
        r=variants[0]
        for v in variants:
            if any(v[f]!=r[f] for f in ['kwamokname','hakjum','prof','classroom','bigo']):
                raise ValueError('Core educational aliases conflict')
        departments=[];classifications={};credits={};remarks={}
        for v in variants:
            dep=re.sub(r'^\[[A-Z0-9]+\]\s*','',v['departmentName']).strip()
            if dep not in departments:departments.append(dep)
            classifications[dep]=clean(v['isugubun']);credits[dep]=float(v['hakjum'])
            note=[clean(v['bigo'])] if clean(v['bigo']) else []
            if v['haknean'].strip():note.append('대상 학년: '+v['haknean'].strip())
            if v['haknean_limit'].strip():note.append('학년 제한(원문): '+v['haknean_limit'].strip())
            if v['excl_ext_stu']=='1':note.append('타교생 수강 제외(공식 원표)')
            remarks[dep]='\n'.join(note)
        schedules=[];status='unrecognized';reason=''
        raw=clean(r['classroom'])
        proof_path=ROOT/'hansung-current-operating-proofs'/f'{code}-{section}.json'
        p=json.loads(proof_path.read_text()) if proof_path.exists() else {'status':'notChecked'}
        if not raw or re.fullmatch(r'온라인강좌\s+[\d.]+시간',raw):
            status='unscheduled'
        else:
            try: source_meetings=hansung_clock.schedules(raw)
            except ValueError as e:reason=str(e)
            else:
                if p['status']!='currentVerifiedIdentity':reason='Current plan not published or not verified'
                elif p.get('educationalParserVersion')!=2:reason='English operation context not yet reverified'
                elif clean(p['sourceSchedule'])!=raw:reason='Current plan/source timetable differ'
                elif p['sourceOfflineFlag']!='Y':reason='Mixed or online operating context requires review'
                elif not all(w['topicPublished'] for w in p['weeks']):reason='Incomplete actual current week context'
                elif code in intensive:reason='Actual current intensive-period operations require review'
                else:
                    lines=p['operatingNotes']+[t for w in p['weeks'] for t in w['operatingEvidence']]
                    special=[t for t in lines if t not in neutral]
                    if special:reason='Whole current operating context requires semantic review'
                    else:status='scheduled';schedules=source_meetings
        if reason:
            reasons[reason]+=1
            for dep in departments:remarks[dep]+=('\n' if remarks[dep] else '')+'수업 운영·시각 검증 중: 확인 전 자동 반복 추가 불가.'
        course={'sourceId':f'hansung/main/2026/2/{code}/{section}','universityId':'hansung','campus':'main',
                'academicYear':2026,'semester':'2','courseCode':code,'section':section,'courseName':clean(r['kwamokname']),
                'professor':clean(r['prof']),'credits':float(r['hakjum']),
                'sourceSchedule':raw,'sourceClassroom':raw,'scheduleStatus':status,'schedules':schedules,
                'departments':departments,'departmentCredits':credits,'departmentClassifications':classifications,
                'departmentRemarks':remarks}
        # Calendar explicitly reserves Dec7-19 for final exams/makeup. No guessed exam times.
        if status=='scheduled':course['period']={'startDate':'2026-08-31','endDate':'2026-12-06'}
        courses.append(course)
    return courses,reasons

if __name__=='__main__':
    courses,reasons=prepare();counts=collections.Counter(c['scheduleStatus'] for c in courses)
    data={'schemaVersion':2,'universityId':'hansung','campus':'main','campusName':'본교','academicYear':2026,'semester':'2',
          'publishedDate':'2026-10-08','sourceUrl':'https://info.hansung.ac.kr/jsp_21/student/kyomu/siganpyo_aui.jsp?viewMode=oc',
          'researchOnly':True,'productionReady':False,'completionClaim':False,'courses':courses}
    (ROOT/'hansung-current-whole-review-unregistered.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    (ROOT/'hansung-current-whole-review-audit.json').write_text(json.dumps({'whole':len(courses),'statuses':counts,'unverifiedReasons':reasons,'productionReady':False,'completionClaim':False},ensure_ascii=False,indent=2)+'\n')
    print('Whole',len(courses),dict(counts),dict(reasons))
