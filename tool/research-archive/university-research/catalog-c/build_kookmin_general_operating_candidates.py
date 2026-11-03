# coding: utf-8
"""Manually audited public weekly rows; incomplete courses stay unresolved."""
import json,datetime
from pathlib import Path
P=Path(__file__).resolve().parent
plans=json.loads((P/'kookmin-current-weekly-operating-rows.json').read_text())
keys={r['code'] for r in json.loads((P/'kookmin-general-exception-operating-phrases.json').read_text())}
raw=json.loads((P/'kookmin-current-college-scope.json').read_text())['records']
# Explicit source words, reviewed row by row; no keyword-only delivery inference.
ASYNC={'1651901-01':['2026-09-15','2026-09-17','2026-10-01','2026-10-08','2026-10-15','2026-10-27'],'0007004-01':['2026-09-29'],'1667001-01':['2026-09-23','2026-09-30','2026-10-28','2026-11-04'],'1659202-51':['2026-09-02','2026-09-16','2026-09-30','2026-10-21'],'0752805-01':['2026-09-14','2026-09-28','2026-10-12','2026-11-02','2026-11-16','2026-12-07'],'003000N-02':['2026-09-11','2026-09-25','2026-10-09','2026-10-30','2026-11-13','2026-11-27']}
LIVE={'0007004-01':['2026-10-06','2026-10-13','2026-11-10','2026-11-17'],'0807700-01':['2026-10-13'],'0160508-51':['2026-09-15','2026-09-22','2026-09-29','2026-10-06','2026-11-03','2026-11-10','2026-11-17','2026-11-24'],'1651201-01':['2026-10-01','2026-11-05','2026-11-12','2026-11-19']}
UNRESOLVED={'1652001-01':([], '현재 혼합수업(대면+비대면) 표시지만 구체적 주차별 방식 미게시'),'0007004-01':(['2026-12-08'],'15주 현장교사 특강 일자 변동 가능 명시'),'0807700-01':(['2026-09-29','2026-10-06','2026-11-10','2026-11-17'],'비대면 강의의 녹화/실시간 구분 미게시'),'1237801-01':(['2026-11-05'],'온라인 특강의 녹화/실시간 구분 미게시'),'0160508-51':(['2026-10-20','2026-12-08'],'중간/기말고사 일시 추후공지 명시'),'1659202-51':([], '실제18:30시작과 API18:00~20:40 대조; 실제 종료시각 별도 확정 문장 없음. 비대면 예정표와10/28합반행 충돌,9/23녹화/실시간 미구분'),'0045106-01':([], '대면/비대면 혼합이며 비고 참조라고 명시하지만 현재 주차 비고에서 구분 미게시'),'0578604-01':([], '온라인 동영상+현장 질의응답 혼합이라고 명시하지만 주차별 구분 미게시'),'0578604-02':([], '온라인 동영상+현장 질의응답 혼합이라고 명시하지만 주차별 구분 미게시'),'0752805-01':(['2026-11-23'],'12주 Zoom100분+실습50분의 정확 시작/종료 및 휴식 배치 미게시; API14~17로 Zoom3시간 생성 금지'),'1395500-01':(['2026-09-03'],'온라인 예정의 녹화/실시간 구분 미게시'),'1645001-01':(['2026-12-14'],'15주 월요일 보충학습은 비대면으로만 명시; KMOOC/녹화/실시간 구분 미게시'),'1646602-01':(['2026-09-14','2026-09-21','2026-10-12','2026-10-19','2026-11-16','2026-11-23'],'비대면 강의의 녹화/실시간 구분 미게시')}
DAYS={'MONDAY':1,'TUESDAY':2,'WEDNESDAY':3,'THURSDAY':4,'FRIDAY':5,'SATURDAY':6,'SUNDAY':7}
out=[]
for plan in plans:
 code=plan['subjectId']+'-'+plan['section']
 if code not in keys:continue
 row=next(r for r in raw if r['subjectId']==plan['subjectId'] and r['classSequence']==plan['section'])
 unresolvedDates,reason=UNRESOLVED.get(code,([],None))
 meetings=[];excluded=[];unresolved=[]
 for w in plan['weeklyRows']:
  assert len(w['dates'])==1
  d=w['dates'][0];day=datetime.date.fromisoformat(d).isoweekday();phrases=[x for x in w['publicCells'][3:] if len(x.strip())>2]
  asyncRow=d in ASYNC.get(code,[]) or (code=='1645001-01' and day==1 and d!='2026-12-14')
  if asyncRow:excluded.append({'date':d,'officialWeek':w['week'],'reason':'source explicitly recorded/video/KMOOC/asynchronous assignment; not no-class','sourcePhrases':phrases});continue
  if reason and (not unresolvedDates or d in unresolvedDates):unresolved.append({'date':d,'officialWeek':w['week'],'reason':reason,'sourcePhrases':phrases});continue
  slots=[z for z in row['schedule']['lectureTimes'] if DAYS[z['dayOfWeek']]==day];assert slots
  live=d in LIVE.get(code,[]);merged=[]
  for z in slots:
   start=z['start']['hour']*60+z['start']['minute'];end=z['end']['hour']*60+z['end']['minute'];room=z.get('classRoomName') or ''
   if merged and merged[-1]['endMinute']==start and merged[-1]['catalogRoom']==room:merged[-1]['endMinute']=end
   else:merged.append({'date':d,'weekday':day,'startMinute':start,'endMinute':end,'room':'' if live else room,'catalogRoom':room,'deliveryMode':'liveOnline' if live else 'onsite','officialWeek':w['week'],'sourcePhrases':phrases})
  meetings+=merged
 out.append({'courseKey':row['id'],'subjectId':row['subjectId'],'section':row['classSequence'],'title':row['subjectNm'],'allAttendanceWeeksVerified':not unresolved,'dateMeetings':meetings,'noTimedMeetingDates':excluded,'unresolvedMeetings':unresolved,'unresolvedReason':reason,'weeklyRecurrenceAllowed':False,'evidence':'kookmin-current-weekly-operating-rows.json','operationPolicy':'manual row review plus actual catalog clock; any unresolved date means entire course unrecognized','completionClaim':False})
assert len(out)==17
(P/'kookmin-general-operating-meeting-candidates.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
print([(x['subjectId']+'-'+x['section'],len(x['dateMeetings']),len(x['noTimedMeetingDates']),len(x['unresolvedMeetings']),x['allAttendanceWeeksVerified']) for x in out])
