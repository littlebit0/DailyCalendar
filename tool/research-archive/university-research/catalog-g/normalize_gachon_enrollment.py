"""Review actual neighboring PDF table headings without claiming unrestricted enrollment."""
import re
NEXT_HEADING=re.compile(r'공학인증\s*이수구분|공학인증|교과목\s*설명|강의\s*진행방법|가천대학교')
CONDITION=re.compile(r'수강\s*대상|수강\s*자격|수강.*제한|수강.*불가|수강.*금지|수강.*가능|이수.*불가|이수.*가능|이수.*제한|(?:학과|학년|학생|학부|전공|외국인).{0,20}전용|전용.{0,20}(?:학생|학과|학년|전공)|재수강|수강신청|prerequisite|pre-requisite|enrollment|restricted|only.{0,40}students|students.{0,40}only',re.IGNORECASE)
def review_enrollment(report):
    evidence=report.get('enrollmentEvidence')
    if evidence is None:return {'state':'not-yet-extracted','absenceMeansUnrestricted':False,'fields':[],'contexts':[]}
    fields=[];contexts=[]
    for heading in evidence['headings']:
        raw=heading['sameLineEducationalValue']
        value=NEXT_HEADING.split(raw,maxsplit=1)[0].strip()
        state='published-same-line-field-value' if value else 'field-present-no-same-line-value-not-unrestricted'
        fields.append({'heading':heading['heading'],'sameLineValue':value,'state':state})
        if value:contexts.append(heading['heading']+': '+value)
    for context in evidence['publicRestrictionContexts']:
        combined=re.search(r'선수\s*(?:과목|교과목)\s*공학인증\s*이수구분(.*)',context)
        if combined:
            following=combined[1].replace('가천대학교','').strip()
            if following and following!='MSC':
                contexts.append('선수과목/공학인증 원문: '+following)
        # A blank prerequisite and the next table header do not become a prerequisite.
        if CONDITION.search(context) or (re.search(r'선수\s*(?:과목|교과목)',context) and not re.search(r'선수\s*(?:과목|교과목)\s*공학인증',context)):
            if context not in contexts:contexts.append(context)
    return {'state':'educational-condition-present-needs-context-review' if contexts else 'no-explicit-condition-found-in-readable-extract','separateFieldState':evidence['separateFieldState'],'absenceMeansUnrestricted':False,'fields':fields,'contexts':contexts,'privacySuppressedContextCount':evidence['privacySuppressedContextCount'],'contextLimitReached':evidence['contextLimitReached'],'contextTruncationDetected':evidence['contextTruncationDetected']}
