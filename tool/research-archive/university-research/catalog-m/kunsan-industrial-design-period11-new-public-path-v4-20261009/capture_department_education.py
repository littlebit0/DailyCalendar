"""Bounded new curriculum/activity route; never infer period11 clock."""
import hashlib
import json
import re
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
BASE = "https://www.kunsan.ac.kr"


class EducationTables(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tables = []
        self.table = None
        self.row = None
        self.cell = None

    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self.table = []
        elif tag == "tr" and self.table is not None:
            self.row = []
        elif tag in ("td", "th") and self.row is not None:
            self.cell = []

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.cell is not None:
            self.row.append(" ".join("".join(self.cell).split()))
            self.cell = None
        elif tag == "tr" and self.row is not None:
            if self.row:
                self.table.append(self.row)
            self.row = None
        elif tag == "table" and self.table is not None:
            self.tables.append(self.table)
            self.table = None


def capture(url):
    with urllib.request.urlopen(url, timeout=30) as r:
        body = r.read()
        return body.decode("utf-8"), {"url": url, "finalUrl": r.url, "status": r.status,
                                     "bytes": len(body), "responseSha256": hashlib.sha256(body).hexdigest()}


home, home_receipt = capture(BASE + "/kssandi/")
assert "DOM_000006002001000000" in home
assert "DOM_000006002002000000" in home
curriculum, curriculum_receipt = capture(BASE + "/index.kunsan?menuCd=DOM_000006002001000000")
parser = EducationTables()
parser.feed(curriculum)
table = next(t for t in parser.tables if t and "교과목번호" in t[0])
assert len(table[0]) == 7
assert all(len(row) == 7 for row in table)
target = [row for row in table[1:] if row[3] == "116289"]
assert len(target) == 1
assert target[0][4] == "디자인교과교재및연구법"
assert "2026" in curriculum and "2학기 산업디자인학부" in curriculum
activity, activity_receipt = capture(BASE + "/index.kunsan?menuCd=DOM_000006002002000000")
notice, notice_receipt = capture(BASE + "/index.kunsan?menuCd=DOM_000006005009000000")
notice_parser = EducationTables()
notice_parser.feed(notice)
notice_table = next(t for t in notice_parser.tables if t and any("제목" in c for c in t[0]))
notice_rows = [{"ordinal": row[0], "title": row[1], "publishedDate": row[3]} for row in notice_table[1:] if len(row) >= 4]
result = {
    "observedOn": "2026-10-09", "scope": "Actual industrial-design departmental undergraduate menu only",
    "homepage": home_receipt, "curriculum": curriculum_receipt,
    "curriculumTitle": "학부(과) 교육과정 검색 (2026년 2학기 산업디자인학부)",
    "curriculumNativeHeader": table[0], "curriculumRawEducationalRows": table[1:],
    "curriculumRowCount": len(table) - 1, "targetLiteralCurriculumRow": target[0],
    "curriculumScopeDecision": "Curriculum code/title/year/semester/grade/category/credit-daytime metadata corroboration only; no offering section/professor/weekday/HH/room columns",
    "activity": activity_receipt,
    "activityObservedScope": "45 posts; first visible page is coursework showcase with2025/2024 course titles, not current2026-2 period clock",
    "notice": notice_receipt, "visibleNoticeTitlesAndDates": notice_rows,
    "noticeScopeDecision": "Unfiltered actual first page checked; latest advising/allocation/social/remote-enrollment/library or older-year subjects not regular period11 start/end table. No linked personal allocation or old guide downloaded.",
    "newRegularPeriod11StartHH": None, "newRegularPeriod11EndHH": None,
    "newEligibleCandidates": 0,
    "notInferred": ["19:10 from period10 end19:00", "50-minute end", "주간 label as exactHH", "department location as physical offering campus", "curriculum grade/credits as course duration"],
    "existingKnownSourcesRedownloaded": False,
    "rawWholeHtmlSaved": False, "staffContactSaved": False,
    "sdkUsed": False, "productChanged": False, "agentMemoryChanged": False,
    "completionClaim": False, "impossibleClaim": False,
}
(OUT / "current-industrial-design-curriculum-and-clock-gap-education.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
proof = {
    "sourceId": "kunsan/unknown/2026/2/116289/01",
    "nativeCode": "116289", "nativeSection": "01", "nativeTitle": "디자인교과교재및연구법",
    "nativeProfessor": "이승희", "nativeDepartment": "산업디자인전공",
    "nativeCredits": "3-3-0", "nativeClassification": "전공선택",
    "nativeScheduleOriginal": "금9 10 11 [예술관-5403]",
    "sourceFieldOnlyCorroborated": "Curriculum exact code116289/title/category/credits/major; no independentsection/weekday/HH/room supplied",
    "existingKnownPartialScope": "Keep separately pending/reviewed 9/10 slots17:10–19:00 on13dates; this investigation adds0 and does not alter pending root SDK validation",
    "remainingPeriod11Reason": "No source HH start/end in these actual public departmental curriculum/activity/notice paths",
    "preservedFrozenFiles": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [
        ROOT / "work/university-research/catalog-m/kunsan-known9-10-pending-partial-root-review-v3-20261009/kunsan-unknown-2026-2.known9-10-root-review-v3.json",
        ROOT / "work/university-research/catalog-m/kunsan-current-circled-late-clock-department-path-v2-20261009/SHA256SUMS.json",
    ]},
    "newAppointmentDates": [], "candidateOrFixtureCreated": False,
    "completionClaim": False, "impossibleClaim": False,
}
(OUT / "native116289-period11-gap-and-preservation-proof.json").write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n")
print("PASS normal public departmental source; curriculum rows", len(table)-1, "; exact target row1; period11HH/new schedules0.")
