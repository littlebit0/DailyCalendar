import json,copy
from pathlib import Path
p=Path(__file__).parent/'kmou-current-new-notices';a=json.loads((p/'kmou-new-collision-free-candidate.json').read_text());b=copy.deepcopy(a)
a['scheduleDerivation']='Calculated dates from published weekday/period and university-wide academic calendar; NOT original individual meeting dates. Do not apply as dated production catalog.'
a['productionIntegrationEnabled']=False
(p/'kmou-new-collision-free-candidate.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n')
for c in b['courses']:
 c['schedules']=[{'weekday':s['weekday'],'startMinute':(8+s['period'])*60,'endMinute':(8+s['period'])*60+50,'classroom':s['classroom']} for s in c['sourceClockPeriods']]
 c['scheduleDerivation']='Original weekly weekday/period converted with published university numeric period clock; no generated meeting dates.'
 c['remarks']='학교 공식 2026-2 주간 시간표. 최종 시간·장소는 종합정보시스템 확인 필요. 개별 날짜 원문 아님. 학교 전체 휴일·지정보강은 별도 학사력에 있으며 개별 강좌 변경·보강은 확인되지 않음.'
 # Semester end retains university-wide current term window; does not claim individual last meeting.
 c['sourcePeriodScope']='학교 전체 2026-2 학사기간; 개별 최종 강의일 미공개'
b['scheduleDerivation']='weekly source; no calculated individual meeting dates'
b['candidateAcceptanceRequired']='Parent must handle global academic holidays/makeup separately without representing generated dates as source-dated meetings.'
(p/'kmou-new-weekly-candidate.json').write_text(json.dumps(b,ensure_ascii=False,indent=2)+'\n')
r=json.loads((p/'candidate-receipt.json').read_text());r.update(newDatedSlotsAreCalculated=True,sourceIndividualMeetingDatesPublished=False,weeklyCandidate='kmou-new-weekly-candidate.json',weeklySlots=sum(len(c['schedules']) for c in b['courses']),datedCandidateProductionUse=False)
(p/'candidate-receipt.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
with (p/'REPORT.md').open('a') as out:out.write('\n## 날짜 파생 정정 — 주간 반복 원자료\n\n5,681개 날짜별 객체는 원문이 아니라 학교 전체 학사력으로 계산한 파생 데이터다. 기존 KMOU dated 생성 방식을 재사용했으나, 새 자료의 원문은 요일·교시 주간 표이므로 생산 적용은 `kmou-new-weekly-candidate.json`의 주간 후보를 기준으로 해야 한다. 원본 dated 후보에는 계산 파생·제품 미적용 표기를 추가했다. 특정 강좌별 휴일·보강 날짜 명시 원문은 없으며 전체 학사력 보강은 별도 처리 대상이다. 검증 시 주간 슬롯과 원문 표 좌표를 대조하고, 계산 날짜를 실제 원문 날짜로 보고하면 안 된다.\n')
print(len(b['courses']),r['weeklySlots'])
