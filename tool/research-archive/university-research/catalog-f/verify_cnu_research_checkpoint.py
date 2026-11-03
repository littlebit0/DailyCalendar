"""Source-aware checks of exact source clocks, rooms and the printed-date proof."""
from pathlib import Path
import json,re,datetime,collections,hashlib
R=Path(__file__).resolve().parent
cat={r['COURSE_NO']:r for r in json.loads((R/'cnu-current-catalog-education.json').read_text())}
projection=json.loads((R/'cnu-current-clock-projection.json').read_text());byid={r['courseId']:r for r in projection}
assert len(cat)==len(projection)==3888
assert sum(r['status']=='closed' for r in projection)==142
assert sum(r['status']=='blankTime' for r in projection)==635
assert sum(r['status']=='parsedExactClock' for r in projection)==3111
for row in projection:
 if row['status']=='parsedExactClock':
  # Every displayed clock and nested location must survive round-trip unchanged.
  norm=lambda s:re.sub(r'[,;\s]+','',s)
  assert norm(''.join(m['rawDisplayedClock'] for m in row['actualClockMeetings']))==norm(cat[row['courseId']]['TMTBL_INFO']),row['courseId']
 assert row['scheduleAllowed'] is False
assert byid['1001-7043-00']['actualClockMeetings'][0]['location']=='개발실(인재개발원3층)'
assert [(m['weekday'],m['startMinute'],m['endMinute'],m['location']) for m in byid['1159-7007-00']['actualClockMeetings']]==[(3,780,840,'체109(경기장)-01'),(3,840,960,'체109(경기장)-01')]
p=json.loads((R/'cnu-first-dated-proof-20261008.json').read_text());dates=[m['date'] for m in p['meetings']]
assert len(dates)==len(set(dates))==15
assert dates[-2:]==['2026-12-02','2026-12-16'] and '2026-12-09' not in dates
assert all(datetime.date.fromisoformat(d).isoweekday()==3 for d in dates)
assert all((m['startMinute'],m['endMinute'],m['location'])==(900,1080,'자2201') for m in p['meetings'])
assert p['periodStart']==min(dates) and p['periodEnd']==max(dates)
r=json.loads((R/'cnu-reviewed-operation-cases-20261008.json').read_text());ids={x['courseId']:x for x in r['reviews']}
assert ids['1001-8005-12']['kind']=='faceToFaceAndUndatedLiveException'
assert ids['1001-8005-13']['kind']=='currentPlanWrongSemesterExamMonths'
assert ids['1001-7038-00']['educationFacts']['makeupDeliveryMode']=='asynchronous'
assert all(x['scheduleAllowed'] is False for x in r['reviews'])
privacy=[];keys=[];acquired=0
for f in (R/'cnu-current-education').glob('*.json'):
 j=json.loads(f.read_text());acquired+=1
 for section in ('header','weeks'):
  for row in j.get(section,[]):
   for k,v in row.items():
    if re.search(r'STAFF_NO|PHONE|EMAIL|SESSION|PASSWORD|TOKEN|MNG_NO',k,re.I):keys.append(f.stem+':'+k)
    if isinstance(v,str) and re.search(r'https?://|[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}|(?<!\d)0\d{1,2}[- .]\d{3,4}[- .]\d{4}(?!\d)|(?<!\d)\d{3}[- ]\d{4}(?!\d)|(?<!\d)\d{3}\s+\d{4}\s+\d{4}(?!\d)',v):privacy.append({'courseId':f.stem,'field':k})
assert not keys and not privacy,(keys,privacy)
audit={'verifiedOn':'2026-10-08','wholeCurrentCatalogRows':3888,'exactClocksAndNestedRoomsRoundTrip':3111,'blankTime':635,'closed':142,'printedDateMeetings':15,'reviewedBlockedOperationCases':len(r['reviews']),'educationCacheFilesPrivacyChecked':acquired,'forbiddenFields':keys,'contactURLOrAccessNumberPatterns':privacy,'collectionStillInProgress':not json.loads((R/'cnu-current-education-collection-audit.json').read_text())['finished'],'wholeSemanticReviewComplete':False,'productionOrDartRestoreVerified':False}
(R/'cnu-research-checkpoint-verification.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2));print(json.dumps(audit,ensure_ascii=False))
