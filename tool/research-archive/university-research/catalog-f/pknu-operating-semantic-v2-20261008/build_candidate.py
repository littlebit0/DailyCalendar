import copy
import datetime
import hashlib
import json
import pathlib

ROOT = pathlib.Path(__file__).parent
OLD = ROOT.parent / 'pknu-current-20261008'
POLICY = ROOT.parent / 'pknu-current-clock-policy-audit.json'
BASE_NAMES = [f'pknu-{campus}-2026-2.published-partial-20261008.json' for campus in ['daeyeon','unknown']]
course_map = {}
baselines = {}
for name in BASE_NAMES:
    original = (OLD/name).read_bytes()
    (ROOT/('baseline-'+name)).write_bytes(original)
    data = json.loads(original)
    baselines[name] = data
    for course in data['courses']:
        course_map[course['courseCode']+'-'+course['section']] = copy.deepcopy(course)
assert len(course_map)==2720
changed = {}
excluded = set(json.loads((OLD/'candidate-audit.json').read_text())['excludedHolidays'])

def add_period(identity, date, day, period, kind):
    c = course_map[identity]
    start = 480 + period*60
    c['schedules'].append({'weekday':day,'startMinute':start,'endMinute':start+50,'classroom':c['sourceClassroom'],'sourcePeriod':period,'sourceMinuteUnit':50,'date':date})
    changed[identity]['dateKinds'][date]=kind

def enable(identity, basis):
    c = course_map[identity]
    assert not c['schedules']
    receipt = json.loads((ROOT/(identity+'.current-operating-education.json')).read_text())
    assert ''.join(receipt['fields']['학수번호'])==c['courseCode']
    assert ''.join(receipt['fields']['분반'])==c['section']
    assert ' '.join(receipt['fields']['강의시간']) == c['sourceSchedule']
    assert ', '.join(receipt['fields']['강의실']) == c['sourceClassroom']
    changed[identity]={'identity':identity,'basis':basis,'receipt':identity+'.current-operating-education.json','dateKinds':{},'currentNativePeriods':copy.deepcopy(c['sourceNativePeriods']),'sourceRoom':c['sourceClassroom']}

# Campus unknown does not erase institution-wide explicitly known clock/room.
for identity in ['102811-101','106337-101','114409-102','100987-101','112758-101','112807-101']:
    enable(identity, 'ordinary current weekly public plan; unknown campus preserved' if identity.startswith(('102811','106337','114409')) else 'ordinary current weekly plan with explicit individual evaluation dates retained separately')
    for offset in range(98):
        date = datetime.date(2026,9,1)+datetime.timedelta(days=offset)
        if str(date) in excluded:
            continue
        for period in course_map[identity]['sourceNativePeriods']:
            if period['weekday']==date.isoweekday():
                kind = 'explicit individual evaluation in ordinary time' if (identity=='100987-101' and str(date)=='2026-10-26') or (identity=='112807-101' and str(date)=='2026-10-23') else 'ordinary weekly reservation'
                add_period(identity,str(date),date.isoweekday(),period['period'],kind)
for identity,date in [('100987-101','2026-12-14'),('112758-101','2026-12-18'),('112807-101','2026-12-18')]:
    day = datetime.date.fromisoformat(date).isoweekday()
    for period in course_map[identity]['sourceNativePeriods']:
        if period['weekday']==day:
            add_period(identity,date,day,period['period'],'explicit individual final evaluation in published ordinary course time')

enable('112888-101','only directly printed in-person Saturday dates; asynchronous remainder held')
for day in ['09-05','09-19','10-03','10-17','10-24','11-07','11-21','12-19']:
    date = '2026-'+day
    assert datetime.date.fromisoformat(date).isoweekday()==6
    for period in course_map['112888-101']['sourceNativePeriods']:
        add_period('112888-101',date,6,period['period'],'explicit individual in-person/assessment day, including Oct3 source holiday override')

enable('103392-103','current official ordinary undergraduate period namespace; periods11–13 available only in50minute table, outside75minute table1–9; inferential clock mapping, not explicit plan HH:mm')
for day in ['09-01','10-13','10-20','10-27','12-01','12-15']:
    date='2026-'+day
    assert datetime.date.fromisoformat(date).isoweekday()==2
    for period in course_map['103392-103']['sourceNativePeriods']:
        assert period['period'] in [11,12,13]
        add_period('103392-103',date,2,period['period'],'explicit individual in-person/assessment day with unique current-table clock inference')

enable('114580-101','explicit live online final examination Dec9 12:00–13:00; asynchronous ordinary lectures remain ungenerated')
course_map['114580-101']['schedules']=[{'weekday':3,'startMinute':720,'endMinute':780,'classroom':'','date':'2026-12-09'}]
changed['114580-101']['dateKinds']['2026-12-09']='explicit live online final examination, not regular asynchronous course date'
for identity, audit in changed.items():
    c=course_map[identity]
    c['scheduleStatus']='scheduled'
    c['sourceSemanticOperatingEvidence']=audit
    c['dateProofKind']='current ordinary reservations and individually labeled published dates; not actual attendance confirmation'
    note='2026-10-08 현재 공개 원문 운영 문맥 재검토: '+audit['basis']+'. 공개 예약 계획이며 실제 출석 확정 아님. 원문 시각·강의실 및 사용자 방식 선택 보존. 개별 평가일·대면 지정일은 정규 반복과 별도로 원문 날짜 근거를 보존했습니다. 캠퍼스 미확인만으로 예약을 보류하지 않으며 캠퍼스는 추정하지 않습니다.'
    def reviewed_note(text):
        if ' 일정 미생성: ' in text:
            beginning, tail = text.split(' 일정 미생성: ',1)
            marker = ' 현재 강의실 건물로 확인된 캠퍼스: '
            text = beginning + (marker + tail.split(marker,1)[1] if marker in tail else '')
        return text + ' / ' + note
    c['sourceSemanticOperatingEvidence']['priorReservationRemarks'] = c['remarks']
    c['sourceSemanticOperatingEvidence']['priorDepartmentReservationRemarks'] = copy.deepcopy(c['departmentRemarks'])
    c['remarks']=reviewed_note(c['remarks'])
    c['departmentRemarks']={key:reviewed_note(value) for key,value in c['departmentRemarks'].items()}
    assert len({json.dumps(x,sort_keys=True) for x in c['schedules']})==len(c['schedules'])

datasets=[]
for name,baseline in baselines.items():
    data=copy.deepcopy(baseline)
    data['courses']=[course_map[c['courseCode']+'-'+c['section']] for c in baseline['courses']]
    data.update(researchOnly=True,completionClaim=False,wholeOperatingVerified=False,wholeSchoolCourseCoverageComplete=False,reservationOnly=True)
    filename=name.replace('.published-partial-20261008','.semantic-reviewed-v2-20261008')
    (ROOT/filename).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    datasets.append({'file':filename,'sha256':hashlib.sha256((ROOT/filename).read_bytes()).hexdigest(),'whole':len(data['courses']),'scheduled':sum(bool(c['schedules']) for c in data['courses']),'meetings':sum(len(c['schedules']) for c in data['courses'])})
    for old,c in zip(baseline['courses'],data['courses']):
        identity=c['courseCode']+'-'+c['section']
        if identity not in changed:
            assert old==c
        else:
            assert not old['schedules']
            for key in old:
                if key not in ['schedules','scheduleStatus','dateProofKind','remarks','departmentRemarks']:
                    assert old[key]==c[key],(identity,key)
policy=json.loads(POLICY.read_text())
(ROOT/'current-clock-policy-education.json').write_text(json.dumps({'revision':policy['revision'],'officialDetail':policy['officialDetail'],'officialDownload':policy['officialDownload'],'clockEvidence':policy['clockEvidence'],'schema':policy['schema'],'mapping103392':'Inferential unique table mapping: current public ordinary undergraduate plan literal periods11/12/13 with current January2026 official undergraduate table;75 table defines only1–9. Historical July50 corroborates but does not select current unit. No1–9 ambiguous Tuesday/Thursday class enabled.'},ensure_ascii=False,indent=2)+'\n')
audit={'researchOnly':True,'completionClaim':False,'whole':2720,'prior1049DeepEqual':True,'prior43018DeepEqual':True,'newCourses':len(changed),'newMeetings':sum(len(course_map[x]['schedules']) for x in changed),'datasets':datasets,'courseProofs':list(changed.values()),'current30PublishedPlansReviewed':True,'wholeCurrentQueryReobtained':False,'wholeOperatingVerified':False,'SDKUsed':False,'actualFixture':'pending'}
(ROOT/'candidate-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in audit.items() if k not in ['courseProofs','datasets']},ensure_ascii=False));print(datasets)
