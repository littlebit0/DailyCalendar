import json,collections
scr={d['sourceId']:d for d in json.load(open('/Users/kimhwi/Documents/Codex/DailyCalendar/work/university-research/catalog-c/ordinary-weekly-held-audit-20261008/khu-native-plan-screen.json'))['decisions']}
W='/Users/kimhwi/Documents/Codex/DailyCalendar/work/wt/u-khu-tt/assets/timetable/'
order=[('원문 모순(시간표·강의계획서 시각/강의실 불일치 또는 시간표 변형 충돌)',{'currentPlanNativeClockRoomMismatch','nativeScheduleVariantConflict'}),
 ('원격 운영(온라인강의 별도 선택·블렌디드 배정 미공개)',{'onlineLectureColumnSelected','priorExplicitBlendedFlippedAllocationUnconfirmed'}),
 ('공식 강의실·시각 표기 불완전',{'nativeClockRoomMissingOrInvalid','nativeClockNotFullyParsed'}),
 ('강의계획서 수업유형 특수 비율 선택(온라인·플립 등)',{'currentPlanSelectedSpecialOperatingType'}),
 ('강의계획서 주차별 운영 특수 신호(실습·집중·휴보강 등)',{'currentPlanOperatingOrWeeklySpecialSignal'}),
 ('강좌명·비고 특수 신호',{'nativeTitleOrRemarksSpecialSignal'})]
by=collections.Counter(); camp=collections.Counter(); rows=[]
for c in ['seoul','global']:
  for x in json.load(open(W+f'khu-{c}-2026-2.json'))['courses']:
    if x['scheduleStatus']!='unrecognized': continue
    camp[c]+=1
    rs=set(scr.get(x['sourceId'],{}).get('screenReasons',[]))
    if x.get('currentOperatingCorrection'): rs.add('onlineLectureColumnSelected')
    p=next((n for n,s in order if rs&s),'10-08 검토 기록 없음')
    by[p]+=1; rows.append(dict(sourceId=x['sourceId'],schedule=x['sourceSchedule'],reason=p,flags=sorted(rs)))
json.dump(dict(byCampus=camp,byReason=by,rows=rows),open('unresolved-725.json','w'),ensure_ascii=False,indent=1)
print(camp,sum(camp.values()));[print(v,k) for k,v in by.most_common()]
print('with clock',sum(1 for r in rows if any(ch.isdigit() for ch in r['schedule'])))
