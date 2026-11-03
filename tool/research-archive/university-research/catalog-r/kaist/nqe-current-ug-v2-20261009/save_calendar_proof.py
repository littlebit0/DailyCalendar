import hashlib,json,re
from pathlib import Path
from html.parser import HTMLParser
R=Path(__file__).parent
class Rows(HTMLParser):
    def __init__(self):super().__init__();self.rows=[];self.row=None
    def handle_starttag(self,t,a):
        if t=='tr':self.row=[]
    def handle_endtag(self,t):
        if t=='tr' and self.row is not None:self.rows.append(' '.join(self.row));self.row=None
    def handle_data(self,d):
        if self.row is not None and d.strip():self.row.append(d.strip())
b=Path('/tmp/kaist-nqe-calendar-20261009.html').read_bytes();p=Rows();p.feed(b.decode())
rows=[t for t in p.rows if any(x in t for x in ['가을학기 개강','가을학기 중간고사','가을학기 학기말 시험','가을학기 종강','추석 연휴','개천절','한글날','연습반 휴강'])]
assert any('12-14' in t for t in rows)
loc=Path('/tmp/kaist-nqe-location-20261009.html').read_bytes()
proof=dict(sourceUrl='https://kaist.ac.kr/kr/html/edu/03110101.html',normalHttpStatus=200,sourceSha256=hashlib.sha256(b).hexdigest(),retrievedDate='2026-10-09',displayedYear=2026,campus='본교',nativeEducationalRows=rows,reservationWindow=dict(startDate='2026-08-31',endDate='2026-12-13',endDerivedFromNextFinalStart=True),excludedAssessmentWindows=[['2026-10-19','2026-10-23'],['2026-12-14','2026-12-18']],holidayExclusion=['2026-09-24','2026-09-25','2026-09-26','2026-10-03','2026-10-05','2026-10-09'],festivalRule='9/18–19 specifically exercise sections only; no general regular closure inferred. NQE UG supplied grid has no Friday slots.',individualExamsOrMakeupUnknown=True,actualAttendanceConfirmed=False,campusProof=dict(sourceUrl='https://nuclear.kaist.ac.kr/class/location.php',normalHttpStatus=200,sourceSha256=hashlib.sha256(loc).hexdigest(),nativeEducationalAddress='대전 광역시 유성구 대학로 291(구성동 373-1) KAIST 원자력및양자공학과',decision='Department own current room-column timetable with official department Daejeon main-campus directions; no room building code invented'),currentWholeOrClosuresVerified=False,completionClaim=False)
(R/'current-calendar-campus-proof.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
b=Path('/tmp/kaist-nqe-curriculum-20261009.html').read_bytes();p=Rows();p.feed(b.decode());selected=[t for t in p.rows if 'NQE.40002' in t and '1:6:3' in t]
(R/'current-undergraduate-operation-crossproof.json').write_text(json.dumps(dict(sourceUrl='https://nuclear.kaist.ac.kr/study/curriculum.php',normalHttpStatus=200,sourceSha256=hashlib.sha256(b).hexdigest(),nativeRows=selected,currentTimetableCode='NQE40002',supportingCurriculumCode='NQE.40002',differentPrintedIdentifiersPreserved=True,aliasNotOfficialOfferingJoin=True,decision='Current UG curriculum 1:6:3 supports exact grid one-hour lecture/six-hour lab; does not establish dated physical delivery/section, curriculum professor not used to overwrite current roster',creditsImported=False,completionClaim=False),ensure_ascii=False,indent=2)+'\n')
