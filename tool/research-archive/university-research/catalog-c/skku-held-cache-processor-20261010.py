import pathlib,json,re,hashlib,datetime,collections,copy,shutil,sys
b=pathlib.Path('work/university-research/catalog-c');p=pathlib.Path(sys.argv[1]);p.mkdir(exist_ok=False);prior=b/'skku-held-cumulative-v190-20261010';auditpath=pathlib.Path('work/university-research/catalog-g/skku-public-operating-plan-audit.json');audit=json.load(open(auditpath));ar={r['offeringCode']:r for r in audit['records']};ledger=json.load(open(b/'skku-held-own-operation-v187-ledger-20261010/source-read-ledger.json'))
def sha(f):return hashlib.sha256(f.read_bytes()).hexdigest()
def write(n,d):(p/n).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
rows={};datasets={}
for camp in ['humanities','naturalScience','icampus']:
 f=prior/f'skku-{camp}-2026-2.cumulative-v190.json';f=f if f.exists() else prior/f'baseline-skku-{camp}-2026-2.json';datasets[camp]=json.load(open(f));shutil.copyfile(f,p/f'baseline-skku-{camp}-2026-2.json')
 for c in datasets[camp]['courses']:rows[c['courseCode']+'-'+c['section']]=c
held={k:c for k,c in rows.items() if not c['schedules']};sources=collections.defaultdict(dict)
for f in sorted(b.glob('skku-held-own-operation-*/*education*.json')):
 try:d=json.load(open(f))
 except (ValueError,UnicodeError):continue
 if not isinstance(d,dict) or d.get('offeringCode') not in held or not d.get('educationFullText'):continue
 key=d['offeringCode'];rawsha=d.get('sha256');identity=d.get('currentFileRow',{});full=d.get('fullEducationalTextRead') is True;visual=d.get('visualEducationalPagesFullRead') is True
 sources[key].setdefault(rawsha or sha(f),{'path':str(f),'jsonSHA256':sha(f),'rawSHA256':rawsha,'text':d['educationFullText'],'completeTextCacheFlag':full,'visualFullCacheFlag':visual,'identityCurrent':identity.get('GAESUL_YEAR')=='2026' and identity.get('GAESUL_TERM')=='20' and identity.get('HAKSU_NO','')+'-'+identity.get('BUNBAN','')==key,'payload':d})
clockre=re.compile(r'(?<!\d)(\d{1,2})\s*[:：]\s*(\d{2})\s*(?:[-–—~～]|to)\s*(\d{1,2})\s*[:：]\s*(\d{2})(?!\d)',re.I)
datere=re.compile(r'(?<!\d)(\d{1,2})\s*[/월]\s*(\d{1,2})\s*일?(?!\d)')
examre=re.compile(r'중간\s*(?:고사|시험)|기말\s*(?:고사|시험)|mid\s*[-–]?\s*term\s*(?:exam|examination)|final\s*(?:exam|examination)',re.I)
uncertainre=re.compile(r'약\s*\d|미정|추후|예정|별도\s*공지|변경|tentative|subject\s*to|TBD|TBA|to\s*be\s*(?:updated|announced)|approx|may\s*be',re.I)
queues=[];facts=[];conflictset=set(ledger['currentHeldActualConflictOfferings']) | {'GEDM001-E4'};positiveExamSuggestions=[]
for key,c in held.items():
 r=ar[key];summaries=[];examclaims=[]
 for src in sources[key].values():
  t=src['text'];cl=[]
  for m in clockre.finditer(t):
   a,bm,z,w=map(int,m.groups());start=a*60+bm;end=z*60+w
   context=t[max(0,m.start()-100):m.end()+120];role='officeOrConsultation' if re.search(r'office\s*hour|면담|상담',context,re.I) else ('exam' if examre.search(context) else 'unspecifiedClock')
   cl.append({'literal':m.group(0),'startMinute':start,'endMinute':end,'validClock':0<=a<=23 and 0<=z<=23 and bm<60 and w<60 and start<end,'contextRoleSuggestion':role,'textOffset':m.start()})
  for line in t.splitlines():
   if not examre.search(line):continue
   mm=list(clockre.finditer(line));dates=[]
   for dm in datere.finditer(line):
    month,day=map(int,dm.groups())
    try:date=datetime.date(2026,month,day)
    except ValueError:continue
    dates.append({'literal':dm.group(0),'dateWhenPrimary2026Confirmed':date.isoformat(),'weekdayIndependentlyComputed':date.isoweekday()})
   if mm and dates:
    for m in mm:
     a,minute,z,last=map(int,m.groups());start=a*60+minute;end=z*60+last
     if not (a<24 and z<24 and minute<60 and last<60 and start<end):continue
     claim={'offeringCode':key,'sourcePath':src['path'],'rawSHA256':src['rawSHA256'],'currentExactPrimaryAssociation':src['identityCurrent'],'fullTextCacheFlag':src['completeTextCacheFlag'],'sourceDateAndClockSameExamLine':True,'clockLiteral':m.group(0),'startMinute':start,'endMinute':end,'dates':dates,'uncertaintyMarkerOnSameLine':bool(uncertainre.search(line)),'ownExamModeInPersonLiteral':bool(re.search(r'대면\s*시험|오프라인.*시험|시험.*오프라인',line)),'ownRoomNotInvented':True,'appointmentGenerated':False,'notWholeCourseCompletion':True};examclaims.append(claim)
  printedyears=sorted(set(re.findall(r'(?i)(?:Fall|Spring|학년도/학기|학년도|Semester)[\s:]*((?:20)\d{2})|((?:20)\d{2})\s*(?:학년도|년\s*[12]\s*학기)',t)))
  summaries.append({'sourcePath':src['path'],'jsonSHA256':src['jsonSHA256'],'rawSHA256':src['rawSHA256'],'completeTextCacheFlag':src['completeTextCacheFlag'],'visualFullCacheFlag':src['visualFullCacheFlag'],'currentExactPrimaryAssociation':src['identityCurrent'],'fullSourceComputerParsed':True,'newHumanFullReadClaim':False,'clockClaims':cl,'sourceOwnTermMarkerSuggestions':printedyears,'anyUncertaintyMarkers':bool(uncertainre.search(t)),'mixedOnlineOfflineSignal':bool(re.search(r'플립|PBL|blended|flip|사전.*오프라인|online.*offline|on/off',t,re.I))})
 a=r.get('attachments',[]);truncated=any(x.get('contextTruncated') or x.get('contextLimitReached') for x in a);contextsource=sum(len(x.get('educationalOperatingContexts',[])) for x in a)
 category=('knownConflictHeld' if key in conflictset else 'completeOriginalNeedsConstraintAdjudication' if summaries else 'excerptOnlyNeedsFullPrimarySource' if a else 'inlineOnlyNoPublicAttachmentCached')
 if examclaims:category='explicitExamClaimsNeedBoundedProjection'
 q={'offeringCode':key,'sourceId':c['sourceId'],'campus':c['campus'],'nativeRawFramesUnchanged':c.get('rawMeetingFrameForReviewOnly',[]),'nativeTeachingMode':c.get('sourceEducationalMetadata',{}).get('SUUP_TYPE_NM'),'nativePeriods':c.get('ordinaryTermFrameForReviewOnly'),'category':category,'previousActualConflict':key in conflictset,'currentInlineIdentityConfirmed':r.get('currentDetailIdentityConfirmed') is True,'fullOriginalComputerParsed':bool(summaries),'cachedAttachmentExcerptCount':len(a),'cachedEducationalContextCount':contextsource,'anyCachedExcerptTruncated':truncated,'literalExamClaims':examclaims,'fullOriginalSummary':summaries,'appointmentGenerated':False};queues.append(q);positiveExamSuggestions+=examclaims
counts=collections.Counter(x['category'] for x in queues);receipt={'sourceOnly':True,'SDKExecuted':False,'productModified':False,'AGENTMemoryModified':False,'completionClaim':False,'processingScopeCompleted':'All current held rows from the selected frozen baseline classified','allHeldRowsProcessed':len(queues),'currentAllOfferings':len(rows),'currentCandidateScheduledOfferings':sum(bool(c['schedules']) for c in rows.values()),'currentCandidateMeetings':sum(len(c['schedules']) for c in rows.values()),'uniqueHeldFullOriginalCachesComputerParsed':sum(bool(x['fullOriginalSummary']) for x in queues),'categories':dict(counts),'literalExamClaims':len(positiveExamSuggestions),'humanWholeReadCountNotChangedByParser':True,'originalAuditSHA256':sha(auditpath),'datesAreClaimsNotGeneratedReservations':True,'excerptCannotEstablishCompleteScope':True,'approximateOrUnannouncedExamEndNotInferred':True,'ordinalToGregorianProjection':False,'officeHoursNeverUsedAsClassClock':True,'protectedSourcesNotBypassed':True,'negativeDoesNotMeanImpossible':True}
write('all-held-source-processing-queue.json',queues);write('batch-processing-receipt.json',receipt);write('explicit-exam-claim-queue.json',positiveExamSuggestions)
(p/'HANDOFF.md').write_text('# SKKU v191 기존 교육JSON 전체 일괄처리\n\n현재 누적후보186 전체2782행 중948held 모두를 원문캐시/inline/첨부문맥으로 분류했습니다. 소수문서 humanreview 완료를 처리선행조건으로 삼지 않았습니다. 실제 전체 인간판독 계수는 별도이며 parser완료가학교지원완료가아닙니다. 날짜+HH 같은시험행만 exactclaim으로 추출하고 원문약/미정/추후공지·혼합방식·officehour·실제충돌을 별도표시했습니다. excerpt/truncation만으로 positive예약을 생성하지 않았습니다. 현재누적후보190=1834/50051 유지/추가예약0, 최종 누적 검증SDKroot만/제품AGENT0. 보호문서우회0.\n')
write('source-sha256.json',{f.name:sha(f) for f in sorted(p.iterdir()) if f.is_file() and f.name!='source-sha256.json'});print(json.dumps(receipt,ensure_ascii=False));print('manifest',sha(p/'source-sha256.json'));print('examkeys',sorted(set(x['offeringCode'] for x in positiveExamSuggestions)))
