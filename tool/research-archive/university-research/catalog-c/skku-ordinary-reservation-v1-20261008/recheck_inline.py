"""Recheck observed anonymous public offerings; persist educational fields only."""
import datetime
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent.parent / 'catalog-g'
sys.path.insert(0, str(SOURCE))
from probe_skku_public_educational_plan import NoSavePublic, FIELDS, params
from skku_inline_private_education_filter import filter_education


def safe_rows(rows, fields):
    result = []
    for row in rows:
        safe = {}
        lost = 0
        for field in fields:
            value, _, loss = filter_education(row.get(field, ''))
            safe[field] = value
            lost += loss
        safe['privacySuppressedLineCount'] = lost
        result.append(safe)
    return result


def main():
    targets = json.loads((HERE / 'inline-physical-shortlist.json').read_text())['shortlist']
    result = {'researchOnly': True, 'completionClaim': False,
              'checkedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'sourceUrl': 'https://kingoinfo.skku.edu/gaia/nxui/outdex.html?language=EN&menuId=NHSSU030840M',
              'anonymousPublicActionsOnly': True, 'records': [], 'stopped': False}
    destination = HERE / 'current-inline-public-recheck.json'
    if destination.exists():
        result = json.loads(destination.read_text())
        assert not result['stopped']
    done = {row['offeringCode'] for row in result['records']}
    targets = [target for target in targets if target['evidence']['offeringCode'] not in done]
    client = NoSavePublic('KO')
    try:
        for target in targets:
            row = target['evidence']['sourceRow']
            code, section = row['HAKSU_NO'], row['BUNBAN']
            detail = client.post('/E_NHSSU900011P/selectMain0', params(code, section, 'selectMain0', 'dsInfoTab01'), '', save=False)
            safe = safe_rows(detail.get('dsInfoTab01', []), FIELDS)
            detail = None
            time.sleep(.8)
            weeks = client.post('/E_NHSSU900011P/selectMain3', params(code, section, 'selectMain3', 'dsTab04'), '', save=False)
            safe_weeks = safe_rows(weeks.get('dsTab04', []), ('GAESUL_YEAR', 'GAESUL_TERM', 'HAKSU_NO', 'BUNBAN', 'PLAN_WEEK_GB', 'PLAN_WEEK_CNT', 'PLAN_WEEK_CONT', 'BIGO'))
            weeks = None
            result['records'].append({'offeringCode': code + '-' + section, 'detail': safe, 'weekly': safe_weeks})
            (HERE / 'current-inline-public-recheck.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
            time.sleep(.8)
    except Exception:
        result['stopped'] = True
        result['failure'] = 'Normal public request stopped; no retry or bypass.'
        (HERE / 'current-inline-public-recheck.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        raise SystemExit(1)
    print({'currentEducationalRecords': len(result['records']), 'stopped': result['stopped']})


if __name__ == '__main__':
    main()
