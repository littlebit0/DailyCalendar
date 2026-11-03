"""Follow the published anonymous lecture-plan form; education-only extraction."""
import hashlib
import json
import re
import subprocess
import time
import urllib.parse
from pathlib import Path
from lxml import html
from fetch_changwon_public import clean
ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / 'public-plans-20261008'
URL = 'https://chains.changwon.ac.kr/abeek/lecture_plan/view.php'

def main():
    OUTPUT.mkdir(exist_ok=True)
    rows = json.loads((ROOT / 'changwon-current-educational-rows-20261008.json').read_text())
    unique = {(r['code'], r['section']): r for r in rows}
    closed = {(r['code'], r['section']) for r in json.loads((ROOT / 'changwon-current-closures-20261008.json').read_text())}
    audit = []
    for index, ((code, section), row) in enumerate(sorted(unique.items())):
        target = OUTPUT / f'{code}-{section}.json'
        if target.exists():
            continue
        if (code, section) in closed:
            continue
        parameters = dict(year='2026', term='2', subject_no=code, division=section, action_mode='R')
        try:
            result = subprocess.run(['curl', '--fail', '--silent', '--show-error', '--max-time', '30', '--data', urllib.parse.urlencode(parameters), URL], check=True, capture_output=True)
            document = html.fromstring(result.stdout.decode('utf-8'))
            headers = [clean(x) for x in document.xpath('//b')]
            if not any('2026 - 2 학기' in x for x in headers):
                raise ValueError('Current semester header absent')
            fields, weekly = {}, []
            for tr in document.xpath('//tr'):
                cells = [clean(x) for x in tr.xpath('./th|./td')]
                if not cells:
                    continue
                for label in ['학수번호', '분반', '교과목명', '강의시간(장소)', '강의진행방식', '수업운영방식', '비대면솔루션', '시험방식', '시험강의실', '시험일시', '시험안내사항']:
                    if label in cells and cells.index(label) + 1 < len(cells):
                        fields[label] = cells[cells.index(label) + 1]
                match = re.fullmatch(r'(\d+) 주', cells[0])
                if match:
                    weekly.append(dict(week=int(match[1]), education=cells[1:]))
                if cells == ['선수과목 및 수강필수조건']:
                    sibling = tr.getnext()
                    if sibling is not None:
                        fields['선수과목 및 수강필수조건'] = clean(sibling)
            if fields.get('학수번호') != code or fields.get('분반') != section:
                raise ValueError('Published identity differs')
            payload = dict(code=code, section=section, checkedAt='2026-10-08', sourceURL=URL, responseSHA256=hashlib.sha256(result.stdout).hexdigest(), fields=fields, weekly=weekly, completionClaim=False)
            target.write_text(json.dumps(payload, ensure_ascii=False, indent=2)+'\n')
            audit.append(dict(code=code, section=section, status='educational_saved', weeks=len(weekly)))
        except (ValueError, subprocess.CalledProcessError) as error:
            audit.append(dict(code=code, section=section, status='held', reason=type(error).__name__))
        if index % 40 == 0:
            print(f'Normal public plans {index+1}/{len(unique)}; saved {len(list(OUTPUT.glob("*.json")))}', flush=True)
            (ROOT/'changwon-plan-query-audit-20261008.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
        time.sleep(0.6)
    (ROOT/'changwon-plan-query-audit-20261008.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
    print(f'Finished {len(list(OUTPUT.glob("*.json")))} current educational plans',flush=True)
if __name__ == '__main__':
    main()
