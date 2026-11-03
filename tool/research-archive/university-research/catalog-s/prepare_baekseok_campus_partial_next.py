# coding: utf-8
"""Immutable actual-source campus split; no inferred campus assignment."""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).parent
SOURCE = 'bu-current-whole-ordinary-app-notes-next-20261008.json'


def sha(name):
    return hashlib.sha256((ROOT / name).read_bytes()).hexdigest()


def prepare():
    whole = json.loads((ROOT / SOURCE).read_text())
    manifest = {'wholeCandidate': SOURCE, 'wholeCandidateSHA256': sha(SOURCE),
                'productionReady': False, 'completionClaim': False,
                'sourceOverlayDate': '2026-08-31',
                'sourceOverlayDateMeaning': 'Latest dated current clock/change evidence, not new whole-package upload date.',
                'files': []}
    for campus in ['cheonan', 'unknown']:
        result = copy.deepcopy(whole)
        result.update({'campus': campus,
                       'publishedDate': '2026-08-31',
                       'sourceUrl': 'https://www.bu.ac.kr/sites/web/intro/2026_2.html',
                       'courses': [row for row in whole['courses'] if row['campus'] == campus]})
        result['counts'] = {status: sum(row['scheduleStatus'] == status for row in result['courses'])
                            for status in ['scheduled', 'unscheduled', 'unrecognized']}
        name = f'baekseok-{campus}-2026-2.ordinary-app-notes-next.json'
        text = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
        file = ROOT / name
        if file.exists():
            assert file.read_text() == text, 'Immutable campus candidate bytes differ'
        else:
            file.write_text(text)
        manifest['files'].append({'filename': name, 'sha256': sha(name),
                                  'courseCount': len(result['courses']), 'counts': result['counts']})
    assert sum(row['courseCount'] for row in manifest['files']) == 2571
    (ROOT / 'bu-campus-ordinary-app-notes-next-manifest-20261008.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == '__main__':
    prepare()
