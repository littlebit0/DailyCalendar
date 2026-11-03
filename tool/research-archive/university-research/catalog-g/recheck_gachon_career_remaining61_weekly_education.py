"""Narrow official public career-plan recheck; retain only education weekly activity."""
import importlib.util
import io
import json
import re
import time
from pathlib import Path
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('gachon_public_existing', ROOT / 'audit_gachon_full_operating_reports.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
original_parser = mod.parse_report
captured = {}


def education_parser(data, row):
    parsed = original_parser(data, row)
    if not all(parsed['report'][key] for key in ['headerCourseCodeMatches', 'currentTermMatches', 'catalogProfessorAppearsInReport']):
        raise RuntimeError('Current public report identity mismatch; stopping')
    text = '\n'.join(page.extract_text() or '' for page in PdfReader(io.BytesIO(data)).pages)
    heading = re.search(r'주차\s*기\s*간', text)
    if not heading:
        raise RuntimeError('Expected current weekly education table absent')
    section = text[heading.end():]
    section = re.sub(r'(?m)^.*(?:교과목명|강의시간|Date\s*:|주차\s*기\s*간).*$','', section)
    matches = list(re.finditer(r'(?m)^\s*(\d{1,2})\s+(\d{2}/\d{2})\s*~\s*(\d{2}/\d{2})', section))
    rows = []
    for index, match in enumerate(matches):
        activity = section[match.end():matches[index + 1].start() if index + 1 < len(matches) else len(section)]
        lines = [line.strip() for line in activity.splitlines() if line.strip() and not mod.PRIVATE.search(line) and not re.search(r'SSU\d+R|Page\s*:', line)]
        safe = ' '.join(lines)
        if len(safe) > 1500:
            raise RuntimeError('Weekly education activity exceeds safe limit; review before collection')
        rows.append({'week': int(match[1]), 'startMonthDay': match[2], 'endMonthDay': match[3], 'educationalActivity': safe})
    captured[row['HAKSU_NO']] = {'reportIdentity': parsed['report'], 'teachingMethodEducationalExcerpt': parsed['teachingMethodEducationalExcerpt'], 'weeklyEducationRows': rows}
    del text, section, data
    return parsed


def main():
    mod.parse_report = education_parser
    reviews = json.loads((ROOT / 'gachon-full-operating-semantic-review.json').read_text())['rows']
    keys = {(r['campus'], r['officialOfferingCode']) for r in reviews if r['decision'] == 'ordinary-conditional-or-individual-operating-method-unresolved' and r['officialOfferingCode'][:5] == '13129'}
    previous = {(r['campus'],r['sourceRow']['HAKSU_NO']):r['sourceRow'] for r in json.loads((ROOT/'gachon-full-operating-report-audit.json').read_text())['reports']}
    items = []
    query_proofs = []
    for campus in ['20','21']:
        query = {'groupType':campus,'searchYear':'2026','searchTerm':'20','searchUnivCD':'','searchDeptCD':'','searchIsuCD':'001','searchGrade':'','searchSubjectNm':'취·창업 진로세미나'}
        response = mod.request(mod.HOST + '/Ssu1000q/mainSearch.do', json.dumps({'data':{'SendData':query}}).encode(), {**mod.HEAD,'Content-Type':'application/json;charset=UTF-8','Referer':mod.HOST+'/ssu/showTimetable.do'})
        parsed = json.loads(response)
        public_rows = parsed.get('MainData')
        assert isinstance(public_rows,list) and len(public_rows) == int(parsed['dmRowCnt']['rowCnt'])
        query_proofs.append({'campus':campus,'publishedSubjectNameSearch':query['searchSubjectNm'],'returnedCount':len(public_rows)})
        for row in public_rows:
            key = (campus,row['HAKSU_NO'])
            if key in keys:
                assert all(row.get(k) == previous[key].get(k) for k in mod.PUBLIC)
                items.append({'campus':campus,'category':'001','row':row})
        del parsed, public_rows, response
        time.sleep(1)
    assert len(items) == len(keys) == 61
    out = ROOT / 'gachon-career61-current-weekly-education-recheck-next-20261008.json'
    assert not out.exists()
    result = {'researchOnly': True, 'completionClaim': False, 'expectedCount': 61, 'source': 'Existing observed normal public ReportingServer export via current official public course identifiers; no account login', 'rawReportPersisted': False, 'personalIdentifierPersisted': False, 'rows': [], 'stopped': False, 'freshNarrowPublicQueries':query_proofs, 'internalReportIdentifierHandling':'Read only in transient published response for normal official report request, never stored or output'}
    try:
        for item in items:
            started = time.monotonic()
            code = item['row']['HAKSU_NO']
            record = mod.fetch_report((item['campus'], item['category'], item['row']))
            if code not in captured:
                raise RuntimeError('Current public report not returned; stopping without bypass')
            result['rows'].append({'campus': item['campus'], 'offering': code, 'title': item['row']['SUBJECT_NM_KOR'], **captured.pop(code)})
            del record
            out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
            if len(result['rows']) % 20 == 0:
                print(json.dumps({'educationReportsRead': len(result['rows']), 'expected': 61}), flush=True)
            time.sleep(max(0, 1.0 - (time.monotonic() - started)))
    except Exception as error:
        result['stopped'] = True
        result['failureType'] = type(error).__name__
        out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        raise RuntimeError('Narrow public recheck stopped; no bypass or automatic retries') from None
    print(json.dumps({'educationReportsRead': len(result['rows']), 'complete': len(result['rows']) == 61}), flush=True)

if __name__ == '__main__':
    main()
