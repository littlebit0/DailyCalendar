"""Four individually read current Wednesday plans: repeated normal rule + printed final."""
import copy,json,hashlib
from datetime import date,timedelta
from pathlib import Path
ROOT=Path(__file__).resolve().parent
KEYS={'A01399101','A01418401','U04239101','U04239102'}
proofs={}
for key in KEYS:
    document=json.loads((ROOT/f'hufs-public-operating-plans/H1-{key}.json').read_text())
    fields=document['fields'];late=fields['weekly']['15th']
    assert '12/9' in late and 'No class' in late or '12/9' in late and 'NO CLASS' in late
    assert '12/16' in late and ('Final Exam' in late or '기말시험' in late)
    assert not any(token in fields.get('methods','')+fields.get('notes','') for token in ['온라인','녹화','Webex','Zoom','협의'])
    sid=f'hufs/seoul/2026/2/{key[:7]}/{key[7:]}'
    proofs[sid]={'sourceUrl':document['sourceUrl'],'currentPlanHeader':fields['schedule'].splitlines()[0],'reviewedOperatingEvidenceHash':hashlib.sha256(json.dumps(fields,ensure_ascii=False,sort_keys=True).encode()).hexdigest(),'normalRepeatedRulePeriod':['2026-09-01','2026-12-07'],'printedNoClassDates':['2026-12-09'],'printedExtraClassDates':['2026-12-16'],'derivedNormalDates':True,'individuallyPrintedWholeNormalDates':False,'extraClockProof':'sameCurrentPlanFixedWednesdayHeaderAndCurrentCampusClock','actualEndDate':'2026-12-16'}
    if key.startswith('A01'):
        assert '10/21' in fields['weekly']['8th']
        proofs[sid]['printedNormalExamDates']=['2026-10-21']
    else:
        assert '9/2' in fields['weekly']['1st']
        proofs[sid]['printedNormalFirstClassDates']=['2026-09-02']

def recover(course):
    proof=proofs[course['sourceId']]
    assert course['sourceSchedule']==proof['currentPlanHeader']
    assert len(course['schedules'])==1 and course['schedules'][0]['weekday']==3
    fixed=course['schedules'][0];result=copy.deepcopy(course);days=[]
    current=date(2026,9,2)
    while current<=date(2026,12,7):days.append(current.isoformat());current+=timedelta(weeks=1)
    days+=proof['printedExtraClassDates']
    result['schedules']=[{**fixed,'date':day} for day in days]
    result['scheduleStatus']='scheduled';result['period']={'startDate':'2026-09-01','endDate':'2026-12-16'}
    return result
