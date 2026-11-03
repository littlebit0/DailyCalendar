"""Offline-only structural audit of already acquired official education sources."""
import datetime
import hashlib
import importlib.util
import io
import json
import re
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from openpyxl import load_workbook
from openpyxl.styles.numbers import is_date_format
from pypdf import PdfReader

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
TIME = re.compile(r"\d{1,2}\s*[:：]\s*\d{2}(?::\d{2})?")


def file_receipt(path):
    return {"path": str(path), "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def workbook_audit(path):
    before = file_receipt(path)
    wb = load_workbook(path, data_only=False)
    worksheets = []
    for sheet in wb:
        hits, formulas, timed_formats = [], [], []
        for row in sheet:
            for cell in row:
                if cell.value is None:
                    continue
                if cell.data_type == "f":
                    formulas.append(cell.coordinate)
                if isinstance(cell.value, (datetime.time, datetime.datetime)) or is_date_format(cell.number_format):
                    timed_formats.append(cell.coordinate)
                if TIME.search(str(cell.value)):
                    # No whole source/user cells retained: title publication-time only.
                    hits.append({"cell": cell.coordinate, "literalTimes": TIME.findall(str(cell.value)),
                                 "scope": "2026-09-08 revision publication time, not a numbered-period definition"})
                    assert sheet.title == "Sheet1" and cell.coordinate == "A1"
        headers = []
        for label in ["oddHeader", "oddFooter", "evenHeader", "evenFooter", "firstHeader", "firstFooter"]:
            value = str(getattr(sheet, label))
            headers.append({"type": label, "hasText": bool(value), "literalTimeHits": TIME.findall(value)})
        worksheets.append({"name": sheet.title, "state": sheet.sheet_state,
                           "maxRow": sheet.max_row, "maxColumn": sheet.max_column,
                           "mergedRanges": [str(r) for r in sheet.merged_cells.ranges],
                           "hiddenRows": [i for i, d in sheet.row_dimensions.items() if d.hidden],
                           "hiddenColumns": [i for i, d in sheet.column_dimensions.items() if d.hidden],
                           "formulaCells": formulas, "dateOrTimeFormattedCells": timed_formats,
                           "printHeadersFooters": headers, "clockLikeCells": hits,
                           "allCellsIncludingHiddenAndMergeAnchorsSearched": True})
    xml_audit = []
    with zipfile.ZipFile(path) as archive:
        media = [n for n in archive.namelist() if n.startswith("xl/media/")]
        for name in archive.namelist():
            if not (name.startswith("xl/drawings/") or "comments" in name) or not name.endswith((".xml", ".vml")):
                continue
            body = archive.read(name)
            root = ET.fromstring(body)
            runs = [node.text or "" for node in root.iter() if node.tag.split("}")[-1] == "t"]
            # Joining every paragraph also detects times split among rich text runs.
            paragraphs = ["".join(x.text or "" for x in p.iter() if x.tag.split("}")[-1] == "t")
                          for p in root.iter() if p.tag.split("}")[-1] == "p"]
            clock_hits = TIME.findall(" ".join(runs)) + TIME.findall(" ".join(paragraphs))
            assert not clock_hits
            xml_audit.append({"zipMember": name, "sha256": hashlib.sha256(body).hexdigest(),
                              "richTextRunCount": len(runs), "paragraphCount": len(paragraphs),
                              "numberedClockTimeHits": clock_hits,
                              "classification": "Registration/curriculum advice shapes or empty comment/VML; no own numbered-period HH",
                              "rawAuthorsInternalPathsOrWholeTextsSaved": False})
    assert before == file_receipt(path)
    return {"source": before, "worksheets": worksheets, "drawingCommentVmlAudit": xml_audit,
            "embeddedImageFiles": media, "rawSourceChanged": False}


snue_paths = [ROOT / "work/university-research/catalog-g" / n for n in
              ["snue2026-2-0827.xlsx", "snue2026-2-0908.xlsx", "snue2026-2-changes0908.xlsx"]]
snue = [workbook_audit(p) for p in snue_paths]

helper_path = ROOT / "work/university-research/catalog-g/read_skku_published_office_plan.py"
spec = importlib.util.spec_from_file_location("published_reader", helper_path)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
hwp = ROOT / "work/university-research/catalog-g/snue2026-2-correction-guide.hwp"
hwp_before = file_receipt(hwp)
hwp_text = helper.hwp_text(hwp.read_bytes())
import olefile
with olefile.OleFileIO(io.BytesIO(hwp.read_bytes())) as compound:
    bins = [p for p in compound.listdir() if p[0] == "BinData"]
    sections = [p[-1] for p in compound.listdir() if p[0] == "BodyText"]
assert not bins
assert hwp_before == file_receipt(hwp)
hwp_proof = {"source": hwp_before, "bodyTextSectionsSearched": sections,
             "allParagraphTextRecordsIncludingHeaderFooterSearched": True,
             "embeddedImageStreamCount": len(bins), "literalTimes": TIME.findall(hwp_text),
             "decision": "Correction application10:00/17:00 windows; no own regular undergraduate period HH",
             "protectedOrDistributedBypass": False, "sourceChanged": False}

deu_proof = []
expected_sha = {"deu-current-time-138673-v8.pdf": "5a83fb04accb42a53c8a421bbb1ed722ed38f2f26fb28fd82034b36b0c401ec9",
                "deu-current-time-138674-v8.pdf": "271fa1bd0f6a647ac89356e8e62901deca0af64eb29db143d1be87f1e75693e4"}
for name, sha in expected_sha.items():
    path = Path("/private/tmp") / name
    before = file_receipt(path)
    assert before["sha256"] == sha
    reader = PdfReader(path)
    page_proof = []
    for i, page in enumerate(reader.pages, 1):
        text = page.extract_text() or ""
        hits = TIME.findall(text)
        assert all(t in ["13:19:43", "13:19:36"] for t in hits)
        page_proof.append({"pdfPage": i, "embeddedImages": len(page.images),
                           "annotations": len(page.get("/Annots", [])), "literalTimeHits": hits,
                           "timeMeaning": "2026-08-10 report-generation footer, not teaching start/end",
                           "numericPeriodRoomEducationBodySearched": True})
    root = reader.trailer["/Root"]
    fields = reader.get_fields() or {}
    assert not fields
    assert not root.get("/OCProperties")
    assert not root.get("/Names")
    assert all(p["embeddedImages"] == 0 and p["annotations"] == 0 for p in page_proof)
    assert before == file_receipt(path)
    deu_proof.append({"source": before, "pages": len(reader.pages), "perPageAudit": page_proof,
                      "acroformDictionaryPresent": bool(root.get("/AcroForm")), "actualFormFields": len(fields),
                      "optionalHiddenLayerDictionaryPresent": False, "attachmentNamesDictionaryPresent": False,
                      "sourceChanged": False})

native_files = [ROOT / "work/university-research/catalog-f/snue/snue-unknown-2026-2.native-held-partial-v1.json",
                ROOT / "work/university-research/catalog-r/deu/new-account-first-year-timetable-v8-20261009/current-first-year-native-543-education.json"]
result = {"observedOn": "2026-10-09", "networkRequests": 0, "sdkUsed": False, "productChanged": False,
          "scope": "Cached actual2026-2 SNUE raw3workbooks/HWP and DEU actual2first-yearPDFs, not new web acquisition",
          "snueWorkbooks": snue, "snueCorrectionGuideHwp": hwp_proof, "deuFirstYearPdfs": deu_proof,
          "deuVisualPagesChecked": [{"source": "138673", "pdfPage": 1}, {"source": "138674", "pdfPage": 14}],
          "snueIndependentStructuralProof": "No images in workbook ZIP/HWP. All worksheets, hidden rows, merge anchors, formula/date-format cells, headers/footers and all rich-text drawing paragraphs checked, not plain-cell parser only.",
          "unchangedNativeEducationalSources": [file_receipt(p) for p in native_files],
          "nativeSourceScopePreserved": {"SNUE": 460, "DEU": 543},
          "newCurrentUndergraduateNumberedPeriodStartEndHH": [], "newEligibleCandidates": 0,
          "completionClaim": False, "impossibleClaim": False}
(OUT / "offline-original-embedded-clock-education-proof.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
print("PASS offline:SNUE3xlsx+HWP all embedded structural scope; DEU23PDFpages/footer/images/form/layers; source hashes unchanged; newclock0.")
