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
TABLE_START = re.compile(r'주차\s*(?:차시|날짜|일자)|Course\s+Description|Course\s+Topics|Course\s+Structure|Week\s*1\b|제\s*1\s*주\b|1\s*주\b|1\)\s*[A-Z]|강의\s*계획|Week\s+Day|1\s*8/31|1\s*9/1|강의\s*오리엔테이션|주\s*차\s*별\s*수\s*업|수\s*업\s*내\s*용|주별\s*수업\s*계획|Class\s+Schedule|Course\s+Schedule|Tentative.{0,40}Schedule|Weekly\s+(?:Course\s+Plan|Schedule)|Lecture\s+Schedule|Course\s+Outline|Schedule\s+주차|주별\s*세부\s*수업계획|세부\s*강의계획|(?:제\s*)?1\s*주차|W1\s*(?::|Team|Lecture|Introduction|\()|강의\s*일정(?:표)?|강의\s*계획표|강의\s*내용|수업\s*일정|수\s*업\s*세\s*부\s*내\s*용|주\s*차\s*별\s*수\s*업\s*주\s*제|주\s*차\s*별\s*수\s*업\s*운\s*영\s*계획|Chapters\s+to\s+be\s+covered|Week\s+Contents|Course\s+Agenda|(?:Weekly|Tentative)\s+Schedule', re.I)
TABLE_END = re.compile(r'평\s*가\s*요\s*소|Evaluation\s+and\s+Grading|Grading\s+Policy|References|Important\s+Policies|Assessment\s+Plan|Course\s+Assessment|Policies\s+and\s+Procedures|Support\s+Systems|Statement\s+on\s+Academic|장애학생\s*지원|Reference\s+Images', re.I)

def mask_contact_context(text):
    """Keep native numbers and bibliography; remove only concrete contact context."""
    short = re.compile(r'(?<![A-Za-z0-9])\d{3,4}-\d{4}(?![A-Za-z0-9])')
    confirmed = set()
    for match in short.finditer(text):
        preceding = text[max(0, match.start()-180):match.start()]
        if re.search(r'contact|phone|tel|연락처|전화|office|Fax|☎', preceding, re.I):
            confirmed.add(match.group())
    for token in confirmed:
        text = text.replace(token, '[비공개 정보 제거]')
    text = re.sub(r'\b[\w.+-]+\s*\[at\]\s*[\w.-]+\s*\[dot\]\s*[\w.-]+',
                  '[비공개 정보 제거]', text, flags=re.I)
    def clean_url(match):
        value = match.group()
        if '?' in value and re.search(r'(?:Signature|Key-Pair-Id|access_token|auth_token|sessionid|JSESSIONID|token)=', value, re.I):
            return value.split('?', 1)[0] + '?[비공개 매개변수 제거]'
        return value
    text = re.sub(r'https?://(?:www\.)?datacamp\.com/groups/shared_links/[^\s<>"\u3000)]+', '[비교육 등록 경로 제거]', text, flags=re.I)
    text = re.sub(r'https?://open\.kakao\.com/[^\s<>"\u3000)]+', '[비교육 연락 경로 제거]', text, flags=re.I)
    text = re.sub(r'https?://bit\.ly/meet[^\s<>"\u3000)]+', '[비교육 연락 경로 제거]', text, flags=re.I)
    text = re.sub(r'(비밀번호\s*[:：]?\s*)([A-Za-z0-9_-]+)', lambda m: m.group(1)+'[접속정보 제거]', text)
    return re.sub(r'https?://[^\s<>"\u3000]+', clean_url, text, flags=re.I)

def table_education(text, code, section, professor):
    text = mask_contact_context(text)
    result = BASE_TEXT_EVIDENCE(text, code, section, professor)
    safe, masked, lost = filter_education(text)
    tables = []
    for match in TABLE_START.finditer(safe):
        end = TABLE_END.search(safe, match.end())
        segment = safe[match.start():end.start() if end else min(len(safe), match.end()+24000)]
        segment = re.sub(r'\s+', ' ', segment).strip()
        if segment and segment not in tables:
            tables.append(segment)
    result['publishedEducationalHeaderRows'] = [line for line in safe.splitlines() if len(line) < 700 and re.search(r'(?:'+re.escape(code)+r'|2026|Fall|Semester|Section|Class\s*(?:Time|Meeting|Room)|\bTime\s*[:：]|\bRoom\s*[:：]|수업\s*(?:시각|시간|장소|요일)|\b(?:Monday|Tuesday|Wednesday|Thursday|Friday)\b|\d{1,2}:\d{2}\s*(?:-|–|~))', line, re.I) and not re.search(r'office\s*hours?|전화|연락처|contact|phone|fax|e-?mail', line,re.I)]
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
                    safe_rows.append([None if cell is None else filter_education(mask_contact_context(cell))[0] for cell in row])
                tables.append({'page': page_number, 'boundingBox': list(table.bbox),
                               'rows': safe_rows,
                               'cellBoundingBoxesByRow': [[None if cell is None else list(cell) for cell in row.cells] for row in table.rows]})
    result['publishedEducationalOperatingTableGeometry'] = tables
    result['rawAttachmentOrWholePagePersisted'] = False
    return result

old.pdf_evidence = geometry_pdf_evidence


BASE_DOCX_EVIDENCE = old.docx_evidence
def geometry_docx_evidence(body, code, section, professor):
    import zipfile
    from xml.etree import ElementTree as ET
    result = BASE_DOCX_EVIDENCE(body,code,section,professor)
    ns={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    with zipfile.ZipFile(io.BytesIO(body)) as archive:
        root=ET.fromstring(archive.read('word/document.xml'))
    tables=[]
    for table in root.findall('.//w:tbl',ns):
        rows=[]
        for row in table.findall('w:tr',ns):
            cells=[]
            for cell in row.findall('w:tc',ns):
                text=' '.join(''.join(n.itertext()) for n in cell.findall('w:p',ns))
                props=cell.find('w:tcPr',ns)
                merge=props.find('w:vMerge',ns) if props is not None else None
                span=props.find('w:gridSpan',ns) if props is not None else None
                cells.append({'text':filter_education(mask_contact_context(text))[0], 'verticalMerge':None if merge is None else merge.get('{'+ns['w']+'}val','continue'), 'columnSpan':1 if span is None else int(span.get('{'+ns['w']+'}val'))})
            rows.append(cells)
        if sum(bool(re.match(r'^\s*(?:W)?(?:[1-9]|1[0-6])\b',r[0]['text'])) for r in rows if r)>=3:
            tables.append({'rows':rows,'nativeXMLCellBoundariesPreserved':True})
    result['publishedEducationalOperatingTableGeometry']=tables
    return result
old.docx_evidence=geometry_docx_evidence

def main():
    targets = json.loads((P / 'incomplete-pool-classification.json').read_text())['records']
    target_codes = set(json.loads((P / 'current-incomplete-targets.json').read_text())['offeringCodes'])
    targets = [r for r in targets if r['offeringCode'] in target_codes]
    path = P / 'current-incomplete-educational-operation-recheck.json'
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
