"""Preserve 40 existing verified offerings; add only three directly dated plans."""
import copy
import datetime as dt
import hashlib
import json
import re
from pathlib import Path
ROOT = Path(__file__).parent
OUT = ROOT / 'sogang-additions-20261008'
BASE = Path('assets/timetable/sogang-unknown-2026-2.json')
base = json.loads(BASE.read_text())
result = copy.deepcopy(base)
proofs = []

def read_source(key):
    p = OUT / f'{key}.source-education.json'
    source = json.loads(p.read_text())
    if key == 'EDUF982-01':
        source['sourceHeader'] = source['sourceHeader'].split('E-mail')[0]
        p.write_text(json.dumps(source, ensure_ascii=False, indent=2) + '\n')
    row = source['currentPublicRow']
    c = next(c for c in result['courses'] if c['courseCode'] + '-' + c['section'] == key)
    assert not c['schedules']
    assert all(row.get(k, '') == v for k,v in c['sourceEducationalMetadata'].items())
    assert row['year'] == '2026 학년도' and row['semester'] == '2학기'
    assert source['currentBytesEqualPrior']
    assert re.sub(r'\s+', '', row['subjectCode']) in re.sub(r'\s+', '', source['sourceHeader'])
    return c, source

def finish(c, source, meetings, exclusions, note):
    meetings.sort(key=lambda x: x['date'])
    assert len({(m['date'], m['startMinute']) for m in meetings}) == len(meetings)
    for m in meetings:
        d = dt.date.fromisoformat(m['date'])
        assert d.isoweekday() == m['weekday'] and dt.date(2026,9,1) <= d <= dt.date(2026,12,21)
        assert m['date'] not in exclusions
    c.update(schedules=meetings, scheduleStatus='scheduled', partialSchedule=True,
             period={'startDate': meetings[0]['date'], 'endDate': meetings[-1]['date']},
             scheduleEvidence={'basis':'currentPublicPlanPrintedDates','attendanceConfirmed':False,'count':len(meetings)})
    for dep in c['departmentRemarks']:
        c['departmentRemarks'][dep] += '\n' + note
    proofs.append({'offering':c['courseCode']+'-'+c['section'], 'sourcePdfSHA256':source['fileSha256'],
                   'dates':[m['date'] for m in meetings], 'meetings':meetings,'exclusions':exclusions,
                   'nativeClock':source['currentPublicRow']['meetingText'],'currentPDFEqualPrior':True})

c,s = read_source('EDUF982-01')
t=s['weeklyOperatingText']
# Source column dates are individual class dates, not assignment deadlines.
dates=['9/2','9/4','9/9','9/11','9/16','9/23','9/30','10/2','10/7','10/14','10/16',
       '10/28','10/30','11/4','11/6','11/11','11/18','11/25','11/27','12/2','12/4']
meetings=[]
for literal in dates:
    assert literal in t
    d=dt.date(2026,*map(int,literal.split('/')))
    assert d.isoweekday() in (3,5)
    meetings.append({'date':d.isoformat(),'weekday':d.isoweekday(),'startMinute':900,'endMinute':975,'classroom':'J112'})
assert len(meetings)==21 and 'Classroom:\tTBA' in s['sourceHeader']
excluded={'2026-09-18':'college festival, source No Class','2026-09-25':'Chuseok No Class',
          '2026-10-09':'holiday; online makeup clock/mode unconfirmed',
          '2026-10-21':'midterm writing assignment, no physical exam inference',
          '2026-10-23':'midterm submission deadline, not attendance',
          '2026-11-13':'separately scheduled conferences; individual time unknown',
          '2026-11-16':'separately scheduled conferences; individual time unknown',
          '2026-11-17':'separately scheduled conferences; individual time unknown',
          '2026-11-20':'study day; makeup via separately scheduled conferences',
          '2026-12-09':'team conference allocation/time unconfirmed',
          '2026-12-11':'individual conference allocation/time unconfirmed',
          '2026-12-16':'final paper week','2026-12-18':'final paper deadline'}
finish(c,s,meetings,excluded,'현재 분반 계획서에 직접 적힌 일반 수업·교실 내 시연 21회만 반영합니다. 계획서 강의실은 TBA이고 현재 공시 강의실은 J112로 지정되어 공시값을 보존합니다. 9/18 축제, 9/25 추석, 10/9 한글날과 온라인 보강, 11/20 논술고사 휴강은 고정 출석을 생성하지 않습니다. 11/13·16·17 별도 예약 면담과 12/9 팀 면담·12/11 개인 면담은 배정 시각 미확인으로 보류합니다. 중간·기말은 글쓰기 과제 제출이므로 공시 시험 예약을 출석으로 추가하지 않습니다. 교직이수자만 전공학점 인정이며 수강대상 2·3·4학년과 권장 1~4학년은 원문처럼 구분합니다. 학교 공시 계획이며 후속 변경 공지를 확인하세요.')

c,s = read_source('MGT3003-02')
t=s['weeklyOperatingText']; compact=re.sub(r'\s+','',t)
assert '실시간 비대면 Zoom 강의, 대면 시험' in s['sourceHeader']
blocks=re.split(r'(\d+)\s*주차',t);meetings=[]
excluded={'2026-09-18':'festival closure','2026-09-25':'Chuseok closure','2026-10-09':'Hangeul closure','2026-11-20':'admission essay closure; recorded makeup not fixed attendance'}
for i in range(1,len(blocks),2):
    week=int(blocks[i]);body=blocks[i+1]
    if week in (8,16):
        assert '대면 시험' in body and '추후 공지' in body
        continue
    header=body.split('학습목표')[0]
    for mm,dd in re.findall(r'(\d{1,2})/(\d{1,2})\s*[수금]',header):
        d=dt.date(2026,int(mm),int(dd))
        if d.isoformat() in excluded: continue
        assert d.isoweekday() in (3,5)
        meetings.append({'date':d.isoformat(),'weekday':d.isoweekday(),'startMinute':900,'endMinute':975,'classroom':'','deliveryMode':'liveOnline'})
assert len(meetings)==24
finish(c,s,meetings,excluded,'현재 공개 계획서의 실시간 비대면 Zoom 정규 강의 24회만 반영하며 대면 시험과 구분합니다. 9/18·9/25·10/9·11/20 휴강은 생성하지 않습니다. 물류·SCM 보강은 녹화 강의로 안내되어 11/20~12/16 임의 출석 시각을 만들지 않습니다. 중간·기말은 대면 시험이지만 실제 일시·교내 장소 추후 공지이므로 보류합니다. 추가 수강은 등록 허가 인원에 따라 교수 승인 가능하며 최신 계획서 버전을 확인해야 합니다. 수업 중 카메라 켜기, 호명 응답, 이동 중 수강 금지와 FA 출결 규정이 적용됩니다.')

c,s=read_source('MAS1006-01');t=s['weeklyOperatingText'];meetings=[]
assert 'Classroom MA206' in s['sourceHeader']
blocks=re.split(r'Week\s+(\d+)\s*\(([^)]+)\)',t)
for i in range(1,len(blocks),3):
    week=int(blocks[i]);literal=blocks[i+1];body=blocks[i+2]
    if week in (8,16): continue
    dates=re.findall(r'(\d{1,2})/(\d{1,2})',literal)
    for mm,dd in dates:
        d=dt.date(2026,int(mm),int(dd))
        if d==dt.date(2026,9,24):
            assert 'No Class' in body
            continue
        assert d.isoweekday() in (2,4)
        meetings.append({'date':d.isoformat(),'weekday':d.isoweekday(),'startMinute':810,'endMinute':885,'classroom':'MA206'})
assert len(meetings)==27
row=s['currentPublicRow'];assert row['exam']=='10.22(목)13:30~14:45[MA206]'
assert 'Mid-term Exam on 10/22 (Th)' in t
meetings.append({'date':'2026-10-22','weekday':4,'startMinute':810,'endMinute':885,'classroom':'MA206'})
finish(c,s,meetings,{'2026-09-24':'Chuseok No Class','2026-10-20':'midterm week, no ordinary class','2026-12-15':'final week','2026-12-17':'final exam date printed, actual clock unpublished'},'현재 계획서에 직접 게시된 일반 수업·학생 주도 토론 27회와 계획서·공시 시험일자가 일치하는 10/22 중간시험 1회를 반영합니다. 과제 제출일 11/30은 수업 출석으로 생성하지 않습니다. 12/17 기말시험 날짜는 게시되었으나 실제 시험 시각은 미공개이므로 정규 강의 시각을 복사하지 않습니다. 계획과 읽기자료는 후속 공지에 따라 바뀔 수 있습니다.')
changed=[a['courseCode']+'-'+a['section'] for a,b in zip(base['courses'],result['courses']) if a!=b]
assert changed==[p['offering'] for p in sorted(proofs,key=lambda p:next(i for i,c in enumerate(base['courses']) if c['courseCode']+'-'+c['section']==p['offering']))]
assert len(changed)==3
candidate=OUT/'sogang-unknown-2026-2.forty-three-reviewed-20261008.json'
candidate.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
audit={'baseFile':str(BASE),'baseSHA256':hashlib.sha256(BASE.read_bytes()).hexdigest(),
       'candidateFile':candidate.name,'candidateSHA256':hashlib.sha256(candidate.read_bytes()).hexdigest(),
       'whole':1541,'previousScheduled':40,'previousPlans':936,'addedScheduled':3,'addedPlans':73,
       'scheduled':43,'plans':1009,'changedOnly':changed,'unchangedSourceIds':True,
       'proofs':proofs,'campusInference':False,'classificationInference':False,
       'closureLimit':'Latest cancellation notice 551152 (2026-09-04) marked secret=Y; no protected detail requested. Current public exact offerings present, complete closure reflection unproven.',
       'completionClaim':False,'productionEdited':False}
assert sum(bool(c['schedules']) for c in result['courses'])==43
assert sum(len(c['schedules']) for c in result['courses'])==1009
(OUT/'additions-audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print('1541 whole /43 scheduled /1009 plans; only3sourceofferingchanges')
