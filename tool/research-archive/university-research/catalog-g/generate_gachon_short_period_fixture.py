"""Research fixture from validated public bounds; never a full catalog support claim."""
import collections,datetime,json,pathlib,re
p=pathlib.Path(__file__).resolve().parent
a=json.loads((p/'gachon-short-course-period-candidates.json').read_text())
rows=[];missing=[]
for r in a['rows']:
 code=r['sourceRow']['HAKSU_NO'];period=r['candidatePeriod']
 if period is None:
  missing.append({'courseCode':code,'title':r['sourceRow']['SUBJECT_NM_KOR'],'reasons':r['reasons']});continue
 start=datetime.date.fromisoformat(period['start']);end=datetime.date.fromisoformat(period['endExclusive']);assert start<end
 official_weekdays=sorted(set('월화수목금토일'.index(d) for d in re.findall('[월화수목금토일]',r['sourceRow']['TIME'] or '')))
 occurrences=[(start+datetime.timedelta(days=i)).isoformat() for i in range((end-start).days) if (start+datetime.timedelta(days=i)).weekday() in official_weekdays]
 # These are calendar occurrences of published regular weekdays, not separately announced sessions.
 row={'campus':r['campus'],'category':r['category'],'officialCourseCode':code,'sourceRow':r['sourceRow'],'period':period,'publishedWeekdaysMondayZero':official_weekdays,'regularWeekdayOccurrencesInsidePublishedBounds':occurrences,'occurrencesAreDerivedNotIndividuallyPublished':True,'completeScheduleVerified':False,'contextReview':r['contextReview'],'weeklyRows':r['weeklyRows']}
 rows.append(row)
assert len(rows)+len(missing)==490
assert len({(r['campus'],r['officialCourseCode']) for r in rows})==len(rows)
out={'researchOnly':True,'productionActivationAllowedByThisFixture':False,'completionClaim':False,'term':'2026-2','auditedShortCourseCount':490,'publishedPeriodBoundCount':len(rows),'missingOrConflictingBoundCount':len(missing),'boundCountByTitleDuration':dict(collections.Counter(re.search(r'\((12|4|5)주',r['sourceRow']['SUBJECT_NM_KOR'])[1] for r in rows)),'unknownClockMustNotBeInvented':True,'weeklyEndMeans':'last date of the final published teaching week; not separately published final meeting day','rows':rows,'missing':missing}
(p/'gachon-short-course-normalized-period-fixture.json').write_text(json.dumps(out,ensure_ascii=False,indent=2))
print('published bounds',len(rows),'unresolved bounds',len(missing),out['boundCountByTitleDuration'])
