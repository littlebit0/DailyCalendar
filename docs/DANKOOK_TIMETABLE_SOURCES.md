# 단국대학교 2026-2 시간표 자료

2026-09-26(한국 시간)에 단국대학교의 공개 학부 강의 조회 화면에서 죽전·천안
캠퍼스의 2026학년도 2학기 자료를 수집했습니다. 대학 계정 로그인이나 개인 수강
내역 조회는 사용하지 않습니다. 자료는 이 날짜의 조회 결과이며 이후 학교의
변경 사항을 자동으로 반영하지 않습니다.

## 공식 조회 화면과 수집 범위

- [죽전 공개 강의 조회](https://webinfo.dankook.ac.kr/tiac/univ/lssn/lpci/views/lssnPopup/tmtbl.do)
- [천안 공개 강의 조회](https://webinfo.dankook.ac.kr/tiac/univ/lssn/lpci/views/lssnPopup/tmtbl2.do)

가져오기 도구는 해당 주소를 GET으로 열어 익명 세션 쿠키를 받은 다음, 동일 주소에
`application/x-www-form-urlencoded` POST를 보냅니다. 공개 화면이 제공하는
전공·교양·학문기초 세 가지 검색을 캠퍼스마다 각각 수행합니다.

| 필드 | 값 |
| --- | --- |
| `yy` | `2026` |
| `semCd` | `2` |
| `qrySxn` | 전공 `1`, 교양 `2`, 학문기초 `3` |
| `lesnPlcCd` | 죽전 `1`, 천안 `2` |
| `colgCd`, `dpmtCd`, `curiCparCd` | 빈 값: 단과대학·학과·이수구분 제한 없음 |
| `mjSubjKnm`, `mjDowCd`, `grade`, `pfltNm` | 빈 값: 과목명·요일·학년·교강사 제한 없음 |

각 요청은 순서대로 보내고 검색 사이에 0.5초 간격을 둡니다. `curl`과 Python
표준 라이브러리만 필요합니다. 익명 쿠키는 도구의 임시 디렉터리에서 사용한 뒤
삭제하며, 앱이나 JSON 자료에 넣지 않습니다.

결과 표 `mjLctTmtblDscTbl`의 공개 표시 건수와 실제 파싱 행 수가 여섯 검색 모두
일치했습니다. 모든 행의 숨은 식별 필드 `yy`, `semCd`, `subjId`, `dvclsNb`를
요청 학기 및 화면의 교과목번호·분반과 대조합니다. 표 열의 종류와 개수도 검사합니다.
따라서 아래 건수는 **두 캠퍼스의 공개 2026-2 학부 전공·교양·학문기초 조회 결과
전체**를 대상으로 합니다. 다른 학기, 대학원 강의, 개인 수강 신청 내역의
완전성을 주장하지 않습니다.

## 수집·병합 건수

| 캠퍼스 | 전공 원본 행 | 교양 원본 행 | 학문기초 원본 행 | 전체 원본 행 | 병합 후 분반 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 죽전 | 4,012 | 1,373 | 515 | 5,900 | 2,722 |
| 천안 | 2,093 | 774 | 384 | 3,251 | 2,562 |
| 합계 | 6,105 | 2,147 | 899 | 9,151 | 5,284 |

| 캠퍼스·기준 | 시간 해석 가능 `scheduled` | 공식 시간 공란 `unscheduled` | 시간 해석 불가 `unrecognized` |
| --- | ---: | ---: | ---: |
| 죽전 원본 행 | 5,435 | 465 | 0 |
| 죽전 병합 분반 | 2,565 | 157 | 0 |
| 천안 원본 행 | 3,229 | 22 | 0 |
| 천안 병합 분반 | 2,540 | 22 | 0 |
| 원본 행 합계 | 8,664 | 487 | 0 |
| 병합 분반 합계 | 5,105 | 179 | 0 |

공식 시간 공란인 179분반도 검색 목록에 보존합니다. 시간이 없는 강의를 임의로
시간표에 배치하지 않으며, 화면에서 학교 확인 후 직접 추가하도록 안내합니다.
나중에 알 수 없는 시간 표기가 생겨도 원문을 `sourceSchedule`에 남기고
`unrecognized`로 구분합니다. 시간 공란과 해석 실패를 동일한 상태로 숨기지 않습니다.

같은 캠퍼스·학기·교과목번호·분반을 여러 학과나 검색에서 찾은 경우
`dku/{campus}/{year}/{semester}/{courseCode}/{section}`으로 병합합니다.
제목·교수·학점·원본 시간·해석한 시간이 충돌하면 가져오기를 중단합니다.
현재 9,151행에는 이 병합 조건의 충돌이 없었습니다. 학과별 이수구분·학점·비고는
모두 보존하며, 공식 이수구분이 빈 죽전 7행에는 값을 추측해 넣지 않습니다.

`수업방법 및 비고`의 줄바꿈과 함께 원어강의 여부·변경내역·수업유형·주수강조직의
공개 값도 비고에 남깁니다. 강의계획서 버튼이나 교직원 내부 식별자는 가져오지
않습니다. 강의 방식은 사용자가 선택하며, 이수구분이나 비고로 단정하지 않습니다.

## 교시와 실제 시간

조회 결과의 숫자 교시는 다음 공식 안내 자료와 대조했습니다.

- [학사종합안내 죽전](https://www.dankook.ac.kr/web/kor/학사종합안내-죽전-)의
  [2026-2학기 종합강의시간표 안내자료 PDF](https://www.dankook.ac.kr/documents/20118/523334/2026-2학기%20종합강의시간표%20안내자료(죽전)_0805.pdf/01393e68-46a9-f866-4e54-7feba0f6e312?version=1.0):
  PDF 153쪽, 인쇄 181쪽.
- [학사종합안내 천안](https://www.dankook.ac.kr/web/kor/학사종합안내-천안-)의
  [2026학년도 학사종합안내 PDF, version 13](https://www.dankook.ac.kr/documents/20118/12232463/2026학년도%201학기%20종합강의시간표_업로드용260119.pdf/0ecd0cf2-f64b-5986-a0c2-d01235678d4b?version=13.0):
  PDF 138쪽, 인쇄 4쪽. 주소의 파일명에 `1학기`가 남아 있지만, 수집일에 공식
  학사종합안내 화면이 연결한 버전 13의 본문 표를 확인했습니다.

두 캠퍼스의 1~18교시는 09:00부터 30분 간격입니다. 야간 교시는 아래와 같습니다.

| 교시 | 원본 시작–종료 |
| --- | --- |
| 19 | 18:00–18:50 |
| 20 | 18:55–19:45 |
| 21 | 19:50–20:40 |
| 22 | 20:45–21:35 |
| 23 | 21:40–22:30 |
| 24 | 22:35–23:25 |

같은 요일·강의실의 연속 교시는 하나의 수업으로 합치고, 떨어진 교시는 나눕니다.
공식 시작·종료 분은 JSON에 그대로 보존합니다. 앱 공통 시간표 표시 규칙이 시작을
이전 00/30분, 종료를 다음 00/30분으로 맞추므로 원본 분과 화면 경계는 구분됩니다.
강의실이 공란이면 방 번호를 만들어 넣지 않습니다.

## 날짜와 파일 메타데이터

공개 검색 결과에는 강의 목록의 발행일이 따로 없으므로 **2026-09-26은 수집일**입니다.
JSON의 `retrievedDate`와 기존 화면의 자료 기준일용 `publishedDate`에 같은 날짜를
기록하고, `dateBasis`를 `public catalogue retrieved date`로 명시합니다.
`publishedDate`라는 필드명을 학교의 실제 발행일로 해석하면 안 됩니다.

각 JSON에는 `sourceUrl`, `sourceGroupCounts`, `sourceRowCount`,
`sourceScheduleStatusCounts`, `courseScheduleStatusCounts`, `periodSourceUrl`,
`periodSourcePage`, 그룹별 원본 HTML SHA-256인 `sourceHashes`가 있습니다.
익명 세션에 따라 HTML 일부가 달라질 수 있으므로 새 조회의 해시가 이전 수집본과
같다는 전제는 두지 않습니다. 원본 HTML과 쿠키는 버전 관리하지 않습니다.

## 다시 수집하거나 보관한 원본에서 복원하기

```sh
python3 tool/timetable/import_dankook.py \
  --campus jukjeon --year 2026 --semester 2 \
  --source-dir work/university-expansion --download \
  --fetched-date 2026-09-26 \
  --output assets/timetable/dku-jukjeon-2026-2.json

python3 tool/timetable/import_dankook.py \
  --campus cheonan --year 2026 --semester 2 \
  --source-dir work/university-expansion --download \
  --fetched-date 2026-09-26 \
  --output assets/timetable/dku-cheonan-2026-2.json
```

새 조회에는 실제 수집일로 `--fetched-date`를 바꿉니다. 같은 수집본을 복원하려면
`work/university-expansion/dku-{campus}-{major|general|basic}.html` 여섯 파일을
준비하고 **위 명령에서 `--download`를 빼고 원래 수집일을 유지**합니다.
가져오기 도구는 `catalog.json`을 자동으로 바꾸지 않습니다. 현재 매니페스트에는
위 두 JSON이 등록되어 있습니다. 다음 학기에는 공개 조회의 열·교시 안내·검색 종류를
다시 확인하고 갱신해야 합니다.

## 검증 기록

2026-09-26 다음 검증을 통과했습니다.

```sh
python3 -m unittest tool/tests/test_dankook_import.py
bash tool/flutter.sh test --no-pub test/features/timetable/dankook_catalog_data_test.dart
```

- Python **6개**: 주간·야간 교시, 떨어진 교시와 잘못된 표기, 열·행 수·학기 식별자,
  공동 개설 병합·비고, 시간 공란·해석 실패, 충돌하는 메타데이터 거부.
- Dart **2개**: 두 캠퍼스의 전체 5,284분반을 각각 읽어 대학·캠퍼스·식별자·건수,
  학과별 분류·학점·비고, 원본 시간과 30분 표시 경계, 유효한 시간표 변환과 JSON
  재로딩, 시간 공란 과목의 검색 가능 여부를 검사.

이 기록은 자료 변환과 Flutter 모델 검증이며, 실제 계정의 Drive 동기화나
설치한 앱의 실행 검증을 대신하지 않습니다.
