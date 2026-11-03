"""Current observed public attachments, educational whitelist and no raw files."""
import datetime
import io
import pdfplumber
import json
import re
import sys
from pathlib import Path

P = Path(__file__).resolve().parent
sys.path.insert(0, str(P.parent.parent / 'catalog-g'))
from repair_skku_inline_privacy_education import collect, old, text_evidence, filter_education

BASE_TEXT_EVIDENCE = text_evidence
TABLE_START = re.compile(r'Course\s+Structure|Week\s*1\b|제\s*1\s*주\b|1\s*주\b|1\)\s*[A-Z]|강의\s*계획|Week\s+Day|1\s*8/31|1\s*9/1|강의\s*오리엔테이션|주\s*차\s*별\s*수\s*업|수\s*업\s*내\s*용|주별\s*수업\s*계획|Class\s+Schedule|Course\s+Schedule|Tentative.{0,40}Schedule|Weekly\s+(?:Course\s+Plan|Schedule)|Lecture\s+Schedule|Course\s+Outline|Schedule\s+주차|주별\s*세부\s*수업계획|세부\s*강의계획|(?:제\s*)?1\s*주차|W1\s*(?::|Team|Lecture|Introduction|\()|강의\s*일정(?:표)?|강의\s*계획표|강의\s*내용|수업\s*일정|수\s*업\s*세\s*부\s*내\s*용|주\s*차\s*별\s*수\s*업\s*주\s*제|주\s*차\s*별\s*수\s*업\s*운\s*영\s*계획|Chapters\s+to\s+be\s+covered|Week\s+Contents|Course\s+Agenda|(?:Weekly|Tentative)\s+Schedule', re.I)
TABLE_END = re.compile(r'평\s*가\s*요\s*소|Evaluation\s+and\s+Grading|Grading\s+Policy|References|Important\s+Policies|Assessment\s+Plan|Course\s+Assessment|Policies\s+and\s+Procedures|Support\s+Systems|Statement\s+on\s+Academic|장애학생\s*지원|Reference\s+Images', re.I)

def table_education(text, code, section, professor):
    result = BASE_TEXT_EVIDENCE(text, code, section, professor)
    safe, masked, lost = filter_education(text)
    tables = []
    for match in TABLE_START.finditer(safe):
        end = TABLE_END.search(safe, match.end())
        segment = safe[match.start():end.start() if end else min(len(safe), match.end()+24000)]
        segment = re.sub(r'\s+', ' ', segment).strip()
        if segment and segment not in tables:
            tables.append(segment)
    result['publishedEducationalOperatingTableSections'] = tables
    result['wholeAttachmentTextPersisted'] = False
    result['operatingTableParserVersion'] = 3
    result['tableSectionPrivacySuppressedLineCount'] = lost
    return result

old.text_evidence = table_education
import repair_skku_inline_privacy_education as repair
repair.text_evidence = table_education

BASE_PDF_EVIDENCE = old.pdf_evidence
GEOMETRY_TARGETS = {'ENA2028-41', 'GELT075-02', 'GELT075-04', 'GEDW001-41', 'GEDW001-42'}

def geometry_pdf_evidence(body, code, section, professor):
    result = BASE_PDF_EVIDENCE(body, code, section, professor)
    if code + '-' + section not in GEOMETRY_TARGETS:
        return result
    tables = []
    with pdfplumber.open(io.BytesIO(body)) as pdf:
        for page_number, page in enumerate(pdf.pages, 1):
            for table in page.find_tables():
                rows = table.extract()
                first_cells = [str(row[0] or '') for row in rows if row]
                numbered = [x for x in first_cells if re.search(r'(?:\b(?:[1-9]|1[0-6])\b|[1-9]\s*주차|1[0-6]\s*주차)', x)]
                if len(numbered) < 3 and not any('수업특성' in str(cell) for row in rows for cell in row):
                    continue
                safe_rows = []
                for row in rows:
                    safe_rows.append([None if cell is None else filter_education(cell)[0] for cell in row])
                tables.append({'page': page_number, 'boundingBox': list(table.bbox),
                               'rows': safe_rows,
                               'cellBoundingBoxesByRow': [[None if cell is None else list(cell) for cell in row.cells] for row in table.rows]})
    result['publishedEducationalOperatingTableGeometry'] = tables
    result['rawAttachmentOrWholePagePersisted'] = False
    return result

old.pdf_evidence = geometry_pdf_evidence


def main():
    targets = json.loads((P / 'whole-attached-pool-classification.json').read_text())['records']
    target_codes = set(json.loads((P / 'operating-table-additional-targets.json').read_text())['offeringCodes'])
    targets = [r for r in targets if r['offeringCode'] in target_codes]
    path = P / 'current-attached-operating-table-v4-additional.json'
    audit = {'researchOnly': True, 'completionClaim': False, 'records': [], 'stopped': False,
             'rawAttachmentsPersisted': False, 'contactsAndStaffIdentifiersPersisted': False,
             'checkedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
             'maximumAnonymousSessions': 1, 'minimumRequestStartSpacingSeconds': .8}
    if path.exists():
        audit = json.loads(path.read_text())
        assert not audit['stopped']
    done = {r['offeringCode'] for r in audit['records']}
    client = old.SpacedPublic('KO')
    try:
        for target in targets:
            if target['offeringCode'] in done:
                continue
            row = target['originalPublicEducationalEvidence']['sourceRow']
            record = collect(client, row)
            audit['records'].append(record)
            path.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
            print('Normal public educational attachment checked', len(audit['records']), flush=True)
    except Exception:
        old.STOP_REQUESTS.set()
        audit['stopped'] = True
        audit['failure'] = 'Normal public source/reader stopped; no retry or bypass.'
        path.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
        raise SystemExit(1)
    print({'currentRecords': len(audit['records']), 'stopped': False})


if __name__ == '__main__':
    main()
