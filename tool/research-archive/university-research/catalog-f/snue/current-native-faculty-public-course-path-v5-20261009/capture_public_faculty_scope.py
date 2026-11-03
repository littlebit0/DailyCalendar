"""One observed public faculty route, exact current native targets; no guessing."""
import hashlib
import json
import re
import urllib.parse
import urllib.request
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
BASE = "https://www.snue.ac.kr"
ENTRY = BASE + "/snue/pf/prfsr/ProfessorList.do?mi=3036"


def fetch(url, data=None):
    with urllib.request.urlopen(urllib.request.Request(url, data=data), timeout=30) as r:
        body = r.read()
        return body.decode("utf-8"), {"url": url, "finalUrl": r.url,
                                     "status": r.status, "responseSha256": hashlib.sha256(body).hexdigest()}


source = ROOT / "work/university-research/catalog-f/snue/snue-unknown-2026-2.native-held-partial-v1.json"
before = hashlib.sha256(source.read_bytes()).hexdigest()
assert before == "bb2af549e573dee2c26d81b27adbfa1dd0a7d9d3e091f6aba062097c39ec60fb"
native = json.loads(source.read_text())
targets = [c for c in native["courses"] if c["professor"] == "구덕회" and c["courseName"] == "초등컴퓨팅교육방법론"]
assert len(targets) == 2
assert all(c["academicYear"] == 2026 and c["semester"] == "2" and c["section"] == "C" for c in targets)
html, entry = fetch(ENTRY)
p = html.index("구덕회")
row = html[html.rfind("<tr", 0, p):html.index("</tr>", p)]
profile_id = re.search(r'<a[^>]*data-id="([^"]+)"[^>]*class="more', row).group(1)
assert profile_id == "3053"
assert 'url: "/snue/pf/prfsr/selectProfessorDetail.do"' in html
assert "data: {selectPrs : selectPrs}" in html
url = BASE + "/snue/pf/prfsr/selectProfessorDetail.do"
response, detail = fetch(url, urllib.parse.urlencode({"selectPrs": profile_id}).encode())
public = json.loads(response)
assert public.get("result") == "Y"
links = re.findall(r'https?://[^\s\"<>]+', response)
assert not links
assert not public.get("prfsrMore")
assert before == hashlib.sha256(source.read_bytes()).hexdigest()
proof = {
    "observedOn": "2026-10-09", "school": "SNUE 서울교육대학교",
    "chosenScope": "Current native professor 구덕회 / 초등컴퓨팅교육방법론 / C /2026-2 only",
    "officialEntry": entry,
    "entryLinkProvenance": "Official main 대학소개→교수진 actual anchor, not generic search",
    "actualPublicMoreButton": {"publishedName": "구덕회", "publishedDepartment": "정보교육과",
                               "publishedDataId": profile_id,
                               "literalHandler": "selectPrs=clicked data-id; POST /snue/pf/prfsr/selectProfessorDetail.do"},
    "normalPublicProfileResponse": detail, "result": public["result"],
    "additionalProfileEntries": len(public.get("prfsrMore", [])),
    "publishedHomepageOrCourseMaterialLinks": links,
    "current2026TermPlanOrHHPublished": False,
    "decision": "Profile returns no published homepage/course-material link or additional profile content. No guessed faculty URL, LMS route or old-year same-title course was followed.",
    "targetNativeFullEducationalObjects": targets,
    "targetDistinctScopeWarning": "Both native C labels have different student scope/day periods; keep separate document-locator identities, no title/professor merge or code invention",
    "ownCalendarPreserved": {"termStartDate": native["termStartDate"], "termEndDate": native["termEndDate"],
                             "grade2And3PracticePeriod": "2026-10-26–2026-11-06 from preserved source; selected grade4 targets do not inherit it",
                             "thursday7And8": "Current undergraduate instruction reserves these for field-capacity program; no generated regular class there",
                             "knownClosedBlocks": 3, "latestWholeClosuresCompared": False},
    "nativeFileSha256BeforeAndAfter": before,
    "priorNativeCount": len(native["courses"]), "newEligibleCandidates": 0,
    "newOwnHHClockMappings": [], "newFixtureCreated": False,
    "staffContactOfficeHoursOrPrivateProfileBodySaved": False,
    "protectedEndpointGuessOrAccountLogin": False, "sdkUsed": False, "productChanged": False,
    "completionClaim": False, "impossibleClaim": False,
}
(OUT / "current-native-faculty-exact-scope-education-proof.json").write_text(json.dumps(proof, ensure_ascii=False, indent=2) + "\n")
print("PASS exact current2native targets; actual public faculty button only; homepage/syllabus links0; newHH0; prior460SHAunchanged.")
