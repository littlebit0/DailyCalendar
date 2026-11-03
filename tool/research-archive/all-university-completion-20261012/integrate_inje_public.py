"""Integrate a finished anonymous undergraduate source packet without guessing clocks."""
import copy
import hashlib
import json
import re
from collections import defaultdict
from pathlib import Path

BASE = Path('work/all-university-completion-20261012')
SOURCE = Path('work/full-timetable-audit-20261012/inje-full-a')
FINAL = SOURCE / 'final-source-packet.json'


def read(path):
    return json.loads(path.read_text())


def parse_schedule(raw, clock):
    """Only fully transcribed native day/period/room grammar is eligible."""
    raw = raw.strip()
    if not raw:
        return [], 'unscheduled', 'No published weekly time'
    pattern = r'(?:[월화수목금토일]\d+(?:,\d+)*)+'
    parts = re.fullmatch(r'(' + pattern + r'(?:/' + pattern + r')*)\s+(.+)', raw)
    if not parts:
        return [], 'unrecognized', 'Native schedule grammar requires source review'
    time_parts, room_parts = parts[1].split('/'), parts[2].split('/')
    if len(room_parts) == 1:
        room_parts *= len(time_parts)
    if len(room_parts) != len(time_parts):
        return [], 'unrecognized', 'Published period and room groups do not align'
    result = []
    for times, room in zip(time_parts, room_parts):
        for group in re.finditer(r'([월화수목금토일])(\d+(?:,\d+)*)', times):
            periods = [int(part) for part in group[2].split(',')]
            if len(periods) != len(set(periods)) or periods != sorted(periods):
                return [], 'unrecognized', 'Native period order is not a unique ascending sequence'
            if any(str(period) not in clock for period in periods):
                return [], 'unrecognized', 'No official undergraduate absolute clock for every period'
            blocks = []
            for period in periods:
                slot = clock[str(period)]
                start, end = slot['startMinute'], slot['endMinute']
                if not 0 <= start < end <= 1440:
                    raise ValueError('Invalid official clock interval')
                if blocks and period == blocks[-1][2] + 1:
                    blocks[-1] = (blocks[-1][0], end, period)
                else:
                    blocks.append((start, end, period))
            for start, end, _ in blocks:
                result.append({'weekday': '월화수목금토일'.index(group[1]) + 1,
                               'startMinute': start, 'endMinute': end,
                               'classroom': room.strip()})
    return result, 'scheduled', ''


def main():
    packet = read(FINAL)
    if packet.get('final') is not True:
        raise SystemExit('Source processing must finish before integration')
    list_path = SOURCE / 'inje-native-all-public-rows.json'
    if packet['nativeListSha256'] != hashlib.sha256(list_path.read_bytes()).hexdigest():
        raise SystemExit('Source list changed after finalization')
    grouped = defaultdict(list)
    for row in read(list_path):
        if row['year'] != 2026 or row['semester'] != 'second' or row['level'] != 'undergraduate':
            raise SystemExit('Wrong native term or degree scope')
        grouped[row['교과목'], row['분반']].append(row)
    if len(grouped) != 1756:
        raise SystemExit('Actual published unique identity count changed')
    clock_packet_path = SOURCE / 'undergraduate-clock-proof.json'
    clock_packet = read(clock_packet_path) if clock_packet_path.exists() else {}
    clock = clock_packet.get('periods', {}) if clock_packet.get('final') is True else {}
    # An explicitly scoped clock is never transferred to unrelated degree units.
    if clock and clock_packet.get('scope') != 'allUndergraduate':
        raise SystemExit('Limited undergraduate clock needs course-specific application')
    supplements = {(r['code'], r['section']): r for r in packet.get('approvedPdfSupplements', [])}
    new = []
    held_reports = []
    for (code, section), rows in grouped.items():
        first = rows[0]
        for field in ('교과목명', '학점', '담당교수'):
            if len({row[field] for row in rows}) != 1:
                raise SystemExit(f'Unadjudicated identity conflict: {code}-{section} {field}')
        reports = SOURCE / 'report-fields' / f'{code}-{section}.json'
        report = read(reports) if reports.exists() else {}
        info = report.get('courseInformation', {})
        verified_report = (not report.get('error') and report.get('returncode') == 0
                           and info.get('교과목번호') == code and info.get('분반') == section
                           and info.get('과정') == '학사과정'
                           and report.get('title') == '2026학년도 2학기 수업계획서')
        if report and not verified_report:
            held_reports.append({'code': code, 'section': section,
                                 'reason': 'Report identity/degree/term is missing or conflicting'})
        supplement = supplements.get((code, section), {})
        schedule = info.get('수업시간강의실', '') if verified_report else supplement.get('sourceSchedule', '')
        schedules, status, held_reason = parse_schedule(schedule, clock)
        if verified_report and info.get('집중이수강좌여부') == '1':
            schedules, status, held_reason = [], 'unrecognized', 'Concentrated course has no exact published teaching date range'
        # The list describes actual query association, not professor ownership.
        categories_by_department = defaultdict(set)
        for row in rows:
            for label in filter(None, (part.strip() for part in row['개설학과'].split(','))):
                categories_by_department[label].add(row['이수구분'])
        categories = list(dict.fromkeys(row['이수구분'] for row in rows))
        category = categories[0] if len(categories) == 1 else ''
        credits = float(first['학점']) if first['학점'] else None
        departments = list(categories_by_department)
        remarks = []
        if held_reason:
            remarks.append('공개 원문 교시와 강의실을 유지합니다. 확인되지 않은 실제 시간은 추정하지 않습니다.')
        if verified_report:
            for label in ('수강대상', '수강제한', '수업방식_전체'):
                if info.get(label):
                    remarks.append(f'{label}: {info[label]}')
        if supplement:
            remarks.append('현재 공개 목록과 일치하는 이전 공식 시간표의 수업시간을 보충했습니다. 이후 학교 변경사항은 수업계획서에서 확인해 주세요.')
        course = {
            'sourceId': f'inje/unknown/2026-2/navi/{code}-{section}',
            'universityId': 'inje', 'campus': 'unknown', 'academicYear': 2026,
            'semester': '2', 'courseCode': code, 'section': section,
            'courseName': first['교과목명'], 'professor': first['담당교수'],
            'credits': credits, 'classification': category, 'departments': departments,
            'departmentCredits': {label: credits for label in departments} if credits is not None else {},
            'departmentClassifications': {label: next(iter(values)) if len(values) == 1 else ''
                                          for label, values in categories_by_department.items()},
            'departmentRemarks': {}, 'schedules': schedules, 'scheduleStatus': status,
            'sourceSchedule': schedule, 'sourceClassroom': '', 'remarks': ' '.join(remarks),
            'sourceUrl': first['sourceUrl'], 'sourceRows': [row['sourceRow'] for row in rows],
            'nativeClassificationVariants': categories, 'nativeQueryAssociationOnly': True,
            'nativeCampusPublished': False,
            'period': {'startDate': '2026-09-01', 'endDate': '2026-12-21'},
            'periodSourceUrl': 'https://www.inje.ac.kr/kor/setRoute/B_Page.asp?pCode=IF010010000&viewType=vy&setYear=2026',
            'sourceLocator': {'nativeListSha256': packet['nativeListSha256'],
                              'nativeRows': [row['sourceRow'] for row in rows]},
        }
        if all(value in ('전필', '전선', '전기') for value in categories):
            course['classificationGroup'] = '전공'
        if verified_report:
            course['sourceLocator']['reportSha256'] = report['sha256']
            course['reportSourceUrl'] = report['sourceUrl']
            course['nativeTeachingMethod'] = info.get('수업방식_전체', '')
            course['nativeConcentratedCourse'] = info.get('집중이수강좌여부', '')
        if supplement:
            course['sourceLocator']['pdfSupplement'] = supplement
        new.append(course)
    path = Path('assets/timetable/inje-unknown-2026-2.json')
    if path.exists():
        raise SystemExit('Already integrated; update using a reviewed exact correction, not duplicate insertion')
    data = {'schemaVersion': 1, 'universityId': 'inje', 'campus': 'unknown',
            'campusName': '캠퍼스 미확인', 'academicYear': 2026, 'semester': '2',
            'publishedDate': '2026-10-12', 'sourceUrl': 'https://navi.inje.ac.kr/AllUsers/Lecture.aspx',
            'sourceNotice': '공식 공개 학부 개설강좌 전체 조회 자료입니다. 원문에 없는 캠퍼스·교시 시간은 추정하지 않습니다.',
            'courses': new, 'wholeOperatingVerified': False}
    affiliation_path = BASE / 'inje-full-confirmed-affiliations-b.json'
    affiliations = read(affiliation_path)
    if affiliations.get('final') is not True or affiliations.get('unresolved'):
        raise SystemExit('Official educational-unit classification remains open')
    native_labels = {label for course in new for label in course['departments']}
    units = []
    for entry in affiliations['entries']:
        if entry['sourceLabel'] not in native_labels:
            raise SystemExit('Affiliation is not an actual native query label')
        unit = {key: copy.deepcopy(entry[key]) for key in (
            'campus', 'sourceLabel', 'department', 'college', 'group',
            'officialGroups', 'officialSystem', 'officialSystems',
            'officialAcademicParent', 'sourceUrl', 'sourceFile', 'evidence',
        ) if key in entry}
        unit.update({'isOfferingUnit': False, 'collegeOnlyEligible': False,
                     'collegeKnown': unit.get('college') is not None,
                     'affiliationStatus': 'officialProgramSystem'
                     if entry['kind'] == 'officialProgramSystem' else 'verified'})
        units.append(unit)
    administrative_labels = {label for target in affiliations['administrativeTargets']
                             for label in target['nativeVariants']}
    if native_labels != {unit['sourceLabel'] for unit in units} | administrative_labels:
        raise SystemExit('Not every actual native association is adjudicated')
    organization_path = Path('assets/timetable/organizations/inje.json')
    organization = read(organization_path)
    if any(unit['sourceLabel'] in native_labels for unit in organization['mappings']):
        raise SystemExit('Existing native affiliation needs a reviewed merge')
    organization_backup = BASE / 'inje-organizations-before-public.json'
    if not organization_backup.exists():
        organization_backup.write_bytes(organization_path.read_bytes())
    organization['mappings'].extend(units)
    catalog_path = Path('assets/timetable/catalog.json')
    catalog = read(catalog_path)
    backup = BASE / 'catalog-before-inje-public.json'
    if not backup.exists():
        backup.write_bytes(catalog_path.read_bytes())
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    catalog.append(str(path))
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
    organization_path.write_text(json.dumps(organization, ensure_ascii=False, indent=2) + '\n')
    receipt = {'verificationPending': True, 'wholeUniversityCompletion': False,
               'addedNativeOfferings': len(new), 'originalGlobalbizOfferingsPreserved': 16,
               'scheduled': sum(bool(row['schedules']) for row in new),
               'heldReportIdentities': held_reports, 'sourcePacket': str(FINAL),
               'sourcePacketSha256': hashlib.sha256(FINAL.read_bytes()).hexdigest(),
               'schools': [{'university': 'inje', 'mappings': len(units), 'ownerUnits': 0}],
               'affiliationPacketSha256': hashlib.sha256(affiliation_path.read_bytes()).hexdigest(),
               'clockProof': str(clock_packet_path) if clock else None}
    (BASE / 'inje-public-integration-receipt.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    print(receipt)


if __name__ == '__main__':
    main()
