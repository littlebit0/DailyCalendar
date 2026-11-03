"""Extract bounded educational headers for individual review, never approvals."""
import collections
import json
import re
from pathlib import Path

P = Path(__file__).resolve().parent
CODE_SECTION = re.compile(r'학수\s*번호\s*[-/]?\s*분반\s*[:：]?\s*([A-Z]{3,4}\d{4})\s*[-_/]\s*([A-Z]?\d{1,2})\b')
KOREAN_TEACHER = re.compile(r'(?:성\s*명|담당\s*교수|교강사\s*명|담당\s*강사)\s*[:：]?\s*([가-힣](?:\s*[가-힣]){1,4})(?=\s|[(:：])')
CLOCK_HEADER = re.compile(r'(?:수업\s*시간|강의\s*시간|class\s*(?:day/time|time|schedule)|lecture\s*(?:time|schedule))\s*[:：]?\s*.{0,115}', re.I)


def main():
    source = json.loads((P / 'skku-inline-privacy-education-repair-audit.json').read_text())
    decisions = []
    counts = collections.Counter()
    for record in source['records']:
        row = record['sourceRow']
        key = record['offeringCode']
        texts = [t for a in record['attachments'] for t in a.get('educationalOperatingContexts', [])]
        explicit = []
        teacher_questions = []
        clocks = []
        for text in texts:
            for match in CODE_SECTION.finditer(text):
                found = match[1] + '-' + match[2].zfill(2)
                if found not in explicit:
                    explicit.append(found)
            for match in KOREAN_TEACHER.finditer(text):
                name = re.sub(r'\s+', '', match[1])
                # Ordinary headings and course topics are not posted person names.
                if name in ('수업', '연락처', '학년도', '수강대상', '학습태도'):
                    continue
                current = re.sub(r'\s+', '', row['PER_NAME'])
                if name not in current and current not in name and name not in teacher_questions:
                    teacher_questions.append(name)
            for match in CLOCK_HEADER.finditer(text):
                bounded = re.sub(r'\s+', ' ', match.group())
                if bounded not in clocks:
                    clocks.append(bounded)
        conflicts = [code for code in explicit if code != row['HAKSU_NO'] + '-' + row['BUNBAN'].zfill(2)]
        counts['currentRepairedHeaderReviewCount'] += 1
        counts['explicitCodeSectionHeaderCourses'] += bool(explicit)
        counts['explicitLinkedSectionConflictCourses'] += bool(conflicts)
        counts['possibleKoreanTeacherLabelConflictCourses'] += bool(teacher_questions)
        counts['clockHeaderCoursesNeedingIndividualInterpretation'] += bool(clocks)
        decisions.append({'offeringCode': key, 'registrationApproval': False,
                          'currentPublishedProfessor': row['PER_NAME'],
                          'currentPublishedClock': row['GYOSI_NAME'],
                          'explicitAttachmentCodeSections': explicit,
                          'explicitLinkedCodeSectionConflicts': conflicts,
                          'possibleKoreanTeacherLabelsNeedingReview': teacher_questions,
                          'attachedClockEducationalHeaderContexts': clocks,
                          'missingHeaderDoesNotInvalidatePublishedTimetable': True})
    output = {'researchOnly': True, 'completionClaim': False, 'registrationApproval': False,
              'whole548Fetched': source['allTargetRequestsFinished'], 'counts': dict(counts),
              'decisions': decisions}
    path = P / 'skku-repaired-education-header-audit.json'
    temporary = path.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(output, ensure_ascii=False, indent=2)+'\n')
    temporary.replace(path)
    print(dict(counts))


if __name__ == '__main__':
    main()
