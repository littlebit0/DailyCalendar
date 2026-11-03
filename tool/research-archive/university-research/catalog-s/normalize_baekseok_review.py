"""Education-only dated conversion of the BU public-source research candidate.

This does not establish final active/room completeness or register production.
"""
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).parent


def normalize(candidate):
    result = []
    for source in candidate['courses']:
        code = source['publishedCombinedCode']
        remarks = ' / '.join(dict.fromkeys(source.get('departmentRemarks', {}).values()))
        reason = []
        # Source-only changes have a real identity, but no original attendance.
        if not source['sourceOccurrences']:
            reason.append('공식 변경표에만 존재하며 원 시간표·강의실과 최종 개설 여부 미확인')
        if re.search(r'집중이수|현장실습|임상실습', source['courseName'] + ' ' + remarks):
            reason.append('현장·임상·집중이수의 실제 출석 날짜 별도 확인 필요')
        raw = re.sub(r'\s+', '', source['sourceSchedule'])
        if re.search(r'(?<!\d)10(?!\d)', raw):
            reason.append('현재 학부 10교시의 실제 시각 미게시')
        meetings = source.get('currentSemesterActualDateReviewMeetings', [])
        if not meetings and raw not in {'사', '사이버', '-', ''}:
            reason.append('원 시간표의 실제 교시·날짜 구성을 확정할 수 없음')
        if reason:
            status = 'unrecognized'
            schedules = []
        elif meetings:
            status = 'scheduled'
            schedules = []
            for meeting in meetings:
                schedules.append({**meeting,
                                  'endMinute': ((meeting['endMinute'] + 29) // 30) * 30,
                                  'originalEndMinute': meeting['endMinute'],
                                  'deliveryMode': 'inPerson'})
        else:
            # Explicit "사" represents video-learning windows, not live clocks.
            status = 'untimed'
            schedules = []
        description = remarks
        if reason:
            description += (' / ' if description else '') + ' / '.join(reason)
        result.append({
            'sourceId': f"baekseok/{source['campus']}/2026/2/{source['courseCode']}/{source['section']}",
            'universityId': 'baekseok', 'campus': source['campus'],
            'academicYear': 2026, 'semester': '2',
            'courseCode': source['courseCode'], 'section': source['section'],
            'courseName': source['courseName'], 'credits': source['credits'],
            'professor': source['professor'], 'departments': source['departments'],
            'departmentCredits': source['departmentCredits'],
            'departmentClassifications': source['departmentClassifications'],
            'departmentRemarks': source['departmentRemarks'],
            'classification': ' / '.join(dict.fromkeys(source['departmentClassifications'].values())),
            'remarks': description, 'sourceSchedule': source['sourceSchedule'],
            'sourceClassroom': source['sourceClassroom'],
            'scheduleStatus': status, 'schedules': schedules,
        })
    counts = dict(Counter(row['scheduleStatus'] for row in result))
    return {'schemaVersion': 2, 'universityId': 'baekseok', 'academicYear': 2026,
            'semester': '2', 'productionReady': False, 'completionClaim': False,
            'finalActiveScopeVerified': False, 'finalRoomChangesVerified': False,
            'clockEvidence': '2026-2 undergraduate contract clock periods 1–9, exact current general-course crosscheck; broader scope review remains',
            'counts': counts, 'courses': result}


if __name__ == '__main__':
    candidate = json.loads((ROOT/'bu-current-whole-candidate-unregistered.json').read_text())
    result = normalize(candidate)
    (ROOT/'bu-dated-normalized-review-unregistered.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(len(result['courses']), result['counts'])
