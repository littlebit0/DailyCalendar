"""Add only exact current guide continuous blocks; keep initial832 immutable."""
from pathlib import Path
from datetime import date, timedelta
import copy
import hashlib
import json
from prepare_kw_partial_candidate import HOLIDAYS, CLOCKS, DAY

ROOT = Path(__file__).parent
GUIDE = "https://www.kw.ac.kr/include/Download.jsp?fuid=34965&ano=52978"
DAY_TWO = {"1,2": (540, 650), "3,4": (720, 830), "5,6": (900, 1010)}
DAY_FOUR = {"0,1,2": (480, 710), "5,6,7": (900, 1130)}


def main():
    raw = json.loads((ROOT / "kw-all-2026-2.json").read_text())["records"]
    base_path = ROOT / "kwangwoon-unknown-2026-2.partial-candidate.json"
    base = json.loads(base_path.read_text())
    original = {c["sourceAcademicNumber"]: c for c in base["courses"]}
    additions = []
    proofs = []
    for row in raw:
        identity = row["6:학정번호"]
        if original[identity]["schedules"] or any(row[k] == "Y" for k in (
            "9:원격100%", "10:원격50%이상", "11:사전녹화100%", "13:집중이수제")):
            continue
        indices = [i for i in (24, 27, 30) if row[f"{i + 1}:None"] is not None]
        if len(indices) != 1:
            continue
        i = indices[0]
        periods = str(row[f"{i + 1}:None"])
        weekday = row[f"{i}:요일{(i - 24) // 3 + 1}"]
        room = row[f"{i + 2}:None"] or ""
        if weekday not in DAY:
            continue
        hours = row["20:시간"]
        kind = None
        blocks = []
        if hours == 2 and periods in DAY_TWO:
            start, end = DAY_TWO[periods]
            kind = "exact-day-2h-continuous"
            blocks = [{"weekday": DAY[weekday], "startMinute": start,
                       "endMinute": end, "classroom": room}]
        elif hours == 4 and periods in DAY_FOUR and any(
            word in row["7:과목명"] for word in ("실험", "실습")
        ):
            # The guide limits its4h chart to experiments/practicals. A course
            # without that literal source designation is not guessed to fit.
            start, end = DAY_FOUR[periods]
            kind = "exact-day-4h-literal-experiment-or-practical"
            blocks = [{"weekday": DAY[weekday], "startMinute": start,
                       "endMinute": end, "classroom": room}]
        else:
            tokens = periods.split(",")
            if hours in (2, 4) and len(tokens) == hours and all(
                token.isdigit() and 7 <= int(token) <= 11 for token in tokens
            ):
                kind = "exact-published-night-45min-periods"
                blocks = [{"weekday": DAY[weekday], "startMinute": CLOCKS[int(t)][0],
                           "endMinute": CLOCKS[int(t)][1], "classroom": room}
                          for t in tokens]
        if kind is None:
            continue
        course = copy.deepcopy(original[identity])
        schedules = []
        current = date(2026, 9, 1)
        while current <= date(2026, 12, 14):
            if current.isoformat() not in HOLIDAYS and current.isoweekday() != 7:
                for block in blocks:
                    if current.isoweekday() == block["weekday"]:
                        schedules.append(dict(block, date=current.isoformat()))
            current += timedelta(days=1)
        assert schedules
        course["schedules"] = schedules
        course["scheduleStatus"] = "scheduled"
        additions.append(course)
        proofs.append({"sourceAcademicNumber": identity,
                       "sourceCourseName": row["7:과목명"], "sourceHours": hours,
                       "sourcePeriods": periods, "sourceWeekday": weekday,
                       "sourceRoom": room, "clockRule": kind,
                       "sourceClockBlocks": blocks, "sourceGuidePdfPage": 6})
    assert len(additions) == 113
    add_dataset = {k: v for k, v in base.items() if k != "courses"}
    add_dataset["courses"] = additions
    out = ROOT / "kwangwoon-unknown-2026-2.continuous-additions.json"
    out.write_text(json.dumps(add_dataset, ensure_ascii=False, indent=2) + "\n")
    checkpoint = copy.deepcopy(base)
    added = {c["sourceId"]: c for c in additions}
    checkpoint["courses"] = [added.get(c["sourceId"], c) for c in checkpoint["courses"]]
    whole = ROOT / "kwangwoon-unknown-2026-2.checkpoint-next.json"
    whole.write_text(json.dumps(checkpoint, ensure_ascii=False, indent=2) + "\n")
    mismatches = []
    for c in checkpoint["courses"]:
        source = original[c["sourceAcademicNumber"]]
        for key, value in source.items():
            if key not in ("schedules", "scheduleStatus") and c[key] != value:
                mismatches.append([c["sourceAcademicNumber"], key])
    assert not mismatches
    audit = {"checkedDate": "2026-10-08", "productionRegistered": False,
             "completionClaim": False, "wholeScope": 1261, "originalScheduled": 832,
             "newScheduled": 113, "scheduledCombined": 945, "remainingUnrecognized": 316,
             "guideSource": GUIDE, "guidePage": 6, "guidePageVisuallyVerified": True,
             "sourceOriginal832Sha256": hashlib.sha256(base_path.read_bytes()).hexdigest(),
             "sourceOriginal832Changed": False, "metadataMismatches": mismatches,
             "candidateSha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (out, whole)},
             "sourceRule": "kw-current-holiday-rule-20261008.json",
             "excludedNationalHolidayDates": sorted(HOLIDAYS),
             "limits": ["Mixed multi-block courses and unlisted starting periods retained for review.",
                        "Day4h courses without literal experimental/practical designation are not inferred.",
                        "No remote/concentrated flags or virtual/12th periods converted.",
                        "Exact normal timetable attendance, not separately inferred field trips or exam events.",
                        "Ordinary dates end12/14; makeup12/15–21 not generated; source campus remains unknown."],
             "courses": proofs}
    (ROOT / "kw-continuous-additions-audit-20261008.json").write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n")
    print({"added": len(additions), "whole": len(checkpoint["courses"])})


if __name__ == "__main__":
    main()
