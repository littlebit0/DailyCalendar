"""Partition existing official rows; never infer remote clocks or approve imports."""
from pathlib import Path
from collections import Counter
import hashlib
import json

ROOT = Path(__file__).parent
FLAGS = ["9:원격100%", "10:원격50%이상", "11:사전녹화100%", "13:집중이수제"]
PERIODS = ["25:None", "28:None", "31:None"]


def main():
    rows = json.loads((ROOT / "kw-all-2026-2.json").read_text())["records"]
    groups = Counter()
    clock_profiles = Counter()
    review = []
    for row in rows:
        flags = [row[key] == "Y" for key in FLAGS]
        if flags[2]:
            group = "prerecorded100-intensive" if flags[3] else "prerecorded100"
        elif flags[0]:
            group = "remote100-mode-unverified"
        elif flags[1]:
            group = "mixed-intensive" if flags[3] else "mixed-mode-unverified"
        else:
            group = "published-default-in-person"
        groups[group] += 1
        periods = [str(row[key]) for key in PERIODS if row[key] is not None]
        tokens = [token.strip() for value in periods for token in value.split(",")]
        unresolved = []
        clock_profile = "delivery-pattern-review"
        if group == "published-default-in-person":
            if any(not token.isdigit() or not 1 <= int(token) <= 11 for token in tokens):
                clock_profile = "special-period"
            elif row["20:시간"] in (2, 4):
                clock_profile = "continuous-2h-or-4h-review"
            elif sum(1.5 if int(token) <= 6 else 1 for token in tokens) == row["20:시간"]:
                clock_profile = "ordinary-clock-chart-source-hour-fit"
            else:
                clock_profile = "source-hours-vs-ordinary-chart-review"
            clock_profiles[clock_profile] += 1
        if any(not token.isdigit() or int(token) > 11 for token in tokens):
            unresolved.append("period-outside-published-ordinary-clock-chart")
        if "0" in tokens:
            unresolved.append("continuous-laboratory-0-period-needs-exact-block-rule")
        if group == "published-default-in-person" and row["20:시간"] in (2, 4):
            unresolved.append("published-2h-or-4h-continuous-clock-rule-review")
        if group.startswith("mixed") or group.startswith("remote100"):
            unresolved.append("weekly-delivery-pattern-not-published-in-workbook")
        if flags[3]:
            unresolved.append("individual-concentrated-date-and-operating-context-review")
        review.append({
            "sourceId": row["6:학정번호"],
            "title": row["7:과목명"],
            "sourceDepartment": row["3:개설학과"],
            "sourceMajor": row["4:개설전공"],
            "sourceClassification": row["17:이수구분"],
            "sourceHours": row["20:시간"],
            "sourcePeriods": periods,
            "operatingGroup": group,
            "clockReviewProfile": clock_profile,
            "reviewReasons": unresolved,
        })
    assert len(review) == len({row["sourceId"] for row in review}) == 1261
    output = {
        "checkedDate": "2026-10-08",
        "source": "https://www.kw.ac.kr/ko/life/bachelor_info13.jsp",
        "currentDownload": "https://www.kw.ac.kr/include/Download.jsp?fuid=35273&ano=52935",
        "currentDownloadBytes": 317194,
        "currentDownloadSameAsExisting": True,
        "sourceSha256": hashlib.sha256((ROOT / "kw-2026-2-timetable.bin").read_bytes()).hexdigest(),
        "modeCounts": dict(groups),
        "defaultInPersonClockReviewCounts": dict(clock_profiles),
        "officialDefaultModeSource": "https://www.kw.ac.kr/ko/life/notice.jsp?BoardMode=view&DUID=52981",
        "ordinaryClockSource": "https://www.kw.ac.kr/include/Download.jsp?fuid=34965&ano=52978",
        "holidayRuleSource": "https://rule.kw.ac.kr/lmxsrv/law/lawFullContent.do?SEQ=21&SEQ_HISTORY=664",
        "ordinaryWindowForReview": {"start": "2026-09-01", "end": "2026-12-14"},
        "makeupWindowNotRegular": {"start": "2026-12-15", "end": "2026-12-21"},
        "approval": False,
        "limits": [
            "Mode partition is source context, not individual operating approval.",
            "Do not transform all adjacent periods into normal75min or continuous2h clocks.",
            "Do not transform prerecorded virtual periods into recurring meetings.",
            "KW-VIP virtual periods need individual course operating clocks.",
            "KMOOC offline final dates announced separately; do not generate them.",
            "Holiday dates require authoritative calendar plus current rule; no dates generated here.",
            "Public change notice excludes room/professor-only changes; current workbook and plans differ in verification scope.",
        ],
        "records": review,
    }
    (ROOT / "kw-current-operating-review-20261008.json").write_text(
        json.dumps(output, ensure_ascii=False, indent=2) + "\n"
    )
    print(json.dumps({"rows": len(review), "groups": dict(groups)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
