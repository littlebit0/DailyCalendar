"""Capture one actual official math-faculty chain; never guess course identity."""
import hashlib
import html
import json
import re
import urllib.request
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
BASE = "https://www.cnue.ac.kr"


def fetch(path):
    url = BASE + path
    with urllib.request.urlopen(url, timeout=30) as r:
        body = r.read()
        return body.decode("utf-8"), {"url": url, "finalUrl": r.url,
                                     "status": r.status, "responseSha256": hashlib.sha256(body).hexdigest()}


def anchors(text):
    return [(html.unescape(h), " ".join(re.sub("<[^>]+>", " ", html.unescape(t)).split()))
            for h, t in re.findall(r'<a[^>]*href=["\x27]([^"\x27]+)["\x27][^>]*>(.*?)</a>', text, re.S)]


source = ROOT / "work/university-research/catalog-c/cnue-current-20261008/cnue-unknown-2026-2.published-partial-20261008.json"
before = hashlib.sha256(source.read_bytes()).hexdigest()
assert before == "5fbbfe93c38bf7cea68dd3063362f5cef8ecf9e1d403ad22b075e55bfb90ad2d"
native = json.loads(source.read_text())
assert len(native["courses"]) == 208
targets = [c for c in native["courses"] if c.get("professor") == "조형미" and c.get("courseName") == "초등수학교육1"]
assert len(targets) == 1
assert targets[0]["sourceId"] == "cnue-document62495-2학년-I22"
assert targets[0]["courseCode"] == "" and targets[0]["section"] == ""
main, main_receipt = fetch("/cnue/index.do")
assert ("/cnue/uni/mathmatics.do", "수학교육과") in anchors(main)
university, university_receipt = fetch("/cnue/uni/mathmatics.do")
assert any(h == "/mathmatics/index.do" and "홈페이지" in t for h, t in anchors(university))
department, department_receipt = fetch("/mathmatics/index.do")
assert any(h == "/mathmatics/prof/prof-dev.do" and "교수" in t for h, t in anchors(department))
professors, professor_receipt = fetch("/mathmatics/prof/prof-dev.do")
assert "조형미" in professors
assert "홈페이지" not in re.sub("<[^>]+>", " ", professors)
assert any(h == "/mathmatics/community/data.do" and t == "자료실" for h, t in anchors(department))
materials, materials_receipt = fetch("/mathmatics/community/data.do")
material_titles = [{"publishedRelativeLink": h, "title": t} for h, t in anchors(materials) if "articleNo=" in h]
assert len(material_titles) == 4
assert not any("2026" in row["title"] or "강의계획" in row["title"] for row in material_titles)
assert before == hashlib.sha256(source.read_bytes()).hexdigest()
proof = {
    "observedOn": "2026-10-09", "school": "CNUE 춘천교육대학교",
    "scope": "One official main→mathematics department→faculty list→same department public materials chain",
    "routeReceipts": [main_receipt, university_receipt, department_receipt, professor_receipt, materials_receipt],
    "publishedLinksFollowed": ["/cnue/uni/mathmatics.do", "/mathmatics/index.do", "/mathmatics/prof/prof-dev.do", "/mathmatics/community/data.do"],
    "actualProfessorNameMatched": "조형미", "professorDepartment": "수학교육과",
    "professorHomepageOrCourseMaterialLinkPublished": False,
    "publicMaterialFirstPageTitles": material_titles,
    "materialBodyAttachmentsOpened": False,
    "nativeTargetFullEducationalObject": targets[0],
    "nativeJoinBoundary": "Source publishes no official course code or individual section; keep empty. Current title/professor/grade/student scope and originalcell locate target, but do not join an undated generic same-title plan.",
    "currentMatching2026TermSyllabusHHObtained": False,
    "calendarAndOperatingBoundary": {
        "ownSemesterStart": "2026-08-31", "ownSemesterEnd": "2026-12-18",
        "observationPractice": "2026-09-07–2026-09-18", "teachingPractice": "2026-11-02–2026-11-13",
        "makeupRange": "2026-12-07–2026-12-11", "grade4IndividualIntensiveDatesUnresolved": True,
        "knownClosureEducationalRows": 19, "nativeExactCodeSectionClosureJoinProven": False,
        "source": "Preserved frozen current calendar/operating/closure education receipts, no repeat network",
    },
    "priorWhole208SourceSha256BeforeAfter": before, "priorRegularDocumentItems": 203,
    "priorOtherCprDocumentItems": 5, "newOwnHHClockMappings": [], "newEligibleCandidates": 0,
    "contactOfficeHoursStudentNamesOrWholeHtmlSaved": False,
    "browserSearchFailureNote": "Web reader ethics default-menu link UnexpectedStatus and math route robots-read failure; actual observed math chain returned normal200 via ordinary HTTP, no host substitution/security bypass",
    "guessedEndpointOrAccountLogin": False, "sdkUsed": False, "productChanged": False,
    "agentMemoryChanged": False, "completionClaim": False, "impossibleClaim": False,
}
(OUT / "current-math-faculty-native-course-and-clock-gap-education-proof.json").write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n")
print("PASS one currentnative math target/full208SHA exact; actual public chain200; matching syllabusHH0; newcandidate0.")
