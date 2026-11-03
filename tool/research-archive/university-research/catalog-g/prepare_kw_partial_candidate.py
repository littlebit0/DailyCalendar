"""Source-grounded ordinary subset; preserve whole educational search scope."""
from pathlib import Path
from datetime import date, timedelta
from collections import Counter
import hashlib
import json
import re

ROOT = Path(__file__).parent
HOLIDAYS = {"2026-09-24", "2026-09-25", "2026-09-26", "2026-10-03", "2026-10-05", "2026-10-09"}
CLOCKS = {
    1: (540, 615), 2: (630, 705), 3: (720, 795),
    4: (810, 885), 5: (900, 975), 6: (990, 1065),
    7: (1080, 1125), 8: (1130, 1175), 9: (1180, 1225),
    10: (1230, 1275), 11: (1280, 1325),
}
DAY = dict(zip("월화수목금토일", range(1, 8)))
REMARK = '33:비고(1학년은 "신입생 및 1학년 분반" 정보 참고하여 수강)'


def main():
    rows = json.loads((ROOT / "kw-all-2026-2.json").read_text())["records"]
    reviews = {r["sourceId"]: r for r in json.loads(
        (ROOT / "kw-current-operating-review-20261008.json").read_text()
    )["records"]}
    courses = []
    clocks = []
    metadata_mismatches = []
    for row in rows:
        identity = row["6:학정번호"]
        assert re.fullmatch(r"[A-Za-z0-9]{4}-\d-\d{4}-\d{2}", identity)
        # The published official timetable page explicitly defines all four
        # components, including the final section number. Retain its full text.
        code, section = identity.rsplit("-", 1)
        review = reviews[identity]
        eligible = review["clockReviewProfile"] == "ordinary-clock-chart-source-hour-fit"
        blocks = []
        for index in (24, 27, 30):
            weekday = row[f"{index}:요일{(index - 24) // 3 + 1}"]
            periods = row[f"{index + 1}:None"]
            room = row[f"{index + 2}:None"] or ""
            if weekday is None and periods is None:
                continue
            if weekday not in DAY or periods is None:
                eligible = False
                continue
            tokens = str(periods).split(",")
            if not all(t.strip().isdigit() and int(t) in CLOCKS for t in tokens):
                eligible = False
                continue
            # Keep each published period separately: neither break durations
            # nor an unproven continuous laboratory rule is created here.
            for token in tokens:
                start, end = CLOCKS[int(token)]
                blocks.append({"weekday": DAY[weekday], "startMinute": start,
                               "endMinute": end, "classroom": room})
        if not blocks:
            eligible = False
        schedules = []
        if eligible:
            current = date(2026, 9, 1)
            while current <= date(2026, 12, 14):
                if current.isoformat() not in HOLIDAYS and current.isoweekday() != 7:
                    for block in blocks:
                        if block["weekday"] == current.isoweekday():
                            schedules.append(dict(block, date=current.isoformat()))
                current += timedelta(days=1)
        department = row["3:개설학과"]
        classification = row["17:이수구분"]
        remark = row[REMARK] or ""
        published_notes = [remark]
        if row["16:신입생 및 1학년 분반"]:
            published_notes.append("신입생 및 1학년 분반: " + str(row["16:신입생 및 1학년 분반"]))
        source_schedule = "; ".join(
            f"{row[f'{i}:요일{(i - 24) // 3 + 1}']} {row[f'{i + 1}:None']} [{row[f'{i + 2}:None'] or ''}]"
            for i in (24, 27, 30) if row[f"{i + 1}:None"] is not None
        )
        course = {
            "sourceId": f"kwangwoon/unknown/2026/2/{identity}",
            "sourceAcademicNumber": identity,
            "sourceDepartment": department,
            "sourceMajor": row["4:개설전공"],
            "sourceGeneralCategory": row["5:교양구분"],
            "campus": "unknown", "academicYear": 2026, "semester": "2",
            "courseCode": code, "section": section,
            "courseName": row["7:과목명"], "professor": row["21:담당교수"] or "",
            "credits": row["19:학점"], "departments": [department],
            "classification": classification,
            "departmentCredits": {department: row["19:학점"]},
            "departmentClassifications": {department: classification},
            "departmentRemarks": {department: "\n".join(n for n in published_notes if n)},
            "sourceSchedule": source_schedule,
            "sourceClassroom": "; ".join(str(row[f"{i}:None"]) for i in (26, 29, 32) if row[f"{i}:None"]),
            "sourceFlags": {k.split(":", 1)[1]: row[k] for k in (
                "9:원격100%", "10:원격50%이상", "11:사전녹화100%", "13:집중이수제")},
            "period": {"startDate": "2026-09-01", "endDate": "2026-12-14"},
            "scheduleStatus": "scheduled" if schedules else "unrecognized",
            "schedules": schedules,
        }
        for field, key in [("courseName", "7:과목명"), ("credits", "19:학점"),
                           ("sourceDepartment", "3:개설학과"), ("classification", "17:이수구분")]:
            if course[field] != row[key]:
                metadata_mismatches.append([identity, field])
        assert course["courseCode"] + "-" + course["section"] == identity
        assert remark in course["departmentRemarks"][department]
        courses.append(course)
        clocks.append({"sourceAcademicNumber": identity, "eligible": eligible,
                       "clockReviewProfile": review["clockReviewProfile"],
                       "sourceClockBlocks": blocks if eligible else [],
                       "datedMeetings": len(schedules)})
    assert not metadata_mismatches
    assert len(courses) == len({c["sourceId"] for c in courses}) == 1261
    dataset = {"schemaVersion": 2, "universityId": "kwangwoon", "campus": "unknown",
               "campusName": "위치 미확인", "academicYear": 2026, "semester": "2",
               "publishedDate": "2026-10-08", "sourceUrl": "https://www.kw.ac.kr/ko/life/bachelor_info13.jsp",
               "courses": courses}
    target = ROOT / "kwangwoon-unknown-2026-2.partial-candidate.json"
    target.write_text(json.dumps(dataset, ensure_ascii=False, indent=2) + "\n")
    audit = {"checkedDate": "2026-10-08", "productionRegistered": False,
             "completionClaim": False, "wholeScope": 1261,
             "counts": dict(Counter(c["scheduleStatus"] for c in courses)),
             "educationalMetadataMismatches": metadata_mismatches,
             "ordinaryRule": "kw-current-holiday-rule-20261008.json",
             "excludedNationalHolidayDates": sorted(HOLIDAYS),
             "nationalHolidaySource": "https://www.kasa.go.kr/bbs/BBSMSTR_000000000010/view.do?nttId=B000000001860Pe2zT3",
             "makeupWindowNotGenerated": ["2026-12-15", "2026-12-21"],
             "campusAssignment": "unknown: workbook does not publish a campus column; no location inferred from department/building",
             "identityGrammarSource": "Official public timetable page defines department-difficulty-course-section components; exact full string retained",
             "cancelledScope": "kw-cancellation-crosscheck.json: final73 are absent from whole current1261",
             "candidateSha256": {target.name: hashlib.sha256(target.read_bytes()).hexdigest()},
             "courses": clocks}
    (ROOT / "kw-partial-candidate-audit-20261008.json").write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n")
    print(audit["counts"])


if __name__ == "__main__":
    main()
