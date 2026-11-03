# -*- coding: utf-8 -*-
"""Compare published program slots with each institution's actual activity clocks."""
from pathlib import Path
import json
import re
from pypdf import PdfReader

ROOT = Path(__file__).parent
# Cross-reviewed institution order/names in program table pages 9–14 and
# institution proposal headers pages 15–39. Page16 continues institution A.
GROUP_PAGES = {
    'A': [15, 16], 'B': [17], 'C': [18], 'D': [19], 'E': [20],
    'F': [21], 'G': [22], 'H': [23], 'I': [24], 'J': [25], 'K': [26],
    'a': [27], 'b': [28], 'e': [29], 'k': [30], 'm': [31], 'l': [32],
    'd': [33], 'f': [34], 'h': [35], 'i': [36], 'c': [37], 'g': [38], 'j': [39],
}
reader = PdfReader(ROOT / 'kangwon-gw-current-service-guide.pdf')
programs = json.loads((ROOT / 'kangwon-gw-current-service-program-audit.json').read_text())['programRows']
output = []
for program in programs:
    prefix = program['section'][0]
    periods = sorted(int(value) for value in program['publishedPeriods'].split(','))
    if periods != list(range(periods[0], periods[-1] + 1)):
        raise ValueError('Noncontiguous published service program')
    expected_start = 480 + periods[0] * 60
    expected_end = 480 + (periods[-1] + 1) * 60
    evidence = []
    names = []
    for page in GROUP_PAGES[prefix]:
        text = reader.pages[page - 1].extract_text(extraction_mode='layout')
        for line in text.splitlines():
            if '기관명' in line and '대표자' in line:
                names.append(line.split('기관명', 1)[1].split('대표자', 1)[0].strip())
            matches = re.finditer(r'([월화수목금토일](?:\s*,\s*[월화수목금토일])*)\s+(\d{1,2}):(\d{2})\s*[~～-]\s*(\d{1,2}):(\d{2})', line)
            for match in matches:
                day, h1, m1, h2, m2 = match.groups()
                start, end = int(h1)*60+int(m1), int(h2)*60+int(m2)
                if program['publishedWeekday'] in day and (start, end) == (expected_start, expected_end):
                    evidence.append({'page': page, 'sourceActivityLine': line.strip(), 'startMinute': start, 'endMinute': end})
    output.append({
        'courseCode': program['courseCode'], 'section': program['section'],
        'institutionNameHeaders': list(dict.fromkeys(names)),
        'programPage': program['sourcePDFPage'],
        'sourceProgramText': program['sourceProgramText'],
        'weekday': '월화수목금토일'.index(program['publishedWeekday']) + 1,
        'startMinute': expected_start, 'endMinute': expected_end,
        'institutionClockEvidence': evidence, 'verified': bool(evidence),
    })
result = {
    'sourceURL': 'https://suganggw.kangwon.ac.kr/resources/file/notice/sugang_bongsa_20262.pdf',
    'courseCount': len(output), 'verifiedCount': sum(row['verified'] for row in output),
    'period': {'startDate': '2026-09-14', 'endDate': '2026-12-04'},
    'normalLectureClockNotUsedForFieldActivity': True,
    'groupPageJoinBasis': 'Published course program institution group labels and matching institution proposal names; not physical campus guessing.',
    'programRows': output,
}
(ROOT / 'kangwon-gw-service-whole-institution-clock-audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
print({'count': len(output), 'verified': result['verifiedCount'], 'unverified': [r['section'] for r in output if not r['verified']]})
