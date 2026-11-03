"""Read only current public undergraduate grid; document locators are not course codes."""
from pathlib import Path
from datetime import date, timedelta
import hashlib, json, re, urllib.parse
import openpyxl

ROOT = Path(__file__).resolve().parent
OLD = ROOT.parent.parent / 'catalog-g'
FILE = OLD / 'gjue2026-2-final0823.xlsx'
URL = 'https://www.gjue.ac.kr/attach/3e083f090615eb3e96611aa403e94224/5e71f4afee0548f3702e6acd40270b82'
NOTICE = 'https://www.gjue.ac.kr/kor/article/BBSMSTR_000000000107/12732'
def save(name, value):
    p = ROOT / name
    p.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    return hashlib.sha256(p.read_bytes()).hexdigest()

wb = openpyxl.load_workbook(FILE, data_only=True)
original = json.loads((OLD / 'gjue2026-2-final0823-raw.json').read_text())
live = json.loads((ROOT / 'gjue-current-source-live-receipt-20261008.json').read_text())
assert live['sameAsPreservedXlsx'] is True
assert live['SHA256'] == hashlib.sha256(FILE.read_bytes()).hexdigest()
courses, receipt, mixed, held_blocks = [], [], [], []
for sheet in wb.worksheets[:4]:
    grade = int(sheet.title[0])
    assert sheet['E2'].value == f'{grade}학년 시간표'
    for day in range(5):
        for column in range(5, 53, 4):
            slots = []
            for period in range(9):
                row = 5 + day * 63 + period * 7
                vals = [str(sheet.cell(row+j, column).value).strip() if sheet.cell(row+j, column).value else '' for j in range(7)]
                if not vals[0]:
                    slots.append(None)
                    continue
                if any(vals[j] for j in [2, 3, 4, 5]) or not vals[1] or not vals[6] or '/' in vals[6] or '\n' in vals[6]:
                    mixed.append({'sheet': sheet.title, 'cell': sheet.cell(row,column).coordinate, 'reason': 'Multiple or incomplete title/professor/room within one period; not converted'})
                    slots.append(None)
                    continue
                clock = str(sheet.cell(row,3).value)
                times = re.findall(r'\d{2}:\d{2}',clock)
                assert len(times) == 2
                assert times == [f'{period+9:02}:00', f'{period+9:02}:50']
                # Independently compare original worksheet cells with predecessor coordinate extraction.
                native_rows = original[sheet.title]['rows']
                for off in [0,1,6]:
                    assert str(native_rows[row+off-1][column-1]).strip() == vals[off]
                slots.append({'row':row,'period':period+1,'courseName':vals[0],'professor':vals[1],'classroom':vals[6], 'start':times[0],'end':times[1], 'nativeClockText':clock})
            i = 0
            while i < 9:
                if slots[i] is None:
                    i += 1
                    continue
                start = i
                key = tuple(slots[i][x] for x in ['courseName','professor','classroom'])
                while i+1 < 9 and slots[i+1] and tuple(slots[i+1][x] for x in ['courseName','professor','classroom']) == key:
                    i += 1
                block = slots[start:i+1]
                first, last = block[0], block[-1]
                cell = sheet.cell(first['row'],column).coordinate
                source_id = URL + '#sheet=' + urllib.parse.quote(sheet.title,safe='') + '&cell=' + cell
                group = f"{grade}학년 {sheet.cell(3,column).value} {sheet.cell(4,column).value}"
                start_minute = int(first['start'][:2])*60
                end_minute = int(last['end'][:2])*60+50
                comments = []
                for slot in block:
                    for off in range(7):
                        for offset_column in range(4):
                            native_cell = sheet.cell(slot['row']+off,column+offset_column)
                            if native_cell.comment:
                                comments.append({'cell':native_cell.coordinate,'text':native_cell.comment.text})
                row = {'sourceId':source_id, 'sheet':sheet.title, 'grade':grade, 'cell':cell, 'column':column, 'studentGroup':group,'courseName':key[0],'professor':key[1],'classroom':key[2], 'weekday':day+1,'startMinute':start_minute,'endMinute':end_minute,'sourceSlotRows':block,'sourceCode':'','sourceSection':'','nativeClassificationIndividuallyKnown':False,'nativeEducationalComments':comments}
                if grade == 2 and key[0] == '체육실기I':
                    row['holdReason']='Current2학년시간표 AC89 comment explicitly says 무용/축구/생존수영 각5주씩 팀티칭; all same-title blocks conservatively held since individual component dates/teacher/room mapping unknown, without asserting comment scope covers every class'
                    held_blocks.append(row)
                    i += 1
                    continue
                receipt.append(row)
                meetings = []
                d = date(2026,9,1)
                while d <= date(2026,12,7):
                    ds = d.isoformat()
                    # Potential national holiday dates are conservatively held, not presented as school-specific verified closure.
                    held = ds in ['2026-09-24','2026-09-25','2026-10-05','2026-10-09'] or (grade == 3 and '2026-10-19' <= ds <= '2026-11-13')
                    if d.isoweekday() == day+1 and not held:
                        meetings.append({'date':ds,'weekday':day+1,'startMinute':start_minute,'endMinute':end_minute,'classroom':key[2]})
                    d += timedelta(days=1)
                note = '공개 주간 예약 계획, 실제 운영/날짜 미확인. 내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다. 교과목코드·개별분반·학점·이수구분은 미공개로 빈 값/미확인입니다. 학년·반·심화과정 열은 원문 학생집단 범위이며 개별 수강분반으로 추론하지 않습니다. 제목의 A/a 등 표기는 원문 그대로 보존하고 별도 코드/분반으로 해석하지 않습니다. 현재 공개 파일은 원문과 일치하나 공지상 수시변경 가능, 최신 강좌별 폐강 대조 미완료입니다. 공개50분 교시 시각을 보존하며 연속교시 사이 휴게시간은 포함될 수 있습니다. 건물/강의실은 원문 그대로, 물리 캠퍼스는 미확인입니다. 9월24~25일·10월5일·10월9일은 휴일 가능일로 보수적 예약 보류하며 학교별 휴강 직접 확인은 미완료입니다. 12월8~14일 지정보강과12월15~21일 기말고사는 원문 일정 근거로 예약 제외, 실제 보강일별 요일 연결은 미공개입니다. 학기 종강일은 별도 미공개로 기말고사 종료일과 혼동하지 않습니다.'
                if grade == 3:
                    note += ' 3학년 실습Ⅱ10월19일~11월13일은 현재 공식 학사일정 근거로 예약 제외합니다.'
                if comments:
                    note += ' 원문 교육용 메모: ' + ' / '.join(c['text'] for c in comments)
                courses.append({'sourceId':source_id,'referenceKind':'internalDocumentLocator','academicYear':2026,'semester':'2','campus':'unknown','courseCode':'','courseName':key[0],'section':'','professor':key[1],'credits':None,'classification':'','departmentClassifications':{},'departmentCredits':{},'departments':[group],'departmentRemarks':{group:note},'sourceSchedule':'월화수목금'[day]+' '+first['start']+'~'+last['end'],'sourceClassroom':key[2],'period':{'startDate':'2026-09-01','endDate':'2026-12-07'},'scheduleStatus':'scheduled','schedules':meetings,'sourceEducation':{'nativePublicBlock':row,'referenceKind':'internalDocumentLocator','nativeStudentGroupIsNotOpeningDepartment':True,'campusPhysicalProof':False,'latestClosureCompared':False,'schoolSpecificHolidayClosureVerified':False,'wholeSchoolCompletionClaim':False}})
                i += 1

assert len({c['sourceId'] for c in courses}) == len(courses)
assert len({(c['courseName'],c['professor'],c['sourceClassroom'],c['sourceSchedule']) for c in courses}) == len(courses)
source_receipt = {'sourceUrl':URL,'noticeUrl':NOTICE,'sourceSHA256':live['SHA256'],'sourceFile':'../catalog-g/gjue2026-2-final0823.xlsx','liveCurrentFileMatched':True,'undergraduateSheetNames':[s.title for s in wb.worksheets[:4]],'graduateSheetsExcluded':['원','(대학원시수raw)'],'nativeCourseCodeCreditRowsEmpty':True,'unambiguousPeriodSlots':sum(len(r['sourceSlotRows']) for r in receipt),'educationRows':receipt,'omittedMixedBlocks':mixed,'heldEducationalBlocks':held_blocks,'sourceContactStaffStudentFieldsSaved':False,'sourceRawOriginalUnchanged':True}
save('gjue-current-unambiguous-source-20261008.json',source_receipt)
dataset = {'schemaVersion':2,'universityId':'gjue','institutionId':'institution:academyinfo:0000251','campus':'unknown','campusName':'캠퍼스 미확인','academicYear':2026,'semester':'2','publishedDate':'2026-08-23','sourceUrl':NOTICE,'candidateRevision':'public-blocks-partial-v1','completionClaim':False,'courses':courses}
name='gjue-unknown-2026-2.public-blocks-partial-v1.json'
h=save(name,dataset)
audit={'file':name,'SHA256':h,'courses':len(courses),'datedSlots':sum(len(c['schedules']) for c in courses),'nativePeriodSlots':source_receipt['unambiguousPeriodSlots'],'excludedMixedOrIncompleteBlocks':len(mixed),'actualDocumentLocatorsUnique':True,'exactTitleTeacherRoomClockDuplicateCount':0,'nativeXlsxAndPredecessorCellsIndependentlyEqual':True,'latestClosureCompared':False,'termEndDatePublished':False,'campusPhysicalProof':False,'sourceStaffStudentContactSaved':False,'productionChanged':False,'wholeSchoolCompletionClaim':False}
save('gjue-current-public-blocks-partial-v1-audit.json',audit)
print(audit)
