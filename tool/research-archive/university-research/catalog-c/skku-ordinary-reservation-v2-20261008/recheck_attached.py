"""Current observed public attachments, educational whitelist and no raw files."""
import datetime
import json
import sys
from pathlib import Path

P = Path(__file__).resolve().parent
sys.path.insert(0, str(P.parent.parent / 'catalog-g'))
from repair_skku_inline_privacy_education import collect, old


def main():
    targets = json.loads((P / 'attached-semantic-review-checkpoint.json').read_text())['records']
    path = P / 'current-attached-public-recheck.json'
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
