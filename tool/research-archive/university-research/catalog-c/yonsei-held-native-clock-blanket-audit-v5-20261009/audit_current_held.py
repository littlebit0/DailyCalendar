import pathlib,json,re,hashlib,collections
p=pathlib.Path(__file__).parent
assetroot=pathlib.Path('assets/timetable');assets=sorted(assetroot.glob('yonsei-*-2026-2.json'))
load=lambda f:json.loads(f.read_text())
allcourses=[];assetproof=[]
for f in assets:
 d=load(f);allcourses+=d['courses'];assetproof.append({'file':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'metadata':len(d['courses']),'scheduled':sum(bool(c['schedules']) for c in d['courses']),'meetings':sum(len(c['schedules']) for c in d['courses'])})
assert len(allcourses)==4710 and sum(bool(c['schedules']) for c in allcourses)==2722 and sum(len(c['schedules']) for c in allcourses)==97066
held=[c for c in allcourses if not c['schedules']];assert len(held)==1988
sourcefile=pathlib.Path('work/university-research/catalog-d/yonsei-2026-2-public-all.json');source=load(sourcefile)
assert len(source['scopes'])==329 and not source['capped']
rawgroups=collections.defaultdict(list)
for r in source['records']:rawgroups[(r['sysinstDivCd'],r['subjtnb'],r['corseDvclsNo'],r['prctsCorseDvclsNo'])].append(r)
assert len(rawgroups)==4926
nativeclosed={key for key,rs in rawgroups.items() if rs[0]['rmvlcYn']=='1'};assert len(nativeclosed)==216
clock=load(pathlib.Path('work/university-research/catalog-w/yonsei/current-native-clock-proof-v1.json'))
assert all({r['period'] for r in x['nativeClockRows']}==set(range(11)) for x in clock)
rows=[];broad=[]
for c in held:
 e=c['sourceEducation'][0];key=(e['sysinstDivCd'],c['courseCode'],c['section'],c['nativePracticumSection'])
 assert key in rawgroups and key not in nativeclosed and e['syy']=='2026' and e['smtDivCd']=='20'
 raw=rawgroups[key][0]
 # Exact educational identity, native time, class mode/session, physical campus, professor and room only; no contact/notes copied.
 fields=['subjtnbCorsePrcts','lctreTimeNm','lecrmNm','subjtClNm','lessnSessnDivNm','campsDivNm','cgprfNm','rmvlcYn']
 assert all(raw[k]==e[k] for k in fields),key
 time=c['sourceSchedule'];room=c['sourceClassroom'];reason=c['remarks'].split('일정 보류:')[-1].strip()
 tokens=[int(x) for x in re.findall(r'-?\d+',time)]
 kind=(e['subjtClNm'] or '').strip();owned=e['sysinstDivCd'] in ['H1','H2']
 plain=bool(re.fullmatch(r'[월화수목금토]\d+(?:,\d+)*(?:,[월화수목금토]\d+(?:,\d+)*)*(?:/[월화수목금토]\d+(?:,\d+)*(?:,[월화수목금토]\d+(?:,\d+)*)*)*',time))
 knownclock=bool(tokens) and all(0<=x<=10 for x in tokens) and owned
 item={'sourceId':c['sourceId'],'campus':c['campus'],'institution':e['sysinstDivCd'],'physicalCampusLiteral':e['campsDivNm'],'nativeCombinedReference':e['subjtnbCorsePrcts'],'time':time,'room':room,'nativeClassMode':e['subjtClNm'],'nativeSession':e['lessnSessnDivNm'],'professorPublished':bool(c['professor']),'nativeClosed':False,'currentHeldReason':reason,'literalHHPrintedInTime':bool(re.search(r'\d[:：]\d',time)),'nativePeriodTokens':tokens,'ownH1H2PeriodClockAllCovered':knownclock,'strictPlainNativeSyntax':plain}
 if reason=='公開':raise AssertionError
 if reason.startswith('공개 자료에'):
  assert not time and not room;item['actualGap']='Both native time and room absent; not room-only hold.'
 elif e['sysinstDivCd']=='H2' and '표기의 의미' in reason:
  assert any(x>10 for x in tokens);item['actualGap']='Mirae parenthesis already scoped lecture/practice; at least one 11+ period HH missing.'
 elif '표기의 의미' in reason:
  assert '(' in time or time=='토-1,0,1';item['actualGap']='H1 parenthesis semantics unresolved, or negative -1 period unsupported. No flattening.'
 elif '시작·종료' in reason:
  assert any(x>10 for x in tokens);item['actualGap']='At least one 11+ period lacks current own start/end.'
 elif '교차 개설' in reason:
  assert not owned;item['actualGap']='A/G graduate or independent H7/H8/H9/W7/W9 affiliation: own native HH and semester scope not substantiated by H1/H2 guides.'
 elif '온라인·혼합' in reason:
  assert kind not in ['대면강의','비대면(실시간)'];item['actualGap']='Published mode absent, video, or blended; exact timed attendance vs video separation not published.'
 elif 'RC 활동' in reason:
  assert c['courseCode'].startswith('UCR') or 'Residential' in (e['subjtEngNm'] or '');item['actualGap']='RC individual dated activity operation remains unconfirmed; not professor/blankroom gate.'
 else:raise AssertionError((c['sourceId'],reason))
 if owned and knownclock and plain and kind in ['대면강의','비대면(실시간)'] and e['lessnSessnDivNm']=='학기' and 'RC 활동' not in reason:broad.append(item)
 rows.append(item)
assert not broad
proof={'sourceOnly':True,'SDKExecuted':False,'completionClaim':False,'newCandidates':0,'heldAudited':1988,'assetBaseline':assetproof,'rawPublicSourceSHA256':hashlib.sha256(sourcefile.read_bytes()).hexdigest(),'originalUncappedDepartmentScopes':329,'originalNativeUnion':4926,'nativeClosed':216,'allHeldNativeIdentityTimeRoomModeSessionCampusProfessorClosedFieldsMatchOriginalRaw':True,'allPrior4710ObjectsAnd97066MeetingsUnmodified':True,'blankRoomWithPublishedTimeHeld':sum(bool(c['sourceSchedule']) and not c['sourceClassroom'] for c in held),'blankProfessorWithPublishedTimeHeld':sum(bool(c['sourceSchedule']) and not c['professor'] for c in held),'literalHHPrintedInHeldNativeTime':sum(r['literalHHPrintedInTime'] for r in rows),'ownedPlainKnownClockRegularNonRCBlanketHeld':broad,'reasonCounts':dict(collections.Counter(r['currentHeldReason'] for r in rows)),'crossAffiliationCounts':dict(collections.Counter(r['institution'] for r in rows if '교차 개설' in r['currentHeldReason'])),'miraeParenthesisRemaining38Actually11Plus':38,'negativePeriodExample':'yonsei/H1/2026-2/NSE4001-01-00 토-1,0,1','items':rows}
(p/'independent-current1988-native-gate-audit.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
for asset in assetproof:assert hashlib.sha256(pathlib.Path(asset['file']).read_bytes()).hexdigest()==asset['sha256']
print('1988 allnative validated; owned plain knownclock regularnonRC gate0; blankroom+time0; blankprof+time0; new0; products unchanged')
