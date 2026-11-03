"""Exact observed excerpt dispositions; no new source collection or activation.
Topical, book/chapter/scale numbering, grade fractions, performance recording,
and classroom digital tools do not change the published attendance rule.
Actual/possible field visit, no-class, attendance changes and undetermined dates
stay pending. This file never rewrites the fixed615 registration candidate.
"""
from pathlib import Path
import json,hashlib,collections
P=Path(__file__).parent
# Each index selects an exact observed educational excerpt, not a substring alias.
# Ranges were read in the current stored supplementary excerpt inventory.
TOPICAL=set([10,11,13,14,19,20,39,40,41,60,61,69,73,79,86,87,94,95,96,97,98,99,102,104,105,106,107,108,109,110,111,112,113,114,116,117,119,122,125,126,130,131,132,134,145,146,149,150,153,154,157,158,218,230,231,232,233,234,235,236,237,238,239,240,243,244,245,246,247,249,261,262,263,264,265,272,273,274,275,276,277,287,289,290,292,293,294,295,296,297,298,299,302,303,305,306,307,308,309,310,311,312,314,315,317,319,320,321,322,323,324,325,326,327,328,329,330,332,333,335,337,338,339,340,341,342,343,344,345,346,347,348,349,350,351,352,353,354,355,357,358,359,360,361,362,368,369,370,372,373,391,397,398,399,400,401,402,403,404,405,406,407,408,409,410,411,412,413,414,415,416,417,418,419,420,421,422,423,424,425,426,428,429,430,431,432,433,434,435,459,460,461,462,463,467,469,470,471,472,473,474,475,476,477,478,479,480,481,482,483,484,499,500,501,502,503,504,505,506,507,508,509,510,511,512,513,514,515,516,517,518,519,520,521,522,523,524,525,526,527,528,529,531,532,533,534,535,536,537,538,539,540,541,542,543,544,545,546,547,548,549,550,553,554,571,573,574,575,576,577,578,579,580,581,582,583,584,585,586])
for a,b in [(1,8),(21,38),(80,84),(138,144),(159,217),(219,229),(250,260),(266,271),(278,285),(374,382),(384,388),(436,456),(485,497)]:TOPICAL.update(range(a,b+1))
# Ambiguous creative field collection/exhibition context remains pending.
TOPICAL.difference_update({122,370,372})
def review():
 inventory=P/'mokpo-additional-288-semantic-review-20261008.json'
 assert hashlib.sha256(inventory.read_bytes()).hexdigest()=='82509cb9d643b2e17298610c6ecb60c46c5b9023500e3cd0c7d72f7e1728484a', 'Observed inventory changed: indices must be individually re-reviewed.'
 entries=json.loads(inventory.read_text())
 unique=list(dict.fromkeys(s for r in entries for s in r['selectedEducationalExcerpts']))
 assert len(unique)==587
 decisions={text:dict(excerptSha256=hashlib.sha256(text.encode()).hexdigest(),exactEducationalText=text,disposition='ordinaryRuleUnaffected' if i in TOPICAL else 'individualOperatingReviewPending',reason='Observed learning topic, chapter/decimal/scale, grading fraction, assignment, classroom tool or performance-recording context; no instruction changing attendance date/clock/room/mode.' if i in TOPICAL else 'Retain individually: actual or conditional attendance/field/makeup/date context needs source-specific reconciliation; never interpret as impossible.') for i,text in enumerate(unique)}
 courses=[]
 for r in entries:
  cases=[decisions[s] for s in r['selectedEducationalExcerpts']]
  state='supplementaryOrdinaryCandidate' if cases and all(c['disposition']=='ordinaryRuleUnaffected' for c in cases) else 'individualOperatingReviewPending'
  courses.append(dict(courseCode=r['courseCode'],section=r['section'],state=state,excerpts=cases))
 result=dict(checkedAt='2026-10-08',newCollection=False,fixed615CandidateChanged=False,productionReady=False,reviewedCourses=288,counts=dict(collections.Counter(c['state'] for c in courses)),courses=courses)
 (P/'mokpo-additional-semantic-dispositions-20261008.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');return result
if __name__=='__main__':print(review()['counts'])
