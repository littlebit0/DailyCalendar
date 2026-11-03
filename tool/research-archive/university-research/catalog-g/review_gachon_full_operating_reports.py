"""Per-offering current educational-context review, not title-based acceptance.
Unread full-scope reports remain blocked. No missing excerpt is called impossible.
"""
import json,re,collections,hashlib
from pathlib import Path
from normalize_gachon_enrollment import review_enrollment
from audit_gachon_full_operating_reports import ENGLISH_OPERATING
from validate_gachon_individual_weekly_period import current_period_weekly_rows_consistent
P=Path(__file__).resolve().parent
source=json.loads((P/'gachon-full-operating-report-audit.json').read_text())
base=json.loads((P/'gachon-full-normalized-source-candidates.json').read_text())
BASE={(r['campusSourceCode'],r['officialOfferingCode']):r for r in base['courses']}
method_review=json.loads((P/'gachon-ordinary-hybrid-method-context-review.json').read_text())
METHOD_REVIEWS={(r['campus'],r['officialOfferingCode']):r for r in method_review['rows']}
conditional_review=json.loads((P/'gachon-ordinary-conditional-method-context-review.json').read_text())
CONDITIONAL_REVIEWS={(r['campus'],r['officialOfferingCode']):r for r in conditional_review['rows']}
topic_review=json.loads((P/'gachon-weekly-topic-marker-context-review.json').read_text())
TOPIC_REVIEWS={(r['campus'],r['officialOfferingCode'],r['week']):r for r in topic_review['rows']}
term_review=json.loads((P/'gachon-other-term-statement-context-review.json').read_text())
TERM_REVIEWS={(r['campus'],r['officialOfferingCode']):r for r in term_review['rows']}
# Individually reviewed current source groups; each offering independently verifies its header.
MIXED={'01706001','02858001','02858002','08231001','08231002','12897001','12897002','K0026002','13660001','15654001'}
EXCEPTION={'05195001','05195002','08386003','08386008','08386006','08386012','08386026','08386028','11471002','13471001','13471002'}
CLASSROOM={'04731001','05086001','06810003','06810007','08849001','11521001','11943001','12400001','12400002','12748001','13664001','13701001','14839001','15159001','15562001','61489001'}
CHEM={f'07721{i:03d}' for i in range(1,11)}|{f'08388{i:03d}' for i in range(1,33)}|{'M3707001','M3707002','M3707003'}
MATH={f'08385{i:03d}' for i in range(1,20)}
PHYS={f'08386{i:03d}' for i in range(1,33)}-EXCEPTION
MED={'M0494007','M0853003','M0853005','M0853006','M2736001','M3478001','M3478002','M3479001','M3479002'}
WEAK={'03939001','11752001','15704001','15750001','61146001','61285001','61454001','61671001','K0126002'}
rows=[]
for report in source['reports']:
    row=report['sourceRow'];code=row['HAKSU_NO'];contexts=report.get('operatingContexts',[]);text=' '.join(contexts)+' '+report.get('teachingMethodEducationalExcerpt','')
    weeks=[];topic_review_applied=False
    for original in report.get('weeklyRows',[]):
        week={**original,'signals':list(original['signals'])}
        topic=TOPIC_REVIEWS.get((report['campus'],code,week['week']))
        if topic and report.get('educationalParserVersion',0)>=6:
            digest=hashlib.sha256(json.dumps(week['operatingContexts'],ensure_ascii=False).encode()).hexdigest()
            if digest==topic['contextSha256']:
                week['signals']=[signal for signal in week['signals'] if signal not in topic['ignoredTopicSignals']]
                if topic.get('ignoredAdditionalDateMarker'):
                    week['explicitAdditionalDateMention']=False
                if topic.get('ignoredAdditionalClockMarker'):
                    week['explicitClockMention']=False
                topic_review_applied=True
        weeks.append(week)
    identity=report.get('report',{})
    period_consistent=current_period_weekly_rows_consistent(report,BASE.get((report['campus'],code)))
    verified=all(identity.get(k) for k in ('headerCourseCodeMatches','currentTermMatches','catalogProfessorAppearsInReport'))
    decision='needs-individual-semantic-review';reason='No acceptance from unread plan, title,15week template, or delivery keyword.'
    reviewed=topic_review_applied;approved=False;excerpts=[]
    if 'Flipped' in row['SUBJECT_NM_KOR']:
        assert code in MIXED|EXCEPTION|CLASSROOM|CHEM|MATH|PHYS|MED|WEAK,code
        reviewed=True
        if not verified:
            decision='current-plan-identity-unverified';reason='A current code/term/professor identity component is absent.'
        elif code in MIXED:
            decision='mixed-video-and-in-person-slot-mapping-unresolved'
            reason='Plan separates self-study/video from required class/practice. Exact printed slot mapping is not independently proved; do not repeat all slots.'
            excerpts=contexts[:4]
        elif code in EXCEPTION:
            decision='actual-date-or-week-delivery-exception-requires-normalization'
            reason='Current plan specifies holiday/makeup/online replacement or conditional later-announced date; preserve per-offering exceptions and do not make a whole-term recurrence.'
            excerpts=[c for w in weeks for c in w.get('operatingContexts',[]) if re.search(r'보강|휴강|비대면|온라인|ZOOM|Zoom',c)][:4]
        elif code in CHEM and '현장 수업에서는' in text and ('수업날 오전' in text or '수업 당일' in text or '수업 하루' in text):
            decision='preclass-video-with-onsite-work-confirmed'
            reason='Current plan explicitly separates advance video/quiz from onsite class activities. Printed classroom meeting is not removed by Flipped Learning title.'
            excerpts=[c for c in contexts if '현장 수업에서는' in c][:1]
            approved=period_consistent and not any(set(w['signals'])&{'휴강','보강','휴일','추석','한글날','집중','교외활동','수업없음','학기불일치표현','화상','비대면','온라인'} for w in weeks)
        elif code in MATH and '현장 수업' in text and ('사전 학습' in text or '사전학습' in text):
            decision='preclass-video-with-onsite-work-confirmed'
            reason='Preclass video/quiz and separately described onsite problem-solving are current plan teaching methods; no printed slot replacement is asserted.'
            excerpts=[c for c in contexts if '현장 수업' in c][:1]
            approved=period_consistent and not any(set(w['signals'])&{'휴강','보강','휴일','추석','한글날','집중','교외활동','수업없음','학기불일치표현','화상','비대면','온라인'} for w in weeks)
        elif code in CLASSROOM:
            decision='separate-classroom-work-confirmed'
            reason='Current teaching method describes class/onsite discussion or work in addition to advance materials; no entire-slot self-study replacement was found in reviewed educational contexts.'
            excerpts=contexts[:3]
            approved=period_consistent and not any(set(w['signals'])&{'휴강','보강','휴일','추석','한글날','집중','교외활동','수업없음','학기불일치표현','화상','비대면','온라인'} for w in weeks)
        elif code in PHYS and any(phrase in text for phrase in ('강의실에서 강의','오프라인 출석','대면 수업','현장 수업','수업 시간에는','강의 2시간','이론 강의와 2시간','2시간의 강의와 2시간','매주 2시간 강의')):
            decision='onsite-theory-and-lab-confirmed'
            reason='Current educational method/attendance explicitly describes onsite class or weekly theory+lab. Source mentions of advance video are not a whole-slot replacement.'
            excerpts=contexts[:3]
            approved=period_consistent and not any(set(w['signals'])&{'휴강','보강','휴일','추석','한글날','집중','교외활동','수업없음','학기불일치표현','화상','비대면','온라인'} for w in weeks)
        else:
            decision='reviewed-excerpt-does-not-resolve-full-slot-semantics'
            reason='Current public report was inspected, but retained educational method does not prove full printed time slots or their video/practice allocation. Missing context is not proof of permanent unavailability.'
            excerpts=contexts[:3]
    elif '실시간화상' in row['SUBJECT_NM_KOR']:
        reviewed=True
        physical_text=re.sub(r'비\s*대면','REMOTE',text)
        exam_physical=bool(re.search(r'(?:대면|강의실|예음홀|오프라인).{0,100}(?:시험|고사)|(?:시험|고사).{0,100}(?:대면|강의실|예음홀|오프라인)',physical_text))
        if not verified:
            decision='current-plan-identity-unverified';reason='Current code/term/professor identity is incomplete.'
        elif not period_consistent:
            decision='live-title-with-incomplete-current-weekly-operation';reason='Live title does not establish missing actual weekly classes or their dates.'
        elif exam_physical:
            decision='live-lectures-with-physical-or-mixed-assessment';reason='Current plan describes physical/mixed assessment distinct from live lectures; actual date, end time and room must be separately normalized.'
        elif any(set(w['signals'])&{'휴강','보강','휴일','추석','한글날','집중','교외활동','수업없음','학기불일치표현','녹화','동영상'} for w in weeks):
            decision='live-title-with-per-week-operating-exceptions';reason='Current weekly source contains a video/no-class/makeup exception; no full-semester live-mode assignment.'
        elif any(set(w['signals'])&{'시험','중간고사','기말고사'} for w in weeks):
            decision='live-lecture-frame-with-assessment-clock-unresolved';reason='Ordinary live teaching is declared, but assessment timing/mode must not be inferred from the lecture frame.'
        elif re.search(r'실시간|화상|온라인|Zoom|ZOOM',text):
            decision='current-live-weekly-frame-confirmed';reason='Live title and current public teaching method agree; full weekly span is present. Exact date conversion and per-course period/exception gates remain required.'
            approved=not any(w.get('explicitClockMention') or w.get('explicitAdditionalDateMention') for w in weeks)
        else:
            decision='live-title-but-operating-method-insufficient';reason='The live label is current, but this educational excerpt does not resolve exact weekly operation.'
        excerpts=contexts[:3]
    elif report.get('educationalParserVersion',0)>=6:
        # Ordinary source validation is explicit screening, not a claim that every
        # narrative sentence was manually reviewed. Uncertain markers stay blocked.
        if not verified:
            decision='current-plan-identity-unverified';reason='Current identity is incomplete.'
        elif re.search(r'현장실습|임상실습|간호.*실습|교육실습|병원실습|인턴|사회봉사|AI-NTree',row['SUBJECT_NM_KOR']):
            decision='individual-placement-or-service-operation-needs-proof';reason='Placement/service class requires its actual period and subgroup operation; a15week template is insufficient.'
        elif not period_consistent:
            decision='ordinary-current-weekly-span-incomplete-or-short';reason='Current dated weekly span is incomplete/nonstandard; individual period proof is required.'
        elif any(set(w['signals'])&{'휴강','보강','휴일','추석','한글날','집중','교외활동','수업없음','학기불일치표현','화상','비대면','온라인','녹화','동영상','실시간'} or w.get('explicitClockMention') or w.get('explicitAdditionalDateMention') for w in weeks):
            decision='ordinary-current-operating-markers-need-review';reason='Current source has delivery, actual extra date/clock, or makeup/no-class markers; no ordinary repeat fallback.'
        elif re.search(r'온라인|비대면|실시간|화상|동영상|영상강의|녹화|플립|사전\s*학습|MOOC|ZOOM|Zoom|in-person.*online|cyber|flipped',report.get('teachingMethodEducationalExcerpt',''),re.IGNORECASE) or ENGLISH_OPERATING.search(report.get('teachingMethodEducationalExcerpt','')):
            decision='ordinary-teaching-method-hybrid-marker-needs-review';reason='Current method has a hybrid/remote marker; title or ordinary grid does not resolve it.'
        elif not row.get('TIME') or not row.get('LOC_NM') or not re.search(r'강의|실습|토론|발표|토의|lecture|discussion',report.get('teachingMethodEducationalExcerpt',''),re.IGNORECASE):
            decision='ordinary-published-method-or-room-insufficient';reason='Current educational method or actual printed classroom/time does not resolve ordinary operation.'
        else:
            decision='ordinary-current-plan-and-printed-clock-consistent';reason='Current identity, all actual weekly dates matching the independently evidenced individual course period, printed room/time and ordinary teaching method agree; explicit exception screening found no marker.';approved=True
    if approved:
        approved=report.get('educationalParserVersion',0)>=6 and period_consistent and not any(w.get('explicitClockMention') or w.get('explicitAdditionalDateMention') or w.get('operatingContextLimitReached') or w.get('operatingContextTruncationDetected') for w in weeks)
    method_decision=METHOD_REVIEWS.get((report['campus'],code))
    if decision=='ordinary-teaching-method-hybrid-marker-needs-review' and method_decision:
        method_unchanged=hashlib.sha256(report.get('teachingMethodEducationalExcerpt','').encode()).hexdigest()==method_decision['methodSha256']
        if method_unchanged and period_consistent and not any(w.get('operatingContextLimitReached') or w.get('operatingContextTruncationDetected') for w in weeks):
            decision='ordinary-supplementary-material-with-classroom-method-confirmed'
            reason=method_decision['reason'];reviewed=True;approved=True
    conditional=CONDITIONAL_REVIEWS.get((report['campus'],code))
    if conditional and report.get('educationalParserVersion',0)>=6:
        method_unchanged=hashlib.sha256(report.get('teachingMethodEducationalExcerpt','').encode()).hexdigest()==conditional['methodSha256']
        if method_unchanged and verified:
            decision='ordinary-conditional-or-individual-operating-method-unresolved'
            reason=conditional['reason'];reviewed=True;approved=False
    if report.get('potentialDifferentTermStatement'):
        term=TERM_REVIEWS.get((report['campus'],code))
        term_contexts=[c for c in report['operatingContexts'] if re.search(r'spring|summer|winter|2026.*1.*학기',c,re.IGNORECASE)]
        digest=hashlib.sha256(json.dumps(term_contexts,ensure_ascii=False).encode()).hexdigest()
        if term and digest==term['termContextSha256'] and verified and period_consistent:
            reviewed=True
        else:
            decision='current-header-with-other-term-statement-needs-review'
            reason='Current code/term header also has another term statement in the actual report. Its meaning must be reviewed before scheduling.'
            approved=False
    rows.append({'campus':report['campus'],'officialOfferingCode':code,'courseName':row['SUBJECT_NM_KOR'],'sourceSchedule':row['TIME'],'currentIdentityVerified':verified,'semanticReviewPerformed':reviewed,'decision':decision,'reason':reason,'sourceOperatingExcerpt':excerpts,'weeklyRowCount':len(weeks),'enrollmentReview':review_enrollment(report),'sourceMeetingSemanticsApproved':approved,'productionSchedulingApproved':False})
output={'researchOnly':True,'completionClaim':False,'fullCurrentCount':source.get('fullCurrentCatalogCount'),'fetched':len(rows),'allCurrentReportsFetched':source['allCurrentReportsFetched'],'sourceFile':'gachon-full-operating-report-audit.json','rows':rows}
temporary=(P/'gachon-full-operating-semantic-review.tmp')
temporary.write_text(json.dumps(output,ensure_ascii=False,indent=2))
temporary.replace(P/'gachon-full-operating-semantic-review.json')
print(dict(collections.Counter(r['decision'] for r in rows)))
print('Semantics approved',sum(r['sourceMeetingSemanticsApproved'] for r in rows),'reviewed',sum(r['semanticReviewPerformed'] for r in rows))
