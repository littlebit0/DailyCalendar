# -*- coding: utf-8 -*-
from pathlib import Path
import json
root=Path.cwd();p=Path(__file__).parent
install=json.loads((p/'install-receipt.json').read_text());assert install['signaturesVerified'] and not install['appLaunched']
live=json.loads((p/'live-calendar-final.json').read_text());by={x['source']:x for x in live};assert len(by)==17 and all(x['status']=='passed' for x in live)
receipt=json.loads((p/'integration-receipt.json').read_text());targets=json.loads((p/'targets.json').read_text())
notes={
'inje':'김해 글로벌경영학부 16개만 확보; 부산·타 학과 미확보',
'wsu':'소프트웨어학과 19개만 확보; 전체 학과 미확보',
'eulji':'성남 60개·의정부 7개 교류 공개 자료; 대전·전체 학과 미확보',
'iccu':'송도 간호·교양 69개; 강화·전체 학과 미확보',
'hongik':'서울·세종 공개 조회 및 110개 분반별 계획서 확인; 폐강 2개 제외, 집중이수 4개 분반만 실제 날짜 적용',
'hansei':'공식 Guest 전체 10개 학부 685개; 665개 시간 확정, 온라인·집중이수·현장실습 20개는 시간 미배정 유지',
'kangnam':'원문 1,983개 고유 과목·분반 중 1,416개 시간 확정; 567개 비대면·미배정·불명확·충돌 보류',
'nambu':'주간 시간 확정 609개; 야간 교시·온라인·미배정 162개 보류',
'pcu':'시간 확정 1,486개; 시간 미배정 등 437개 보류',
'ewha':'공식 학부별 조회 2,573개; 589개 시간 미배정 유지',
'hyupsung':'2026년 1·2학기 공식 자료; 학기별 집계',
'sungkyul':'2026년 1·2학기 공식 자료; 학기별 집계',
'sangji':'2026년 2학기 공식 자료; 폐강 38개 제외, 미배정 유지',
'kentech':'공식 교육편람은 교육과정·과목코드만 제공; 개설강좌의 요일·시각·강의실 미확보',
'sunmoon':'공식 개설강좌 조회에 학생 로그인 필요; 공개 수강안내에는 실제 시간표 없음',
'konyang':'SmartKY 강좌개설조회에 학생 로그인 필요; 공개 TERM 이미지에 시각·과목코드 등 부족',
'dju':'공식 수강편람은 학생 포털 조회를 안내; 공개 편람에 실제 개설 시간표 없음'}
statusfile=root/'docs/UNIVERSITY_SUPPORT_STATUS_2026-10-06.json';status=json.loads(statusfile.read_text());table=[]
for t in targets['requested']:
 key=t['sourceId'];assets=[x for x in receipt['assets'] if x['university']==key];courses=sum(x['courses'] for x in assets);scheduled=0
 for e in assets:
  d=json.loads((root/e['asset']).read_text());scheduled+=sum(bool(x['schedules']) for x in d['courses'])
 t['academic']='implemented_live_verified';t['timetable']='implemented_partial_catalog' if assets else 'held_actual_offering_clocks_not_acquired';t['coverageNote']=notes[key]
 record={'requestedName':t['name'],'name':t['name'],'institutionIds':[t['institutionId']],'academicCalendar':{'status':'implemented_live_verified',
'sourceId':key,'sourceUrl':by[key]['snapshot'][0]['url'],'events2026':by[key]['events'],'checkedAt':'2026-10-12'},'timetable':{'status':t['timetable'],'checkedAt':'2026-10-12',
'universityId':key,'courses':courses,'scheduled':scheduled,'datasets':[e['asset'] for e in assets],'coverageNote':notes[key],'wholeUniversityCompletionClaim':False},'sourceEvidence':'work/university-research/expansion17-20261011/'}
 existing=next((i for i,x in enumerate(status['universities']) if t['institutionId'] in x.get('institutionIds',[])),None)
 if existing is None:status['universities'].append(record)
 else:status['universities'][existing]=record
 table.append(f"| {t['name']} | {by[key]['events']}개 | {str(courses)+'개' if assets else '미연결'} | {notes[key]} |")
status['checkedAt']='2026-10-12';status['requestedUniversities']=len(status['universities']);status['completionClaim']=False;status['latestPassEvidence']='work/university-research/expansion17-20261011/verification-receipt.json';statusfile.write_text(json.dumps(status,ensure_ascii=False,indent=2)+'\n')
targets['secondStageStatus']={'processed':True,'newEligibleDatasets':0,'remaining':targets['secondStage'],'reasons':{'동의대학교':'새 폐강 명단으로 기존 후보12개 폐강 확인. 남은531개는 개설 보증이 아니며 현재 절대 교시 시각 미확정.',
'서울교육대학교':'2026-07-30 공식 학사운영 규정은 교시 묶음만 제공; 실제 HH:mm 미확보.',
'진주교육대학교':'공식 조회·시설예약이 로그인 화면으로 연결되어 실제 개설 강좌와 시각 미확보. 청주교대와 구분.',
'춘천교육대학교':'2026-03-25 공식 규정은 50분 단위만 명시. 2021년 이미지의 일부 교시를 2026년 전체 시각으로 추정하지 않음.'},'evidence':['c/deu/HANDOFF.md',
'c/education-clocks/HANDOFF.md']};(p/'targets.json').write_text(json.dumps(targets,ensure_ascii=False,indent=2)+'\n')
report='''# 추가 17개 대학 처리 결과 — 2026-10-12

요청한 17개 대학의 학사일정 연결과 실제 2026년 서버 조회 검증을 완료했다. 시간표는 원자료와 실제 시각을 확보한 13개 대학의 17개 캠퍼스·학기 자료 묶음, 16,052개 강좌를 기존 상명대·단국대·전남대 모델과 화면에 반영했다. **대학 전체 지원 완료가 아니다.** 일부 학교는 특정 학과·교류 자료만 공개되어 누락 범위가 남아 있다. 미확인 시간·강의실·날짜는 추정하지 않았다.

| 대학 | 실제 조회 학사일정 | 반영 시간표(학기별 집계) | 범위와 남은 문제 |
|---|---:|---:|---|
'''+ '\n'.join(table)+'''

## 시간표 미연결 8개 대학

- 신규: 한국에너지공과대·선문대·건양대·대전대. 실제 개설 요일·시각 자료를 확보하지 못했으며 선문·건양·대전의 공식 조회는 학생 로그인이 필요하다.
- 재조사: 동의대·서울교대·진주교대·춘천교대. 현재 적용 가능한 정확한 교시 시각 또는 실제 개설 자료를 확보하지 못했다. 최신 공식 공지·규정을 다시 확인한 근거는 `c/deu/HANDOFF.md`, `c/education-clocks/HANDOFF.md`에 있다.
- 지원 불가능으로 확정한 대학은 없다. 인증 또는 원자료가 필요하다는 것과 지원 불가능은 구분한다.

## 검증과 설치

전체 처리 후 통합 검증 1회. 실패 수정 후 변경 범위만 재검증했으며, 통과한 전체 검사를 반복하지 않았다. 학사일정 17개 실제 조회, 변경 범위 정적 검사, 기존 시간표 UI·캠퍼스 선택·학기 경계·원래 시각·저장 모델 검사에서 남은 실패 없음. 마지막 통신 종료 처리 검토 후 해당 검사와 Mac 산출물만 재생성했다. 기존 시간표 146개 파일은 처리 전과 바이트 단위로 동일하다.

을지대 공식 서버의 규격 위반 `Referrer Policy` 헤더에만 전용 호환 처리를 적용했다. 정상 TLS 인증서 검증, 공식 달력 주소 제한, 전체 25초·본문 8MB·헤더 64KB 상한, 기타 헤더·본문 프레이밍 검증은 유지한다. 첫 규격 위반 이후 해당 조회의 남은 월만 호환 경로로 진행한다. 로그인·쿠키를 수집하지 않는다.

Mac Debug 빌드 성공 후 `~/Applications/Daily Test.app`에 업데이트했다. 3.6.0, `com.littlebit0.daily.test`, 서명 팀·보안 저장소 권한을 유지했다. 학사·시간표 JSON 및 로고의 소스/빌드/설치 해시와 엄격 서명을 확인했다. 생성된 중복 앱은 제거했다. 앱 실행·재로그인·실제 사용 검증은 하지 않았으며, 다른 플랫폼 빌드·기기·다중 기기 검증과 배포·커밋·푸시는 수행하지 않았다.

근거: `verification-receipt.json`, `live-calendar-final.json`, `integration-receipt.json`, `existing-datasets-preserved.json`, `install-receipt.json`. 현재 설치는 그 영수증이 가리키는 상태이며, 과거 checkpoint 숫자로 판단하지 않는다.
'''
(p/'REPORT.md').write_text(report)
memory=root/'AGENT_MEMORY.md';s=memory.read_text();a=s.index('## Additional 17 universities');b=s.index('## University expansion — resumed',a)
section='''## Additional 17 universities — Mac updated 2026-10-12

- Approved scope: 17 requested academic calendar/timetable integrations, then DEU/SNUE/CUE/CNUE timetable re-investigation. All17 academic sources implemented and real2026 fetch passed.13 universities/17 campus-semester datasets/16,052 courses integrated in existing SMU/DKU/JNU model/UI; partial/department/untimed scope remains. No whole-university completion claim. Evidence and per-school table: `work/university-research/expansion17-20261011/REPORT.md`; current status inventory `docs/UNIVERSITY_SUPPORT_STATUS_2026-10-06.json`.
- Hansei authorized publicGuest CAPTCHA completed; all10faculty685rows collected,665timed/20online-intensive-field-placement untimed. Official individualplan directly proves8period16:00; generichelp typo16:30 notused. Hongik ambiguous102offerings adjudicated by individualplan hours; four intensive sections retain actual dates using existing schema2. Never enroll or extract credentials/cookies. Research-only browser/server stopped.
- Remaining newTT unconnected: KENTECH/SUNMOON/KONYANG/DJU. InjeGimhae globalmanagement16, WSUsoftware19, EuljiSeongnam60/Uijeongbu7exchange, ICCUSongdo69 are explicit subsets; InjeBusan/EuljiDaejeon/ICCUGanghwa TTremainnull. Re-investigated DEU/SNUE/CUE/CNUE with latest source evidence; no new eligible datasets. No university proven impossible. Current failed-source/coverage details `targets.json` and a/b/c handoff, not invented completion.
- Whole pass implemented before combined verification; initial failures fixed then narrow checks only. Actual17live calendars and changed-scope analyzers passed; original146timetable datasets byte-identical. Eulji malformed Referrer Policy response header handled only at fixed officialcalendar URI with normal TLS/strict otherheaders/25s/8MB/64KB limits; sourceIO and standardinstalled http_parser codec, no permissive global policy. Final transport cleanup review closes lateconnected socket after timeout, only its7checks and affectedMac artifact rebuilt.
- MacDebug build and canonical ~/Applications/Daily Test.app in-place update verified, version3.6.0/bundle/team/keychainentitlements unchanged. AllJSON/logo source-built-installed hashes/strictsignatures verified; backup /private/tmp/daily-test-before-expansion17-20261012.tar.gz. Generated duplicate removed. No launch/production/data/account/keychain changes, no otherplatformbuild/deviceUI/multidevice acceptance, noLMS/release/commit/push. Verification/install receipts in currentworkfolder.
- integrate.py and profile_integration.py already executed ONCE: do not rerun or overwrite before/baseline snapshots. Next work requires new actualoffering/nativeclock evidence or authorized authenticated access for held universities, plus per-school partialcoverage expansion. Do not replay frozen149/152 projection or already-passed fullchecks.

'''
memory.write_text(s[:a]+section+s[b:])
canon=root/'docs/UNIVERSITY_EXPANSION_PAUSED_2026-10-09.md';s=canon.read_text();s=s.replace('# University expansion handoff — resumed 2026-10-11',
'# University expansion handoff — updated 2026-10-12',1);s=s.replace('## Current remaining-source processing and Mac update',
'''## Current additional17 pass and Mac update — 2026-10-12

17 academic calendar sources passed actual2026 fetch;13 new timetable integrations contain17 campus-semester datasets/16,052 courses, with explicit partial coverage. Canonical test app updated in place, no launch. Remaining timetable integrations: KENTECH/SUNMOON/KONYANG/DJU and DEU/SNUE/CUE/CNUE; none proven impossible. Read [the current per-school report](../work/university-research/expansion17-20261011/REPORT.md) and verification/install receipts. Shared code applies to all affected platforms; only Mac build/install verified. Do not rerun one-shot integration scripts. The earlier pass below remains historical evidence.

## Previous remaining-source processing and Mac update''',1);canon.write_text(s)
print('Updated current report, status inventory and consolidated handoff')
