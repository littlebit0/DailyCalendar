import hashlib
import json
import re
from collections import defaultdict
from pathlib import Path

from pypdf import PdfReader

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
SOURCE = Path('/private/tmp/jbnu-major-355180-v4.pdf')
OLD = OUT.parent / 'jbnu-current-20261008'
CURRENT = ROOT / 'assets/timetable/jbnu-unknown-2026-2.json'
COLUMNS = [(0, 77, 'grade'), (77, 128, 'classification'),
           (128, 326, 'courseTitle'), (326, 369, 'sectionOrCertification'),
           (369, 412, 'creditsOrPublishedHours'), (412, 498, 'professor'),
           (541, 583, 'nativeLectureLanguageColumn'),
           (583, 842, 'classroomOrNativeDayPeriods')]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def normalize(value):
    return re.sub(r'\s+', '', value or '')


def main():
    inputs = sorted(OLD.glob('*current-metadata-20261008.json'))
    inputs.append(OLD / 'jbnu-unknown-medical-document-2026-2.published-partial-20261008.json')
    inputs.append(CURRENT)
    before = {str(path.relative_to(ROOT)): sha(path) for path in inputs}
    native = [row for path in inputs[:6] for row in json.loads(path.read_text())['courses']]
    assert len(native) == 3571
    reader = PdfReader(SOURCE)
    assert len(reader.pages) == 309
    assert sha(SOURCE) == 'bd8f8f3ca03705c680e5bb1c11bbd0224833a4a243b1889406f09c503d3a12e0'
    pages = []
    first_fragments = None
    clock_hits = []
    image_hashes = defaultdict(list)
    for index, page in enumerate(reader.pages, 1):
        fragments = []

        def visitor(text, cm, tm, font, size):
            x, y = round(tm[4], 2), round(tm[5], 2)
            if text.strip() and y >= 50 and not 498 <= x < 541:
                for left, right, column in COLUMNS:
                    if left <= x < right:
                        fragments.append((x, y, column, text))
                        break

        page.extract_text(visitor_text=visitor)
        for image in page.images:
            image_hashes[hashlib.sha256(image.data).hexdigest()].append(index)
        cells = defaultdict(list)
        for x, y, column, text in fragments:
            cells[(y, column)].append((x, text))
        lines = [{'sourceY': y, 'column': column,
                  'sourceText': ''.join(text for x, text in sorted(glyphs)),
                  'sourceXStart': min(x for x, text in glyphs)}
                 for (y, column), glyphs in cells.items()]
        lines.sort(key=lambda row: (-row['sourceY'], row['sourceXStart']))
        for line in lines:
            if re.search(r'\d{1,2}:\d{2}', line['sourceText']):
                clock_hits.append({'page': index, **line})
        pages.append({'pdfPage': index, 'educationalColumnLines': lines,
                      'officialCodeColumnPublished': False})
        if index == 1:
            first_fragments = fragments
    assert not clock_hits
    first_cells = defaultdict(list)
    for x, y, column, text in first_fragments:
        first_cells[(y, column)].append((x, text))
    first_lines = [(y, column, ''.join(text for x, text in sorted(glyphs)))
                   for (y, column), glyphs in first_cells.items()]
    anchors = sorted([y for y, column, text in first_lines
                      if column == 'sectionOrCertification' and text.strip().isdigit()], reverse=True)
    assert len(anchors) == 10
    sample_rows = []
    for index, anchor in enumerate(anchors, 1):
        row_cells = defaultdict(list)
        for y, column, text in first_lines:
            if anchor - 28 < y <= anchor + 3:
                row_cells[column].append((y, text))
        values = {column: [text for y, text in sorted(lines, reverse=True)]
                  for column, lines in row_cells.items()}
        title = ''.join(values['courseTitle'])
        section = values['sectionOrCertification'][0]
        professor = ''.join(values['professor'])
        room = values['classroomOrNativeDayPeriods'][0]
        schedule = ''.join(values['classroomOrNativeDayPeriods'][1:])
        matches = [row for row in native if
                   normalize(row['courseName']) == normalize(title) and
                   str(row['section']) == section and
                   normalize(row['professor']) == normalize(professor) and
                   normalize(row['sourceClassroom']) == normalize(room) and
                   normalize(row['sourceSchedule']) == normalize(schedule)]
        sample_rows.append({'documentLocator': f'attachment355180/page1/row{index}',
                           'printedEducationalColumns': values,
                           'courseCodePublished': False,
                           'wholeNativeCorroborationMatches': [
                               {'sourceId': row['sourceId'], 'courseCode': row['courseCode'],
                                'section': row['section'], 'campus': row['campus']}
                               for row in matches],
                           'officialCodeJoinProven': False,
                           'newScheduleEligible': False})
    assert len(image_hashes) == 2 and all(len(occurrences) == 309 for occurrences in image_hashes.values())
    before_after = {str(path.relative_to(ROOT)): sha(path) for path in inputs}
    assert before == before_after
    current = json.loads(CURRENT.read_text())
    assert len(current['courses']) == 33
    assert sum(bool(row['schedules']) for row in current['courses']) == 18
    assert sum(len(row['schedules']) for row in current['courses']) == 1098
    education = {'sourceUrl': 'https://stat.jbnu.ac.kr/bbs/stat/834/355180/download.do',
                 'sourceSHA256': sha(SOURCE), 'sourceBytes': SOURCE.stat().st_size,
                 'nativeTitle': '2026년도 2학기 수업시간표_(전공).pdf',
                 'pages': pages, 'columnExtractionScope': COLUMNS,
                 'excludedFields': ['capacity column498–541', 'footer below sourceY50 including internal report identifier/address and generation timestamp'],
                 'schemaNote': 'Original educational column text by page/sourceY, not manufactured course rows or inferred official codes. Whitespace between separate glyphs is not semantic classroom/course-code assignment.',
                 'wholeCurrentOfferingCoverageComplete': False}
    (OUT / 'major309-page-published-education.json').write_text(json.dumps(education, ensure_ascii=False, indent=2) + '\n')
    proof = {'normalPublicDownloadHTTP': 200, 'observedOfficialNotice': 'https://stat.jbnu.ac.kr/bbs/stat/834/396264/artclView.do',
             'attachmentURL': education['sourceUrl'], 'sourceSHA256': sha(SOURCE),
             'sourceBytes': SOURCE.stat().st_size, 'pdfPages': 309,
             'sourceSnapshotPublishedDate': '2026-07-15',
             'sourceWarning': '시간표 및 수업정보는 주관 학과의 방침에 따라 변동되므로 수강신청 전 개설강좌보기의 최종 수업시간표 확인',
             'all309EducationHHHits': clock_hits, 'newPublishedClock': 0,
             'imageAudit': {'totalImageOccurrences': sum(len(occurrences) for occurrences in image_hashes.values()),
                            'uniqueImageSHA256': dict(image_hashes),
                            'actualVisualInterpretation': 'University logo and logo mask only, both155x36; each repeated on all309pages. No image clock chart.'},
             'page1VisuallyReviewed': True, 'page1SampleEducationalRows': sample_rows,
             'sampleExactFiveFieldCorroborationCount': sum(len(row['wholeNativeCorroborationMatches']) == 1 for row in sample_rows),
             'officialCodeJoinProvenCount': 0,
             'unmatchedPage1Row': {'title': '데이터통신', 'printedSection': '1',
                                   'printedProfessor': '최선오',
                                   'reason': 'No same normalized title+section in current3571 metadata. Not classified as closed or assigned a guessed code.'},
             'frozenCurrentInputSHA256BeforeAndAfter': before,
             'preservedNativeMetadata': 3571, 'preservedCurrentDocumentCourses': 33,
             'preservedScheduledCourses': 18, 'preservedDatedMeetings': 1098,
             'newScheduledCandidates': 0,
             'independentFutureValidationPlan': 'Need current own undergraduate A/B starts/ends or course-specific direct HH plus authoritative native identity. Match code-section/campus/professor/room and operating restrictions against exact current rows; preserve every previous whole object and verify literal own dates and three-mode/full Drive only after valid schedules exist.',
             'remainingGap': 'This whole-major snapshot supplies printed sections/teacher/room/numericA-B but no official code column and no HH start/end. Medical33 must not be title-only merged into3571. Current late changes/closure native joins and specific medical-campus allocation remain unresolved.',
             'sdkUsed': False, 'productChanged': False, 'completionClaim': False, 'impossibleClaim': False}
    (OUT / 'major309-page-clock-and-native-identity-proof.json').write_text(json.dumps(proof, ensure_ascii=False, indent=2) + '\n')
    print(f'PASS309pages/HH0; page1 ten exactfield corroborations={proof["sampleExactFiveFieldCorroborationCount"]}; prior3571+33/18/1098 SHA unchanged')


if __name__ == '__main__':
    main()
