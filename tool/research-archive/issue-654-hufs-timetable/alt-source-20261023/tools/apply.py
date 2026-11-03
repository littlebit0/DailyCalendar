"""2026-10-23 직접 조회 결과를 hufs 자산에 반영한다(원문 변경 10강좌 + 강의계획서 원문 기준 미확정 14강좌 해소)."""
import json,re,sys,copy,datetime as dt,collections
sys.path.insert(0,'/Users/kimhwi/Documents/Codex/DailyCalendar/work/wt/u-hufs-tt/tool/timetable'); import import_hufs as mod
from pathlib import Path
WT=Path('/Users/kimhwi/Documents/Codex/DailyCalendar/work/wt/u-hufs-tt')
_,rows=mod.load_complete(Path('raw1023')); raw=collections.defaultdict(list)
for r in rows: raw[(r['queryCampus'],r['row']['lssnCd'])].append(r)
clocks={'H1':{str(i):[480+i*60,530+i*60]for i in range(13)},'H2':{str(i):[480+i*60,530+i*60]for i in range(1,13)}}
closed={'2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'}
START,END=dt.date(2026,9,1),dt.date(2026,12,7)
warning=' · 공개 운영 일정 확인 중: 자동 시간 생성 보류'
note='현재 2026-2 학교 자체 정규 교시·캠퍼스·개설 강좌 원문과 공개 운영 필드를 대조한 부분만 예약합니다. 학교 원문 날짜가 있으면 그 날짜를 우선하며, 휴일·평가·보강·원격·개별 배정·운영 미확정 부분은 별도 원문 큐에 보존합니다. 강의계획 미게시 자체만으로 공개 정규 개설 시각을 삭제하지 않으며, 실제 출석 및 대학 전체 최신 변경 확인 완료를 뜻하지 않습니다.'
def week_dates(weeks):
    out=[]
    for w in weeks:
        a=START+dt.timedelta(days=7*(w-1))
        out+= [a+dt.timedelta(days=o) for o in range(7)]
    return out
# 강의계획서(2026-10-23 조회) 원문에 따른 수업 주차/날짜. 시험·휴일·보강·온라인 표기 주차는 뺀다.
ordinary=lambda excl:[w for w in range(1,15) if w not in excl]
RULES={
 ('H1','A05460202'):{'weeks':ordinary({8})},
 ('H1','A01275202'):{'weeks':ordinary({5,8})},
 ('H1','B02126501'):{'weeks':ordinary({8})},
 ('H1','Q03028104'):{'weeks':ordinary({5,8})},
 ('H2','N08135101'):{'weeks':ordinary({5,8})},
 ('H2','N01108301'):{'weeks':ordinary({4,6,8})},
 ('H2','N01201101'):{'weeks':ordinary({4,6,8})},
 ('H2','O02112101'):{'weeks':ordinary({8})},
 ('H2','U76213301'):{'weeks':ordinary({4,8})},
 ('H1','A07142301'):{'weeks':ordinary({8})},
 # 기본 오프라인, 원문이 적은 온라인 날짜(9/7, 9/28, 11/5, 11/19, 12/3) 제외
 ('H1','A02150001'):{'weeks':ordinary({8}),'skip':{'2026-09-07','2026-09-28','2026-11-05','2026-11-19','2026-12-03'}},
 # 1주차(9/4) 시작 14:00 원문, 4·6주 휴강(보강일은 정규 기간 밖)
 ('H1','E11301101'):{'weeks':ordinary({4,6,8}),'override':{'2026-09-04':(840,None)}},
 # 대면 강의 주차(원문 [N강] 행)만. 소그룹 워크샵 주차(4주 중 2주 선택)·휴일·과제대체 주차 제외
 ('H2','Y21181201'):{'dates':['2026-09-07','2026-09-14','2026-10-12','2026-10-19','2026-11-16','2026-11-23','2026-11-30','2026-12-07']},
 ('H2','Y21181204'):{'dates':['2026-09-07','2026-09-14','2026-09-21','2026-10-19','2026-11-02','2026-11-09','2026-11-30','2026-12-07']},
}
changes=[];resolved=[]
for campus,H in [('seoul','H1'),('global','H2')]:
    path=WT/f'assets/timetable/hufs-{campus}-2026-2.json'; doc=json.loads(path.read_text())
    for c in doc['courses']:
        key=c['courseCode']+c['section']; rr=raw[(H,key)]; row=rr[0]['row']
        sched=mod.clean(row['dayTimeDisplay']); prof=mod.clean(row['empNm'])
        if sched!=c['sourceSchedule'] or prof!=c['professor']:
            before={k:c[k] for k in ['sourceSchedule','sourceClassroom','professor']}
            fixed=mod.meetings(sched,clocks[H])
            if c['schedules']:
                # 요일·시각은 같고 강의실만 바뀐 경우만 자동 반영
                slot=lambda m:(m['weekday'],m['startMinute'],m['endMinute'])
                rooms={slot(f):f['classroom'] for f in fixed}
                assert {slot(m) for m in c['schedules']}<=set(rooms), key
                for m in c['schedules']: m['classroom']=rooms[slot(m)]
            c['sourceSchedule']=sched; c['professor']=prof
            c['sourceClassroom']=' / '.join(dict.fromkeys(f['classroom'] for f in fixed))
            changes.append({'sourceId':c['sourceId'],'before':before,'after':{k:c[k] for k in ['sourceSchedule','sourceClassroom','professor']}})
        old_etc='이예훈 Trolan 팀티칭 진행'
        if key=='S01116301':
            assert row['etc']=='Trolan 수업진행(팀티칭 해제)'
            c['departmentRemarks']={k:v.replace(old_etc,row['etc']) for k,v in c['departmentRemarks'].items()}
        rule=RULES.get((H,key))
        if not rule: continue
        assert c['scheduleStatus']=='unrecognized' and not c['schedules'], key
        fixed=mod.meetings(sched,clocks[H])
        if 'dates' in rule: days=[dt.date.fromisoformat(d) for d in rule['dates']]
        else: days=[d for d in week_dates(rule['weeks']) if d.isoformat() not in closed and d.isoformat() not in rule.get('skip',set())]
        meetings=[]
        for d in sorted(days):
            assert START<=d<=END
            for f in fixed:
                if f['weekday']==d.isoweekday():
                    m={'date':d.isoformat(),**f}
                    ov=rule.get('override',{}).get(d.isoformat())
                    if ov: m['startMinute']=ov[0]
                    meetings.append(m)
        if 'dates' in rule: assert len(meetings)==len(rule['dates']), key
        assert meetings
        c['schedules']=meetings; c['scheduleStatus']='scheduled'; c['sourcePartialCoverage']=True
        c['departmentRemarks']={k:v.replace(warning,'')+'\n'+note for k,v in c['departmentRemarks'].items()}
        c['semanticOperatingReview']={'sourcePartialCoverage':True,'ordinaryNativeOrLiteralDateScope':True,'actualAttendanceConfirmed':False,'sourceSnapshot':'2026-10-23','packet':'hufs_alt_source_20261023'}
        resolved.append({'sourceId':c['sourceId'],'meetings':len(meetings)})
    path.write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'changes':changes,'resolved':resolved},ensure_ascii=False,indent=1))
json.dump({'changes':changes,'resolved':resolved},open('apply-result.json','w'),ensure_ascii=False,indent=1)
