"""Read official active weekly-plan selector; alternative unused grids are not plans."""
import json
import sys
import time
from pathlib import Path

P = Path(__file__).resolve().parent
sys.path.insert(0, str(P.parent.parent / 'catalog-g'))
from probe_skku_public_educational_plan import NoSavePublic, params


def main():
    path = P / 'current-inline-public-recheck.json'
    audit = json.loads(path.read_text())
    client = NoSavePublic('KO')
    for record in audit['records']:
        if 'activeWeekType' in record:
            continue
        code, section = record['detail'][0]['HAKSU_NO'], record['detail'][0]['BUNBAN']
        group = client.post('/E_NHSSU900011P/selectMain01', params(code, section, 'selectMain01', 'dsPlanWeekGb'), '', save=False).get('dsPlanWeekGb', [])
        record['activeWeekType'] = group[0].get('PLAN_WEEK_GB') if group else None
        record['inactiveAlternativeGridCount'] = sum(w['PLAN_WEEK_GB'] != record['activeWeekType'] for w in record['weekly'])
        record['weekly'] = [w for w in record['weekly'] if w['PLAN_WEEK_GB'] == record['activeWeekType']]
        path.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
        time.sleep(.8)
    print({'activeWeekTypeVerified': len(audit['records'])})


if __name__ == '__main__':
    main()
