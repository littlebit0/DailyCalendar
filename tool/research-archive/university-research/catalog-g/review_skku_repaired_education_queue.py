"""Build a local semantic-review queue from the isolated educational repair.

This does not approve offerings, generate meetings, or alter immutable candidates.
Only educational evidence previously sanitized by the public collector is used.
"""
import collections
import importlib.util
import json
import re
from pathlib import Path

P = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('planned_r25', P / 'prepare_skku_planned_regular_r25_candidate.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)


def read(name):
    return json.loads((P / name).read_text())


def main():
    repair = read('skku-inline-privacy-education-repair-audit.json')
    current = {r['HAKSU_NO_BUNBAN']: r for r in read('skku-final-current-educational-source.json')['records']}
    decisions = []
    counts = collections.Counter()
    for record in repair['records']:
        key = record['offeringCode']
        row = current[key]
        detail = record['detail'][0] if record['detail'] else {}
        reasons = []
        if not record['currentDetailIdentityConfirmed'] or not detail:
            reasons.append('currentDetailIdentityUnconfirmed')
        if base.frames(row['GYOSI_NAME']) != base.frames(detail.get('SUUP_YOIL_GYOSI', '')):
            reasons.append('currentPublishedClockConflict')
        if detail.get('PER_NAME', '').strip() != row['PER_NAME'].strip():
            reasons.append('currentPublishedProfessorConflict')
        if any(a.get('protectionPresent') or 'educationalOperatingContexts' not in a for a in record['attachments']):
            reasons.append('attachmentEducationUnavailableWithoutBypass')
        if any(a.get('privacySuppressedLineCount') for a in record['attachments']):
            reasons.append('remainingEducationalLineLoss')
        if any(a.get('contextLimitReached') or a.get('contextTruncated') for a in record['attachments']):
            reasons.append('educationalContextStillCapped')
        if any(x.get('privacySuppressedLineCount') for x in [detail] + record['weekly']):
            reasons.append('remainingDetailOrWeeklyLineLoss')
        if row['HAKBU_JIBJUNG_GB'] != 'N':
            reasons.append('concentratedTermNeedsIndividualPeriod')
        if row['SUUP_TYPE_CD'] not in ('31', '33'):
            reasons.append('deliveryAllocationNeedsIndividualReview')
        sources = [('currentTitle', row['GWAMOK_NAME']), ('currentRemarks', row.get('BIGO', '')),
                   ('detailMethod', detail.get('CLASS_INFO', '')), ('detailRemarks', detail.get('BIGO', ''))]
        sources += [('weekly:' + str(w['PLAN_WEEK_CNT']), w.get('PLAN_WEEK_CONT', '') + ' ' + w.get('BIGO', '')) for w in record['weekly']]
        sources += [('attachmentEducation', t) for a in record['attachments'] for t in a.get('educationalOperatingContexts', [])]
        garbled = any(len(re.findall(r'[\u0590-\u05ff\u0980-\u0aff]', text)) > 30 for _, text in sources)
        if garbled:
            reasons.append('educationalTextEncodingUncertain')
        signals = []
        header_conflicts = []
        restrictions = []
        extra_delivery = re.compile(r'\bon[- ]line\b|\b(?:pre[- ]?recorded|recorded)\s*(?:video|lecture|class)|\bvideo\s*(?:lecture|class)|사전\s*(?:녹화|제작)|녹화\s*(?:강의|수업)|excursion|\bcancel(?:led|ed)\b|(?:class|lecture).{0,25}cancel|\bholiday\b|(?:수업|강의).{0,15}중단', re.I)
        for field, text in sources:
            for pattern in (base.SIGNAL, base.PLACEMENT, base.TERM_CONFLICT, extra_delivery):
                for match in pattern.finditer(text):
                    context = text[max(0, match.start()-90):min(len(text), match.end()+150)]
                    value = {'field': field, 'signal': match.group(), 'educationalContext': context}
                    if value not in signals:
                        signals.append(value)
            for match in re.finditer(r'학수\s*번호\s*[-/]?\s*분반.{0,35}?\b([A-Z]{3,4}\d{4})\s*[-_/]\s*([A-Z]?\d{1,2})\b', text):
                if match[1] != row['HAKSU_NO'] or match[2].zfill(2) != row['BUNBAN'].zfill(2):
                    header_conflicts.append({'field': field, 'explicitCodeSection': match[1] + '-' + match[2]})
            for match in re.finditer(r'수강\s*(?:대상|제한|불가|금지)|타과|타\s*학과|선수\s*(?:과목|학습)|prerequisite|enrol(?:l)?ment\s*(?:restriction|requirement)', text, re.I):
                value = {'field': field, 'educationalContext': text[max(0, match.start()-50):min(len(text), match.end()+180)]}
                if value not in restrictions:
                    restrictions.append(value)
        if header_conflicts:
            reasons.append('explicitLinkedPlanCodeSectionConflict')
        # A flag is a review question, never an automatically proved cancellation.
        state = 'needsSemanticOperatingReview' if signals else 'needsWholeHeaderAndRestrictionReview'
        if reasons:
            state = 'needsSpecificEvidenceReview'
        counts[state] += 1
        decisions.append({'offeringCode': key, 'sourceType': row['SUUP_TYPE_CD'],
                          'decision': state, 'registrationApproval': False,
                          'actualAttendanceConfirmed': False, 'reasons': reasons,
                          'sourceAndDetailOriginalClockMatch': base.frames(row['GYOSI_NAME']) == base.frames(detail.get('SUUP_YOIL_GYOSI', '')),
                          'explicitLinkedPlanCodeSectionConflicts': header_conflicts,
                          'operatingSignalContexts': signals, 'restrictionContexts': restrictions,
                          'currentPublishedEligibility': detail.get('SUGANGDAESANG_HAKGWA', ''),
                          'currentPublishedPrerequisite': detail.get('PRE_HAKSU_NAME', ''),
                          'sourcePublishedRemarks': row.get('BIGO', ''),
                          'detailPublishedRemarks': detail.get('BIGO', '')})
    output = {'researchOnly': True, 'completionClaim': False, 'registrationApproval': False,
              'whole548Fetched': repair['allTargetRequestsFinished'],
              'fetchedCount': repair['count'], 'targetCount': 548,
              'counts': dict(counts), 'canonicalAuditModified': False,
              'originalR25CandidateModified': False, 'newDatesCreated': False,
              'decisions': decisions}
    target = P / 'skku-repaired-education-semantic-review-queue.json'
    temp = target.with_suffix('.json.tmp')
    temp.write_text(json.dumps(output, ensure_ascii=False, indent=2)+'\n')
    temp.replace(target)
    print({'fetched': repair['count'], 'counts': dict(counts),
           'codeSectionConflictCourses': sum(bool(r['explicitLinkedPlanCodeSectionConflicts']) for r in decisions),
           'restrictionContextCourses': sum(bool(r['restrictionContexts']) for r in decisions)})


if __name__ == '__main__':
    main()
