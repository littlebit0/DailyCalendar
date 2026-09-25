# 대학별 시간표 적용 기간 근거

확인일: 2026-09-25. 데이터: [`assets/timetable/term-periods.json`](../assets/timetable/term-periods.json).

상명대학교 [중앙 학부 학사일정](https://www.smu.ac.kr/kor/life/academicCalendar.do)의 공개 일정 데이터를 확인했다. [천안 공과대학 학사일정](https://ceng.smu.ac.kr/ceng/admission/calendar.do?mode=list)도 같은 중앙 학사일정 게시판(`bachelorNo=85`)을 사용한다. 아래 기간은 서울·천안 캠퍼스에 공통으로 적용되는 학부 일정이다.

## 적용 범위

시작일과 종료일은 모두 포함한다. 정규학기는 개강일부터 자율보강(기말고사) 주간 마지막 날까지로 정하고, 그다음 날 시작되는 방학은 제외한다. 성적 입력·확인 기간이나 행정상 학기 구분을 수업 기간으로 사용하지 않는다. 계절학기는 별도 기간이며 겨울 계절학기의 연도는 개강한 학년도다.

| 학년도·학기 | 시작일 | 종료일 | 공식 일정 근거 |
| --- | --- | --- | --- |
| 2026년 1학기 | 2026-03-03 | 2026-06-22 | [개강](https://www.smu.ac.kr/kor/life/academicCalendar.do?mode=view&articleNo=762385&boardNo=85), [기말고사 6/9–15](https://www.smu.ac.kr/kor/life/academicCalendar.do?mode=view&articleNo=762391&boardNo=85), [자율보강 6/16–22](https://www.smu.ac.kr/kor/life/academicCalendar.do?mode=view&articleNo=762392&boardNo=85), [하계방학 시작 6/23](https://www.smu.ac.kr/kor/life/academicCalendar.do?mode=view&articleNo=762396&boardNo=85) |
| 2026년 여름 | 2026-06-23 | 2026-07-08 | [하계 계절수업](https://www.smu.ac.kr/kor/life/academicCalendar.do?mode=view&articleNo=762397&boardNo=85) |
| 2026년 2학기 | 2026-09-01 | 2026-12-21 | [개강](https://www.smu.ac.kr/kor/life/academicCalendar.do?mode=view&articleNo=765597&boardNo=85), [기말고사 12/8–14](https://www.smu.ac.kr/kor/life/academicCalendar.do?mode=view&articleNo=766725&boardNo=85), [자율보강 12/15–21](https://www.smu.ac.kr/kor/life/academicCalendar.do?mode=view&articleNo=766727&boardNo=85), [동계방학 시작 12/22](https://www.smu.ac.kr/kor/life/academicCalendar.do?mode=view&articleNo=766729&boardNo=85) |
| 2026년 겨울 | 2026-12-22 | 2027-01-08 | [동계 계절수업](https://www.smu.ac.kr/kor/life/academicCalendar.do?mode=view&articleNo=766730&boardNo=85) |

이 기간은 주·일간 스케줄에 시간표를 적용할 수 있는 날짜 범위다. 범위 안의 모든 공휴일·시험일·보강일에 개별 강의가 진행된다는 뜻은 아니다. 수업별 실제 변경에는 날짜별 휴강·수업 방식 변경을 사용한다.

공식 기간이 확인되지 않은 연도·학기는 날짜를 추정하지 않는다. 사용자가 적용 기간을 지정하기 전에는 주·일간 스케줄에 수업을 반복 표시하지 않는다.

## 검증 방법

공식 학사일정 화면이 사용하는 [`app.bachelor_calendar.calendar.js`](https://www.smu.ac.kr/_custom/smu/resource/js/app/app.bachelor_calendar.calendar.js)의 공개 조회 요청을 재현했다.

```text
POST https://www.smu.ac.kr/app/common/selectDataList.do
Content-Type: application/x-www-form-urlencoded

sqlId=jw.Article.selectCalendarArticle
modelNm=list
jsonStr={"year":"2026","month":"9","bachelorBoardNoList":["85"]}
```

응답 `list`에서 `articleNo`, `articleTitle`, `etcChar6`(시작일), `etcChar7`(종료일)을 확인했다. 상세 게시물의 작성일과 일정의 실제 시행일은 다르므로, 기간은 해당 일정 필드를 기준으로 한다. 공식 일정이 변경되면 원문을 다시 확인한 뒤 데이터와 확인일을 함께 갱신한다.

## 단국대학교·전남대학교 추가 기간 (2026-09-26)

[단국대학교 공식 학사일정](https://www.dankook.ac.kr/web/kor/-2014-)과
[전남대학교 공식 학부 학사일정](https://events.jnu.ac.kr/Schedule.aspx?mode=1&YY=2026)의
공개 응답에서 다음 8개 기간을 확인했다. 단국대는 죽전·천안, 전남대는
광주·여수 캠퍼스를 동일 대학의 학부 일정으로 처리한다.

| 대학·학년도·학기 | 시작일 | 종료일(포함) | 응답의 정확한 일정 제목 |
| --- | --- | --- | --- |
| 단국대 2026년 1학기 | 2026-03-03 | 2026-06-19 | `2026학년도 1학기 개강`, `2026학년도 1학기 종강`, `2026학년도 1학기 공휴일 지정순연일` |
| 단국대 2026년 여름 | 2026-06-23 | 2026-07-13 | `2026학년도 계절(하계)학기 수업기간` |
| 단국대 2026년 2학기 | 2026-09-01 | 2026-12-21 | `2026학년도 2학기 개강`, `2026학년도 2학기 종강`, `2026학년도 2학기 공휴일 지정순연일` |
| 단국대 2026년 겨울 | 2026-12-23 | 2027-01-14 | `2026학년도 계절(동계)학기 수업기간` |
| 전남대 2026년 1학기 | 2026-03-03 | 2026-06-23 | `제1학기 개강`, `제1학기 종강` |
| 전남대 2026년 여름 | 2026-06-29 | 2026-07-23 | `하계 계절학기` |
| 전남대 2026년 2학기 | 2026-09-01 | 2026-12-21 | `제2학기 개강`, `제2학기 종강` |
| 전남대 2026년 겨울 | 2026-12-28 | 2027-01-22 | `동계 계절학기` |

단국대의 명목상 종강일은 1학기 6월 15일, 2학기 12월 14일이다.
각각 이어지는 공휴일 지정순연일 6월 16–19일과 12월 15–21일까지
수업 적용 기간에 포함한다. 성적 입력·공시 기간은 종료일 근거로 쓰지 않는다.
기본 기간 안에서도 개별 강의의 휴강·보강 여부는 별도 강의 설정에 따른다.

공개 요청은 로그인, 쿠키, Authorization 헤더 없이 이루어진다.

```text
GET https://www.dankook.ac.kr/o/dku_calendar-rest/calendar/events/0/1767193200000/1798729199999
GET https://events.jnu.ac.kr/Schedule.aspx?mode=1&YY=2026
```

단국대의 조회 범위는 한국 시간 2026-01-01 00:00:00부터
2026-12-31 23:59:59.999까지의 밀리초다. `startTime` / `endTime`을 UTC+09:00
달력 날짜로 해석하므로 기기의 시간대에 따라 하루가 바뀌지 않는다.
전남대는 지정된 학부 일정 표의 두 날짜를 읽는다. 원문 종료일은 포함 날짜이며,
학사일정 이벤트의 내부 종료일은 그 다음 날(배타적)로 변환한다.
2026년 겨울 수업은 원문의 2027년 종료일까지 유지한다.

고정 검증 자료:

| Fixture | 원본 행 수 | SHA-256 |
| --- | --- | --- |
| `test/fixtures/academic/dku-2026.json` | 125 | `e863fa2c6ed538e021f3b0f40ed1bd81d3027d13e413d10e35e9ab52b8527137` |
| `test/fixtures/academic/jnu-2026.html` | 57 (입학식 중복 제거 후 56) | `2edd402ea7c063af4a941ae3b0bdab1ca20bf5cb3a53b29260d9dd4ef4846b7a` |

`additional_academic_sources_test.dart`는 각 기간의 `sourceTitles`를 위
fixture의 실제 항목과 일치시키고, 해당 항목의 최소 시작일과 최대 종료일이
기본 기간에 정확히 대응하는지 검사한다. 날짜 범위 바깥 하루, 확인되지 않은
학년도, 잘못된 날짜/역전 구간/응답 형식, 실패·과대 HTTP 응답도 확인한다.
두 공개 소스에는 영속적인 일정 ID가 없어 제목·시작 연도·동일 제목 발생 순서로
가져온 일정의 ID를 구성한다. 동일 제목의 별도 일정이 추가·삭제되거나 순서가
바뀌면 발생 순서 ID의 한계가 있으므로, 이를 서버가 제공한 영속 ID로 설명하지 않는다.

## Dankook and Chonnam additions, checked 2026-09-26

The existing SMU keys remain backward compatible. Additional universities live
in `term-periods.json.additionalUniversities` and are selected by university ID.
Unknown university/year/semester combinations return no default; they never fall
back to another university's dates. Explicitly edited/stored semester periods
remain under the timetable store's existing preservation rules.

- Dankook: [official calendar](https://www.dankook.ac.kr/web/kor/-2014-), public
  calendar JSON endpoint documented in `ACADEMIC_SOURCE_ADAPTERS.md`. The 2026
  spring period is March 3–June 19 including the published June 16–19 makeup
  period; fall is September 1–December 21 including December 15–21 makeup.
  Published summer teaching is June 23–July 13; winter December 23–January 14.
- Chonnam: [official 2026 undergraduate calendar](https://events.jnu.ac.kr/Schedule.aspx?mode=1&YY=2026).
  Spring March 3–June 23; fall September 1–December 21; summer June 29–July 23;
  winter December 28–January 22. Dates are inclusive in the timetable defaults.

Each added period records the exact official source title(s), URL and check
date. No generic month estimate is used for unpublished years.
