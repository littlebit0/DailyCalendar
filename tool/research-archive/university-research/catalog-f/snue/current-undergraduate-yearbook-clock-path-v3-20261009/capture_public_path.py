"""Capture only the observed public SNUE yearbook route, never viewer APIs."""
import hashlib
import json
import re
import urllib.parse
import urllib.request
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
BASE = "https://www.snue.ac.kr"
MENU = BASE + "/snue/na/ntt/selectNttList.do?bbsId=3089&mi=3490"


def fetch(url, data=None):
    with urllib.request.urlopen(urllib.request.Request(url, data=data), timeout=30) as response:
        body = response.read()
        return body.decode("utf-8"), {
            "url": url,
            "finalUrl": response.url,
            "status": response.status,
            "bytes": len(body),
            "responseSha256": hashlib.sha256(body).hexdigest(),
        }


def save(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


menu, menu_receipt = fetch(MENU)
start = menu.index("대학요람(2026)")
segment = menu[start:start + 2200]
document_id = re.search(r"onclick=\"view\('([^']+)'\)", segment).group(1)
assert '<form name="viewerForm" id="viewerForm" method="POST"' in menu
assert 'attr("action","/snue/na/ntt/selectNttViewPop.do")' in menu
preview_url = BASE + "/snue/na/ntt/selectNttViewPop.do"
preview, preview_receipt = fetch(
    preview_url, urllib.parse.urlencode({"streamdocsId": document_id}).encode()
)
iframe = re.search(r'<iframe id="viewer" src="([^"]+)"', preview).group(1)
assert iframe.startswith("https://doc.snue.ac.kr:8080/streamdocs/view/sd;streamdocsId=")
viewer, viewer_receipt = fetch(iframe)
assert "<sd-root>" in viewer
save("new-2026-yearbook-public-path-education.json", {
    "observedOn": "2026-10-09",
    "school": "SNUE 서울교육대학교",
    "educationScope": "Official university yearbook menu; current annual undergraduate/general university document lead, not confirmed semester offerings or clock",
    "entry": "Official main menu 대학소개 → 대학현황 → 대학요람",
    "nativeDocumentTitle": "대학요람(2026)",
    "menu": menu_receipt,
    "publicPreviewForm": {
        "method": "POST", "action": preview_url,
        "publishedInputName": "streamdocsId", "publishedDocumentId": document_id,
        "source": "Actual yearbook item onclick plus published viewerForm; not guessed endpoint",
        "response": preview_receipt,
    },
    "publishedIframe": viewer_receipt,
    "viewerObservedState": "Normal public HTTP200 StreamDocs HTML application shell with sd-root; document pages not obtained through static response",
    "wholeHtmlStored": False,
    "documentPageTextObtained": False,
    "newCourseRows": 0,
    "newRegularUndergraduatePeriodHH": [],
    "universityWideClockApplicabilityConfirmed": False,
    "internalViewerApiAttempted": False,
    "accountLoginAttempted": False,
    "securityBypassAttempted": False,
    "sdkUsed": False,
    "productChanged": False,
    "completionClaim": False,
    "impossibleClaim": False,
})
prior = ROOT / "work/university-research/catalog-f/snue/snue-unknown-2026-2.native-held-partial-v1.json"
assert hashlib.sha256(prior.read_bytes()).hexdigest() == "bb2af549e573dee2c26d81b27adbfa1dd0a7d9d3e091f6aba062097c39ec60fb"
save("prior-preservation-and-independent-clock-verification-plan.json", {
    "priorPath": str(prior.relative_to(ROOT)),
    "priorSha256": hashlib.sha256(prior.read_bytes()).hexdigest(),
    "priorNativeDocumentBlocks": 460,
    "priorRawSelectedOccurrences": 478,
    "priorScheduledBlocks": 0,
    "priorDatedSlots": 0,
    "priorClosedBlocks": 3,
    "priorFrozenChanged": False,
    "newEligibleCandidates": 0,
    "newFixtureCreated": False,
    "reason": "No current regular undergraduate numbered-period start/end HH obtained; a new public yearbook viewer lead alone cannot resolve the native period grid",
    "nextNormalPublicAction": "Use the published yearbook preview in a normal hidden browser UI; no internal network/API calls. Inspect current undergraduate period HH, exact page/title and applicability if the UI displays pages.",
    "independentVerificationRequiredBeforeCandidate": [
        "Literal period start/end HH and current undergraduate scope from actual yearbook page; retain page/education excerpt evidence",
        "Do not treat facility access hours, graduate clocks, admissions exams, mentoring, CPR or orientation times as regular undergraduate clock",
        "Compare numbered-period labels to frozen 460 native blocks without inferred course identity/section/room allocation",
        "Preserve 3 current closures and 2 native allocation conflicts; confirmed clock alone does not resolve teacher/room pair allocation",
        "Verify own current semester/exceptions and actual appointment weekday/date, all native educational fields, user mode choices and full Drive JSON only after scheduling evidence exists",
    ],
    "completionClaim": False,
    "impossibleClaim": False,
})
print("Public yearbook path captured; prior native file SHA exact; new clock/course candidates 0.")
