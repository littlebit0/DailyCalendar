"""Read the root's immutable official yearbook; store bounded education proof."""
import hashlib
import json
import re
from pathlib import Path
from pypdf import PdfReader

OUT = Path(__file__).resolve().parent
SOURCE = OUT.parent
ROOT = OUT.parents[5]
PDF = SOURCE / "snue-2026-official-yearbook.pdf"
TEXT = SOURCE / "snue-2026-official-yearbook.txt"
PDF_SHA = "7706ca1e210a194dc82e850cb25250325b2ab8fdac47f2c427b316f1771df114"
assert hashlib.sha256(PDF.read_bytes()).hexdigest() == PDF_SHA
reader = PdfReader(PDF)
assert len(reader.pages) == 537
pages = [page.extract_text() or "" for page in reader.pages]
terms = ["교시", "수업시간표", "강의시간", "1단위 시간은 50분", "오전", "오후", "수업이 시작되는 시각"]
time_pattern = re.compile(r"\d{1,2}\s*[:：]\s*\d{2}")
classification = {
    373: "서록관 외박 신청 deadline, not regular undergraduate class clock",
    490: "학군단 restricted education block, not numbered general undergraduate periods; no native offering identity/room/year-term join",
    492: "학군단 application/submission windows, not course clock",
    493: "학군단 recruitment/application deadline, not course clock",
    511: "총동창회 historical event hours, not course clock",
}
time_hits = []
for number, text in enumerate(pages, 1):
    values = time_pattern.findall(text)
    if values:
        assert number in classification, (number, values)
        time_hits.append({"pdfPageOneBased": number, "printedPage": number - 10,
                          "literalTimes": values, "scopeDecision": classification[number]})
page51 = pages[50]
start = page51.index("제6조(수업시간표)")
end = page51.index("제8조(수강인원의 편성)")
page128 = pages[127]
unit = re.search(r"1\) 1학점은[^\n]+", page128).group(0)
page490 = pages[489]
rotc = re.search(r"∙ 교내교육[^\n]+", page490).group(0)
prior = ROOT / "work/university-research/catalog-f/snue/snue-unknown-2026-2.native-held-partial-v1.json"
prior_sha = hashlib.sha256(prior.read_bytes()).hexdigest()
assert prior_sha == "bb2af549e573dee2c26d81b27adbfa1dd0a7d9d3e091f6aba062097c39ec60fb"
courses = json.loads(prior.read_text())["courses"]
assert len(courses) == 460
assert not any(any(term in json.dumps(course, ensure_ascii=False) for term in
                   ["군사학", "안전 및 조직관리", "창의리더십", "안보학"]) for course in courses)
result = {
    "observedOn": "2026-10-09", "school": "SNUE 서울교육대학교",
    "sourceAcquisition": "Root normal visible public yearbook viewer menu PDF download; same actual published viewer URL as frozen v3",
    "sourcePdfSha256": PDF_SHA, "sourcePdfBytes": PDF.stat().st_size,
    "sourceTextSha256": hashlib.sha256(TEXT.read_bytes()).hexdigest(),
    "pdfPages": 537, "allPagesTextSearched": 537,
    "searchTermHitPages": {term: [i + 1 for i, text in enumerate(pages) if term in text] for term in terms},
    "otherTermHitsClassified": [
        {"pdfPageOneBased": 58, "scope": "Blank 공결신청서 example with 3-4교시 only; no actual offering or HH; no identity/contact fields copied"},
        {"pdfPageOneBased": 285, "scope": "학교시설 lexical substring 교시, not numbered-period clock"},
        {"pdfPageOneBased": 388, "scope": "박물관 관람시간 오전10시–오후5시, not course clock"},
    ],
    "allLiteralColonTimeHits": time_hits,
    "regularUndergraduateRule": {
        "pdfPageOneBased": 51, "printedPage": 41,
        "literalEducationExcerpt": page51[start:end].strip(),
        "decision": "Native pair/triple-period grouping and teaching time change approval; no start/end HH. Not enough to convert frozen native periods.",
    },
    "undergraduateUnitRule": {"pdfPageOneBased": 128, "printedPage": 118,
                              "literalEducationExcerpt": unit,
                              "decision": "50-minute unit is explicit; start, break placement and end for numbered periods are not supplied"},
    "scopedRotcBlock": {"pdfPageOneBased": 490, "printedPage": 480,
                       "literalEducationExcerpt": rotc,
                       "semester2TitleLabels": ["안전 및 조직관리 사례연구", "창의리더십"],
                       "nativeCodePublished": False, "sectionPublished": False,
                       "professorPublished": False, "classroomPublished": False,
                       "numberedPeriodClockPublished": False,
                       "titleTermsPresentInPrior460": False,
                       "decision": "Do not generalize Wed/Thu08:00–10:00 to regular period0/1/2 or title-only join these 2-credit restricted offerings"},
    "otherMisleadingStartEndRule": {"pdfPageOneBased": 484, "printedPage": 474,
                                    "scope": "부설초등학교 수업운영, 학교장 determines start/end; no HH and not university undergraduate scope"},
    "visualPagesInspected": [51, 128, 490],
    "visualRenderNote": "Bundled pdftoppm; page51 font warning affects decorative side text, regular Korean rule body and printed41 are legible",
    "priorNativeFileSha256": prior_sha,
    "priorNativeBlocks": 460, "priorRawOccurrences": 478, "priorScheduled": 0,
    "priorDatedSlots": 0, "priorClosed": 3,
    "newEligibleClockMappings": 0, "newScheduledCandidates": 0,
    "inferenceLimit": "Negative result is bounded to extracted full537-page text and relevant visual pages; does not prove no other current public source exists",
    "sourcePdfOrTextChanged": False, "sdkUsed": False, "productChanged": False,
    "historicalFrozenChanged": False, "completionClaim": False, "impossibleClaim": False,
}
(OUT / "whole537-page-clock-scope-education-proof.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2) + "\n")
print("PASS:537 pages read, period/unit visual scope separated; current native460 exact unchanged; new scheduling0.")
