"""Read actual code-bearing blocks in the published 2026-08-31 change table."""
import json
import re
from pathlib import Path
ROOT = Path(__file__).parent


def extract(tables):
    result = []
    for table in tables:
        blocks = []
        for row in table['rows'][2:]:
            if row[0] and row[0] in {'핵심', '응용', '기초', '교양', '심화'}:
                blocks.append([])
            if blocks:
                blocks[-1].append(row)
        for block in blocks:
            values = []
            for col in range(12):
                unique = list(dict.fromkeys(r[col] for r in block if r[col]))
                values.append(' '.join(unique))
            if not re.fullmatch(r'\d{7}', values[3]):
                raise ValueError('Invalid published change identity')
            result.append(dict(zip(['classification', 'faculty', 'department', 'combinedCode',
                                   'courseName', 'credits', 'hours', 'previousSchedule',
                                   'newSchedule', 'previousProfessor', 'newProfessor', 'remarks'], values),
                               source='bu-current-changes-20260831.pdf', page=table['page']))
    return result


if __name__ == '__main__':
    records = extract(json.loads((ROOT/'bu-current-changes-20260831.tables.json').read_text()))
    (ROOT/'bu-current-full-change-records.json').write_text(json.dumps(records, ensure_ascii=False, indent=2)+'\n')
    print(len(records), 'actual current change records')
