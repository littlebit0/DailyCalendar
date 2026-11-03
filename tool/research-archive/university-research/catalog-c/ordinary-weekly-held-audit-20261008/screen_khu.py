"""Research screening only; no product mutation or operating approval."""
import collections, hashlib, json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1].parent
OUT=Path(__file__).resolve().parent
known={'ECON2043-00':'priorExplicitBlendedFlippedAllocationUnconfirmed'}
plans=collections.defaultdict(list)
for path in (ROOT/'catalog-u/public-plans-v2').glob('*.json'):
    p=json.loads(path.read_text());plans[(p['campus'],p['lectureCode'])].append((path,p))
slot=re.compile(r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)')
special=re.compile(r'집중|비실시간|비대면|실시간|온라인|원격|녹화|동영상|블[렌랜]디드|하이브리드|현장|실습|실험|실기|개별|독립|캡스톤|임상|프로젝트|인턴|군사|휴강|보강|대체|자율|별도|학회|견학|blended|flipped|asynchronous|online|remote|internship|field\s*trip|intensive|recorded|MOOC',re.I)
decisions=[]
for file in Path('assets/timetable').glob('khu-*2026-2.json'):
    d=json.loads(file.read_text())
    for c in d['courses']:
        if c['schedules']:continue
        reasons=[];
        if c['courseCode']+'-'+c['section'] in known:reasons.append(known[c['courseCode']+'-'+c['section']])
        variants=c['sourceEducationalVariants'];native={'seoul':'서울','global':'국제'}[c['campus']]
        texts={re.sub(r'<br\s*/?>','\n',v['timetable'],flags=re.I).strip() for v in variants}
        if len(texts)!=1:reasons.append('nativeScheduleVariantConflict')
        text=sorted(texts)[0];matches=list(slot.finditer(text));residue=slot.sub('',text)
        if not matches or re.sub(r'[\s,;/]','',residue):reasons.append('nativeClockNotFullyParsed')
        if any(not m[6].strip() or int(m[4])*60+int(m[5])<=int(m[2])*60+int(m[3]) for m in matches):reasons.append('nativeClockRoomMissingOrInvalid')
        if special.search(c['courseName']+' '+ ' '.join(v['bigo'] for v in variants)):reasons.append('nativeTitleOrRemarksSpecialSignal')
        key=(native,variants[0]['lecture_cd']); own=plans.get(key,[]);planproof=[]
        teachers={v['teach_na'] for v in variants}
        for path,p in own:
            if p.get('header')!=['2026학년도 2학기 강의계획서'] or p['queriedProfessorName'] not in teachers:reasons.append('currentPlanIdentityConflict')
            selected=[];context=[]
            basic_rows=[row for section in p['educationalSections'] if section['section']=='기본정보' for row in section['rows']]
            published_codes=[row[1] for row in basic_rows if len(row)>1 and row[0]=='학수번호']
            if published_codes!=[key[1]]:reasons.append('currentPlanPublishedNativeCodeConflict')
            title_rows=[row for row in basic_rows if row and row[0]=='강좌명']
            if not title_rows or not any(p['queriedProfessorName'] in ' '.join(row) for row in title_rows):reasons.append('currentPlanPublishedTeacherConflict')
            basic=[row for section in p['educationalSections'] if section['section']=='기본정보' for row in section['rows'] if row and row[0]=='강의시간강의실']
            joined=' '.join(' '.join(row[1:]) for row in basic)
            normalized=re.sub(r'\s+','',joined)
            if basic and any((m[1]+m[2]+':'+m[3]+'-'+m[4]+':'+m[5]) not in normalized or re.sub(r'\s+','',m[6]) not in normalized for m in matches):reasons.append('currentPlanNativeClockRoomMismatch')
            for s in p['educationalSections']:
                if s['section']=='수업운영방식':
                    for row in s['rows'][1:]:
                        if row and row[0]=='수업운영방식' and any(x.strip() not in ['', '0%', '0', '0.0%'] for x in row[2:]):selected.append(row)
                        elif row and row[0]=='추가설명':context.extend(row[1:])
                if s['section']=='수업유형 및 방법':
                    for row in s['rows']:
                        if row and row[0] in ['수업유형추가설명','수업진행추가설명']:context.extend(row[1:])
                        if row and row[0]=='수업유형' and any(x.strip() not in ['', '0%', '0', '0.0%'] for x in row[2:7]):selected.append(row)
                if s['section']=='주별강의내용':context.extend(' '.join(row[2:]) for row in s['rows'] if row)
            if selected:reasons.append('currentPlanSelectedSpecialOperatingType')
            if special.search(' '.join(context)):reasons.append('currentPlanOperatingOrWeeklySpecialSignal')
            planproof.append({'file':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'selectedSpecialRows':selected})
        decisions.append({'sourceId':c['sourceId'],'courseCode':c['courseCode'],'section':c['section'],'courseName':c['courseName'],'campus':c['campus'],'sourceSchedule':c['sourceSchedule'],'sourceClassroom':c['sourceClassroom'],'nativePublicVariants':len(variants),'currentCachedPlans':len(own),'screenReasons':sorted(set(reasons)),'ordinaryReviewShortlistOnly':not reasons,'operatingApproval':False,'planProofs':planproof})
data={'completionClaim':False,'productionEdited':False,'screenOnly':True,'decisions':decisions,'reasonCounts':dict(collections.Counter(r for d in decisions for r in d['screenReasons'])),'shortlist':sum(d['ordinaryReviewShortlistOnly'] for d in decisions)}
(OUT/'khu-native-plan-screen.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');print({'held':len(decisions),'shortlist':data['shortlist'],'reasons':data['reasonCounts']})
