"""Current observed public attachments, educational whitelist and no raw files."""
import datetime
import json
import re
import sys
from pathlib import Path

P = Path(__file__).resolve().parent
sys.path.insert(0, str(P.parent.parent / 'catalog-g'))
from repair_skku_inline_privacy_education import collect, old, text_evidence, filter_education

BASE_TEXT_EVIDENCE = text_evidence
TABLE_START = re.compile(r'주\s*차\s*별\s*수\s*업|수\s*업\s*내\s*용|주별\s*수업\s*계획|Class\s+Schedule|Course\s+Schedule|Tentative.{0,40}Schedule|Weekly\s+(?:Course\s+Plan|Schedule)|Course\s+Outline', re.I)
TABLE_END = re.compile(r'과\s*제\s*물|평\s*가\s*요\s*소|평\s*가\s*방\s*법|성적\s*평가|Evaluation\s+and\s+Grading|Grading\s+Policy|References|Important\s+Policies|Assessment\s+Plan|Course\s+Assessment', re.I)

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
    result['tableSectionPrivacySuppressedLineCount'] = lost
    return result

old.text_evidence = table_education
import repair_skku_inline_privacy_education as repair
repair.text_evidence = table_education


def main():
    targets = json.loads((P / 'whole-attached-pool-classification.json').read_text())['records']
    targets = [r for r in targets if r['teachingType'] == '31' and not r['completenessFlags']]
    path = P / 'current-attached-operating-table-recheck.json'
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
