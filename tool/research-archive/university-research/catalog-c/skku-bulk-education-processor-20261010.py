"""Classify extracted primary originals without inventing periods, modes or HH."""
import pathlib,json,re,datetime,hashlib,collections,sys
b=pathlib.Path(__file__).parent;src=pathlib.Path(sys.argv[1]);out=pathlib.Path(sys.argv[2]);out.mkdir(exist_ok=True)
clock=re.compile(r'(?<!\d)(\d{1,2})\s*[:：]\s*(\d{2})\s*[-–—~～∼]\s*(\d{1,2})\s*[:：]\s*(\d{2})(?!\d)')
date=re.compile(r'(?<!\d)(\d{1,2})\s*(?:/|월)\s*(\d{1,2})\s*일?(?!\d)');exam=re.compile(r'중간\s*(?:고사|시험)|기말\s*(?:고사|시험)|mid\s*[-–]?\s*term\s*(?:exam|examination)|final\s*(?:exam|examination)',re.I)
constraints={'mixedPrerecordedAndContact':r'플립|PBL|blended|flip|on\s*/\s*off|사전.*오프라인|online.*offline','recordedOnly':r'사전제작|사전\s*녹화|pre[- ]?recorded|uploaded\s*video','individuallyAssigned':r'개별|현장실습|individual\s*(?:study|assignment)|field\s*trip','unknownOrChange':r'미정|추후|별도\s*공지|변경|TBD|TBA|to\s*be\s*(?:updated|announced)|tentative|subject\s*to','officeOrConsultation':r'office\s*hour|면담|상담','moduleOrIntensive':r'모듈|module|집중|intensive','examNoActualTimeOrDateInference':r'중간|기말|mid[- ]?term|final'}
records=[]
for f in sorted(src.glob('*-education-cache.json')):
 try:d=json.load(open(f))
 except (OSError,ValueError):continue
 text=d.get('educationFullText','');fr=d.get('currentFileRow',{});key=d.get('offeringCode');identity=fr.get('GAESUL_YEAR')=='2026' and fr.get('GAESUL_TERM')=='20' and fr.get('HAKSU_NO','')+'-'+fr.get('BUNBAN','')==key
 clocks=[];dates=[];examclaims=[]
 for m in clock.finditer(text):
  h,mi,h2,mi2=map(int,m.groups());valid=h<24 and h2<24 and mi<60 and mi2<60 and h*60+mi<h2*60+mi2
  context=text[max(0,m.start()-80):m.end()+80];office=bool(re.search(constraints['officeOrConsultation'],context,re.I));clocks.append({'literal':m.group(0),'startMinute':h*60+mi,'endMinute':h2*60+mi2,'validClock':valid,'officeNearbyMustNotBecomeClassHH':office,'offset':m.start()})
 for m in date.finditer(text):
  mo,day=map(int,m.groups())
  try:dt=datetime.date(2026,mo,day)
  except ValueError:continue
  dates.append({'literal':m.group(0),'dateConditionalOnCurrent2026Primary':dt.isoformat(),'weekdayComputedNotPrinted':dt.isoweekday(),'withinVerifiedOrdinarySchoolPeriod':datetime.date(2026,8,31)<=dt<=datetime.date(2026,12,18),'offset':m.start()})
 for line in text.splitlines():
  if not exam.search(line):continue
  cs=list(clock.finditer(line));ds=list(date.finditer(line))
  if cs and ds and not re.search(r'약\s*\d|approx|TBD|TBA|미정|추후',line,re.I):
   examclaims.append({'exactClockLiterals':[m.group(0) for m in cs],'dateLiterals':[m.group(0) for m in ds],'physicalModeLiteral':bool(re.search(r'대면\s*시험|오프라인.*시험|시험.*오프라인',line)),'stillNeedsWholeConstraintAndIdentityConsistency':True,'appointmentGenerated':False})
  # Exact jointly-operated calculus exams: literal date+HH, no weekly or office-hour projection.
 normalized=re.sub(r'\s+',' ',text)
 calculus=[]
 if key and re.search(re.escape(key.split('-')[0])+r'(?:\s*[-–]\s*|.{0,20}\()'+re.escape(key.split('-')[1])+r'\b',normalized) and ('오프 라인으로 진행' in normalized or '오프라인으로 진행' in normalized or 'in person (offline)' in normalized):
  patterns=[(r'(?:중간고사(?:는| 는)?|Midterm:)\s*(?:–\s*)?(?:10월\s*20일\(화\)|Oct\.\s*20\s*\(Tue\))\s*,?\s*18:00\s*[-–∼]\s*19:00','2026-10-20',1080,1140),(r'(?:기말고사(?:는| 는)?|Final:)\s*(?:–\s*)?(?:12월\s*15일\(화\)|Dec\.\s*15\s*\(Tue\))\s*,?\s*18:00\s*[-–∼]\s*19:00','2026-12-15',1080,1140),(r'Midterm:\s*Oct\.\s*21\s*\(Wed\),\s*16:30\s*[-–]\s*17:30','2026-10-21',990,1050),(r'Final:\s*Dec\.\s*16\s*\(Wed\),\s*16:30\s*[-–]\s*17:30','2026-12-16',990,1050)]
  for pat,day,start,end in patterns:
   m=re.search(pat,normalized,re.I)
   if m:calculus.append({'date':day,'weekday':datetime.date.fromisoformat(day).isoweekday(),'startMinute':start,'endMinute':end,'classroom':'','deliveryMode':'inPerson','sourceLiteral':m.group(0)})
  # Classify exact fragments only; header and full constraints remain mandatory to projection.
 normalizedExam=re.compile(r'(?:mid\s*[-–]?\s*term|final)(?:\s*(?:exam|examination))?\s*[:：–-]?\s*(?:Oct\.?|October|Dec\.?|December)\s*\d{1,2}.{0,40}?\d{1,2}:\d{2}\s*[-–∼~]\s*\d{1,2}:\d{2}',re.I)
 englishExamFragments=[m.group(0) for m in normalizedExam.finditer(normalized)]
 header=text[:1800];years=[int(y) for y in re.findall(r'(?:Fall|Spring|Autumn|학년도/학기|Semester)\s*[:：]?\s*(20\d{2})|(?:(20\d{2}))\s*(?:학년도|년\s*[12]\s*학기)',header,re.I) for y in y if y];headers=[]
 for m in re.finditer(r'(?:Course\s*(?:No\.?|number|code)|Class\s*code|학수번호(?:-분반)?)\s*[:：]?\s*([A-Z]{2,6}\s*\d{3,4}(?:\s*-\s*[A-Z0-9]{1,2})?)',header,re.I):headers.append(re.sub(r'\s+','',m.group(1)).upper())
 owncodeconflict=any(x.split('-')[0]!=key.split('-')[0] for x in headers) if key else False
 flags={k:bool(re.search(v,text,re.I)) for k,v in constraints.items()};category='exactExamClaimsNeedBoundedOwnScopeProjection' if examclaims or calculus or englishExamFragments else 'primaryExtractedNeedsConstraintOrClockEvidence'
 if d.get('potentialGlyphExtractionGap'):category='glyphOrTextCompletenessGapHeld'
 if any(y!=2026 for y in years) or owncodeconflict:category='ownHeaderPotentialIdentityConflictHeld'
 records.append({'offeringCode':key,'sourceFile':str(f),'sourceJSONSHA256':hashlib.sha256(f.read_bytes()).hexdigest(),'originalSHA256':d.get('sha256'),'exactCurrentPrimaryAssociation':identity,'humanWholeReadClaim':False,'educationalTextComputerProcessed':True,'category':category,'ownHeaderYearSuggestions':years,'ownHeaderCodeSuggestions':headers,'ownHeaderCodeConflictSuggestion':owncodeconflict,'clockClaims':clocks,'dateClaims':dates,'constraints':flags,'exactExamClaimSuggestions':examclaims,'englishExactExamFragmentSuggestions':englishExamFragments,'calculusOwnPhysicalExamLiteralSuggestions':calculus,'appointmentGenerated':False,'rawNativeOrCandidateChanged':False})
counts=collections.Counter(r['category'] for r in records);receipt={'sourceOnly':True,'SDKExecuted':False,'productModified':False,'completionClaim':False,'processedEducationalJSONs':len(records),'processedUniqueOfferings':len(set(r['offeringCode'] for r in records)),'categories':dict(counts),'humanWholeReadCountAdded':0,'newReservations':0,'allParsedDatesAreConditionalClaimsNotInventedAppointments':True,'ordinalGregorianMappingApplied':False,'officeHHNeverApplied':True,'lastUpdatedAt':datetime.datetime.now().astimezone().isoformat()}
(out/'parsed-primary-source-queue.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n');(out/'processing-progress.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n');print(json.dumps(receipt,ensure_ascii=False))
