#!/usr/bin/env python3
"""Parse public CAU undergraduate course menu responses, without student data.

Official period reference: https://cse.cau.ac.kr/file/2026_haksa_guide.pdf
Numeric periods are 50 minutes, starting 09:00 Seoul / 09:30 Davinci.
The public menu also publishes late periods 13/14; extend the same hourly
cadence from the guide (13 = 21:00 Seoul, 14 = 22:00), bounded to these
actually observed periods and checked to remain within the same day.
The public menu's Term3/4 teaching dates are persisted for calendar projection.
"""
import argparse
from decimal import Decimal
import html
import json
from pathlib import Path
import re

DAYS = '월화수목금토일'
FLEX = {'Term3': {'startDate': '2026-09-01', 'endDate': '2026-10-26'},
        'Term4': {'startDate': '2026-10-27', 'endDate': '2026-12-21'}}


def meetings(text, campus):
    text = html.unescape(text or '').strip()
    if not text.replace('/', '').strip():
        return [], 'unscheduled'
    if campus not in ['1', '2']:
        raise ValueError('Unknown CAU teaching campus')
    time_parts, room_parts = [], []
    for part in re.split(r'\s+/\s+', text):
        part = part.strip()
        if not part:
            continue
        if part[0] in DAYS:
            time_parts.extend(re.split(r',\s*(?=[월화수목금토일])', part))
        else:
            room_parts.append(part)
    # The public menu joins all times and all rooms into separate strings.
    # Keep that complete room list rather than invent an association.
    classroom = ' / '.join(room_parts)
    result = []
    for part in time_parts:
        match = re.fullmatch(r'([월화수목금토일])(?:\(?(\d{2}):(\d{2})~(\d{2}):(\d{2})\)?|([0-9A-H,]+))', part)
        if not match:
            return [], 'unparsed'
        if match[2] is not None:
            if int(match[3]) > 59 or int(match[5]) > 59:
                raise ValueError('Invalid CAU clock minute')
            times = [(int(match[2])*60+int(match[3]), int(match[4])*60+int(match[5]))]
        else:
            base = 540 if campus == '1' else 570
            times = []
            for period in match[6].split(','):
                if period in 'ABCDEFGH':
                    start = base + 'ABCDEFGH'.index(period)*90
                    end = start + 75
                elif re.fullmatch(r'\d{1,2}', period) and 0 <= int(period) <= 14:
                    start = base + (int(period)-1)*60
                    end = start+50
                else:
                    return [], 'unparsed'
                times.append((start, end))
        for start, end in times:
            if not 0 <= start < end <= 1440:
                raise ValueError('Invalid CAU teaching interval')
            result.append({'weekday': DAYS.index(match[1])+1, 'startMinute': start, 'endMinute': end, 'classroom': classroom})
    merged = []
    for meeting in sorted(result, key=lambda r: (r['weekday'], r['classroom'], r['startMinute'])):
        previous = merged[-1] if merged else None
        if previous and previous['weekday'] == meeting['weekday'] and previous['classroom'] == meeting['classroom'] and previous['endMinute'] <= meeting['startMinute'] <= previous['endMinute']+10:
            previous['endMinute'] = meeting['endMinute']
        elif meeting not in merged:
            merged.append(meeting)
    return merged, 'scheduled' if merged else 'unparsed'


def parse_rows(rows, year, semester):
    result = {}
    for row in rows:
        if row.get('shtm') != semester or row.get('corscd') != '학사':
            raise ValueError('Wrong CAU course term or programme')
        campus = row['campcd']
        code, section, title = (row.get(k) for k in ['sbjtno', 'clssno', 'clssnm'])
        if campus not in ['1','2'] or not all(isinstance(v,str) and v.strip() for v in [code,section,title]):
            raise ValueError('Invalid CAU course identity')
        # Public menu includes classes already closed by the university.
        if row.get('clsefg') == '폐강':
            continue
        if row.get('clsefg') not in [None, '']:
            raise ValueError('Unknown CAU closure marker')
        name = 'seoul' if campus == '1' else 'davinci'
        offering_department = row.get('sust')
        if not isinstance(offering_department, str) or not offering_department:
            raise ValueError('Missing CAU offering department identity')
        identity = f'cau/{name}/{year}/{semester}/{offering_department}/{code}/{section}'
        department = row.get('sustnm') or row.get('colgnm')
        if not department:
            raise ValueError('Missing CAU offering department')
        credit_match = re.fullmatch(r'((?:\d+(?:\.\d+)?|\.\d+))-((?:\d+(?:\.\d+)?|\.\d+))', row.get('pnt') or '')
        if not credit_match:
            raise ValueError('Invalid CAU credits')
        credits = float(Decimal(credit_match[1]))
        schedule = html.unescape(row.get('ltbdrm') or '')
        parsed, status = meetings(schedule, campus)
        remarks = '\n'.join(html.unescape(str(v)) for v in [row.get('remk'),row.get('usktp'),row.get('flx')] if v)
        current = {'sourceId':identity,'universityId':'cau','campus':name,'academicYear':year,'semester':semester,
            'courseCode':code,'section':section,'courseName':title,'professor':row.get('profnm') or '',
            'credits':credits,'sourceSchedule':schedule,'sourceClassroom':' / '.join(dict.fromkeys(m['classroom'] for m in parsed if m['classroom'])),
            'scheduleStatus':status,'schedules':parsed,'departments':[department],
            'departmentCredits':{department:credits},'departmentClassifications':{department:row.get('pobtnm') or ''},
            'departmentRemarks':{department:remarks}}
        if row.get('flx'):
            if year != 2026 or semester != '2' or row['flx'] not in FLEX:
                raise ValueError('Unverified CAU flexible teaching period')
            current['period'] = FLEX[row['flx']]
        previous = result.get(identity)
        if previous is None:
            result[identity] = current
        else:
            for field in ['courseName','professor','schedules','period','credits']:
                if previous.get(field) != current.get(field):
                    raise ValueError(f'Conflicting CAU offering {identity}: {field}')
            if department not in previous['departments']:
                previous['departments'].append(department)
            for field in ['departmentCredits','departmentClassifications','departmentRemarks']:
                previous[field].update(current[field])
    if not result:
        raise ValueError('Empty CAU catalog')
    return list(result.values())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--raw', type=Path, required=True)
    args = parser.parse_args()
    # Verify every published college/department response has its course query.
    for campus in ['1', '2']:
        colleges = json.loads((args.raw/f'campus-{campus}.json').read_text())['selectColg']
        codes = {r['deptcd'] for r in colleges} | {'LNK', 'FSN'}
        for code in codes:
            depts = json.loads((args.raw/f'departments-{campus}-{code}.json').read_text())['selectSust']
            for dept in depts:
                if not (args.raw/f"courses-{campus}-{code}-{dept['deptcd']}.json").is_file():
                    raise ValueError('Incomplete published CAU filter coverage')
    files = sorted(args.raw.glob('courses-*.json'))
    rows = [r for path in files for r in json.loads(path.read_text())['selectSust']]
    courses = parse_rows(rows, 2026, '2')
    for campus in ['seoul','davinci']:
        selected = [r for r in courses if r['campus']==campus]
        target = Path(f'assets/timetable/cau-{campus}-2026-2.json')
        target.write_text(json.dumps({'schemaVersion':1,'publishedDate':'2026-10-06','universityId':'cau','campus':campus,'academicYear':2026,'semester':'2',
            'sourceUrl':'https://mportal.cau.ac.kr/std/usk/sUskSif001/search.do','courses':selected},ensure_ascii=False,indent=2)+'\n')
        print(campus,len(selected),{status:sum(c['scheduleStatus']==status for c in selected) for status in ['scheduled','unscheduled','unparsed']})


if __name__ == '__main__':
    main()
