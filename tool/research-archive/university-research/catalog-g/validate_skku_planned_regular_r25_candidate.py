"""Independent, network-free preservation and planned-date audit."""
import collections, datetime, hashlib, json, re
from pathlib import Path
P=Path(__file__).resolve().parent

def load(name):return json.loads((P/name).read_text())

def main():
 manifest=load('skku-partial-audited-20261008-r25-sha-manifest.json')
 assert manifest['actualAttendanceConfirmed'] is False and manifest['wholeOperatingAuditFinished'] is False
 current={r['HAKSU_NO_BUNBAN']:r for r in load('skku-final-current-educational-source.json')['records'] if r['JUKYONGHAKWI_GB']!='05'}
 evidence={r['offeringCode']:r for r in load('skku-public-operating-plan-audit.json')['records']}
 rules=load('skku-current-term-closure-rule-evidence.json');start=datetime.date.fromisoformat(rules['term']['startDate']);end=datetime.date.fromisoformat(rules['term']['endDate']);closed=set(rules['nationalHolidayDates']['dates'])|set(rules['closureRule']['schoolSpecificClosures'])
 counts=collections.Counter();preserved=0;planned=0;meetings=0;rawchecks=0;blank=0;exam=0
 for entry in manifest['campuses']:
  path=Path(entry['path']);assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256']
  old=load(f"skku-{entry['campus']}-2026-2.partial-audited-20261008-r21.json");old={c['courseCode']+'-'+c['section']:c for c in old['courses'] if c['scheduleStatus']=='scheduled'}
  base=load(f"skku-{entry['campus']}-2026-2.metadata-safe-unregistered.json");base={c['courseCode']+'-'+c['section']:c for c in base['courses']}
  data=json.loads(path.read_text())
  for c in data['courses']:
   key=c['courseCode']+'-'+c['section'];s=current[key];r=evidence[key];counts[c['scheduleStatus']]+=1
   assert c['sourceSchedule']==s['GYOSI_NAME'] and c['professor']==s['PER_NAME']
   for field in ('sourceId','courseName','credits','sourceClassroom','departments','departmentCredits','departmentClassifications','sourceDegreeCode','sourceTeachingTypeCode','sourceConcentratedType','sourceEducationalMetadata','rawMeetingFrameForReviewOnly'):
    assert c[field]==(old[key][field] if key in old else base[key][field]), (key,field)
   rawchecks+=1
   if key in old:assert c==old[key];preserved+=1
   elif c['scheduleStatus']=='scheduled':
    assert c['scheduleEvidenceKind']=='plannedRegularTimetable' and c['actualAttendanceConfirmed'] is False
    assert s['SUUP_TYPE_CD'] in ('31','33') and s['HAKBU_JIBJUNG_GB']=='N' and r['currentDetailIdentityConfirmed']
    d=r['detail'][0];assert d['PER_NAME'].strip()==s['PER_NAME'].strip()
    assert all(room in d.get('SUUP_GANGUISIL','') for room in c['sourceClassroom'].split(',')), key+' current detail classroom conflict'
    rx=re.compile(r'([월화수목금토일])(?:\[[^\]]*\])?(\d{2}):(\d{2})[-~](\d{2}):(\d{2})')
    frames=lambda value:sorted(tuple(m.groups()) for m in rx.finditer(value))
    assert frames(s['GYOSI_NAME'])==frames(d['SUUP_YOIL_GYOSI'])
    assert not any(x.get('privacySuppressedLineCount') for x in [d]+r['weekly'])
    assert not any(x.get('privacySuppressedLineCount') or x.get('contextTruncated') or x.get('contextLimitReached') for x in r['attachments'])
    expected=[];day=start
    while day<=end:
     if day.weekday()!=6 and day.isoformat() not in closed:expected.extend({**f,'date':day.isoformat()} for f in base[key]['rawMeetingFrameForReviewOnly'] if f['weekday']==day.isoweekday())
     day+=datetime.timedelta(days=1)
    assert c['schedules']==expected
    for dept,note in base[key]['departmentRemarks'].items():
     assert c['departmentRemarks'][dept]==note.replace('수업 운영 미확인: 실제 날짜·수업 방식·휴강·보강을 확인 중입니다.','학교 공시 정규 수업시간에 학기·휴업일을 적용했습니다. 실제 휴·보강 및 시험 시간은 학교 공지를 확인하세요.')
    planned+=1
    blank+=bool(r['weekly']) and not any(w.get('PLAN_WEEK_CONT','').strip() or w.get('BIGO','').strip() for w in r['weekly'])
    exam+=bool(re.search(r'exam|시험|고사',' '.join(w.get('PLAN_WEEK_CONT','') for w in r['weekly']),re.I))
   else:assert not c['schedules']
   meetings+=len(c['schedules'])
 assert preserved==422 and planned==758 and rawchecks==2782 and counts['scheduled']==1180
 result={'checkpoint':'20261008-r25','wholeRawEducationalMetadataIdentityTeacherClockRoomPreservedCount':rawchecks,'r21ExactCourseObjectPreservedCount':preserved,'plannedRegularTimetableCount':planned,'totalScheduledCourseCount':1180,'datedMeetingCount':meetings,'blankTopicsStillHavePublishedPlannedTimesCount':blank,'genericExamTopicsStillHavePublishedPlannedTimesCount':exam,'actualAttendanceConfirmed':False,'wholeOperatingAuditFinished':False,'counts':dict(counts)}
 (P/'skku-partial-audited-20261008-r25-current-detail-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(result)

if __name__=='__main__':main()
