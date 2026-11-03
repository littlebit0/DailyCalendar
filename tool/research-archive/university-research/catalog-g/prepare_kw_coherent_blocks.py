"""Coalesce only consecutive night periods within one original source triple."""
from pathlib import Path
from collections import defaultdict
import copy
import hashlib
import json
from prepare_kw_partial_candidate import CLOCKS, DAY

ROOT = Path(__file__).parent


def main():
    original_path = ROOT / "kwangwoon-unknown-2026-2.checkpoint-next.json"
    original = json.loads(original_path.read_text())
    result = copy.deepcopy(original)
    raw = {r["6:학정번호"]: r for r in json.loads(
        (ROOT / "kw-all-2026-2.json").read_text())["records"]}
    merges = []
    affected = set()
    before_count = after_count = 0
    for course in result["courses"]:
        before_count += len(course["schedules"])
        if not course["schedules"]:
            continue
        row = raw[course["sourceAcademicNumber"]]
        for i in (24, 27, 30):
            periods = row[f"{i + 1}:None"]
            if periods is None:
                continue
            tokens = str(periods).split(",")
            if len(tokens) < 2 or not all(t.isdigit() and 7 <= int(t) <= 11 for t in tokens):
                continue
            numbers = [int(t) for t in tokens]
            if numbers != list(range(numbers[0], numbers[-1] + 1)):
                continue
            weekday = DAY[row[f"{i}:요일{(i - 24) // 3 + 1}"]]
            room = row[f"{i + 2}:None"] or ""
            old_blocks = [{"startMinute": CLOCKS[n][0], "endMinute": CLOCKS[n][1]} for n in numbers]
            indices_by_date = defaultdict(list)
            for index, m in enumerate(course["schedules"]):
                if m["weekday"] == weekday and m["classroom"] == room and any(
                    m["startMinute"] == b["startMinute"] and m["endMinute"] == b["endMinute"]
                    for b in old_blocks
                ):
                    indices_by_date[m["date"]].append(index)
            # No other source triple, classroom or nonconsecutive period joins
            # this block. Require each dated set to contain exactly all slots.
            if not indices_by_date or any(len(indices) != len(numbers) for indices in indices_by_date.values()):
                continue
            remove = set()
            merged = []
            for teaching_date, indices in indices_by_date.items():
                actual = sorted((course["schedules"][n]["startMinute"], course["schedules"][n]["endMinute"]) for n in indices)
                assert actual == sorted((b["startMinute"], b["endMinute"]) for b in old_blocks)
                remove.update(indices)
                merged.append({"weekday": weekday, "startMinute": CLOCKS[numbers[0]][0],
                               "endMinute": CLOCKS[numbers[-1]][1], "classroom": room,
                               "date": teaching_date})
            course["schedules"] = [m for n, m in enumerate(course["schedules"]) if n not in remove] + merged
            course["schedules"].sort(key=lambda m: (m["date"], m["startMinute"], m["endMinute"], m["classroom"]))
            affected.add(course["sourceAcademicNumber"])
            merges.append({"sourceAcademicNumber": course["sourceAcademicNumber"],
                           "sourceTripleIndex": (i - 24) // 3 + 1,
                           "sourcePeriods": str(periods), "weekday": weekday, "classroom": room,
                           "originalPeriodClockBlocks": old_blocks,
                           "mergedStartMinute": CLOCKS[numbers[0]][0],
                           "mergedEndMinute": CLOCKS[numbers[-1]][1],
                           "dates": sorted(indices_by_date)})
    metadata_mismatches = []
    original_by_id = {c["sourceId"]: c for c in original["courses"]}
    for course in result["courses"]:
        after_count += len(course["schedules"])
        for key, value in original_by_id[course["sourceId"]].items():
            if key != "schedules" and course[key] != value:
                metadata_mismatches.append([course["sourceAcademicNumber"], key])
        if course["sourceAcademicNumber"] not in affected:
            assert course == original_by_id[course["sourceId"]]
    assert not metadata_mismatches and len(affected) == 65
    output = ROOT / "kwangwoon-unknown-2026-2.coherent-blocks-next.json"
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    base = json.loads((ROOT / "kwangwoon-unknown-2026-2.partial-candidate.json").read_text())
    base_ids = {c["sourceAcademicNumber"] for c in base["courses"] if c["schedules"]}
    audit = {"checkedDate": "2026-10-08", "productionRegistered": False, "completionClaim": False,
             "wholeScope": 1261, "scheduled": 945, "unrecognized": 316,
             "affectedCourses": len(affected), "affectedOriginal832": len(affected & base_ids),
             "affectedNew113": len(affected - base_ids), "datedMeetingsBefore": before_count,
             "datedMeetingsAfter": after_count, "metadataMismatches": metadata_mismatches,
             "immutableSourceSha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (
                 original_path, ROOT / "kwangwoon-unknown-2026-2.partial-candidate.json",
                 ROOT / "kwangwoon-unknown-2026-2.continuous-additions.json")},
             "candidateSha256": {output.name: hashlib.sha256(output.read_bytes()).hexdigest()},
             "rule": "Same original triple and room only, exactly consecutive night7–11 periods; keep5min breaks inside source block outer bounds.",
             "merges": merges}
    (ROOT / "kw-coherent-blocks-audit-20261008.json").write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n")
    print({k: audit[k] for k in ("affectedCourses", "affectedOriginal832", "affectedNew113", "datedMeetingsAfter")})


if __name__ == "__main__":
    main()
