#!/usr/bin/env python3
"""Snapshot JNU's public undergraduate timetable using its normal search forms.
No login, enrolment or authenticated endpoint. Requests are serial and spaced.
Cached public responses permit reproducible offline rebuilding of the catalog.
"""
from __future__ import annotations
import argparse
from collections import Counter
from datetime import date
from html import unescape
from html.parser import HTMLParser
from http.cookiejar import CookieJar
import json
from pathlib import Path
import re
import time
from urllib.parse import urlencode
from urllib.request import Request, build_opener, HTTPCookieProcessor

URL = 'https://hakstd.jnu.ac.kr/web/Suup/TimeTable/Suup030_C.aspx'
PREFIX = 'ctl00$ctl00$ContentPlaceHolder$ContentPlaceHolderSub$'
MODULE_SOURCE = 'https://engedu.jnu.ac.kr/bbs/engedu/2411/1050036/artclView.do'
SATURDAY_MODULE_SOURCE = 'https://physics.jnu.ac.kr/bbs/physics/2140/828207/download.do'

class Form(HTMLParser):
    def __init__(self, markup):
        super().__init__()
        self.fields, self.selects = {}, {}
        self.current = self.option = None
        self.feed(markup)
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'input' and attrs.get('name'):
            if attrs.get('type') not in ('radio', 'checkbox') or 'checked' in attrs:
                self.fields[attrs['name']] = attrs.get('value', '')
        elif tag == 'select':
            self.current = attrs.get('name')
            self.selects[self.current] = []
        elif tag == 'option' and self.current:
            self.option = {'value': attrs.get('value', ''), 'text': '', 'selected': 'selected' in attrs}
    def handle_data(self, data):
        if self.option is not None:
            self.option['text'] += data
    def handle_endtag(self, tag):
        if tag == 'option' and self.option is not None:
            self.selects[self.current].append(self.option)
            self.option = None
        if tag == 'select':
            options = self.selects[self.current]
            self.fields[self.current] = next((o['value'] for o in options if o['selected']), options[0]['value'] if options else '')
            self.current = None
    def options(self, name):
        return [o for o in self.selects.get(PREFIX + name, []) if o['value'] and o['text'].strip() != '선택하세요']

class PublicSearch:
    def __init__(self, cache, fetch, max_requests=1200):
        self.cache, self.fetch = cache, fetch
        cache.mkdir(parents=True, exist_ok=True)
        self.opener = build_opener(HTTPCookieProcessor(CookieJar()))
        self.requests = 0
        self.max_requests = max_requests
    def request(self, key, markup=None, changes=None, event=None):
        target = self.cache / (key + '.html')
        if target.exists():
            return target.read_text()
        if not self.fetch:
            raise FileNotFoundError(target)
        body = None
        if markup is not None:
            fields = Form(markup).fields
            fields.update({PREFIX + k: v for k, v in changes.items()})
            fields.update({'__EVENTTARGET': PREFIX + event, '__EVENTARGUMENT': ''})
            body = urlencode(fields).encode()
        for attempt in range(3):
            if self.requests >= self.max_requests:
                raise ValueError('Public request limit reached; resume from cache')
            try:
                time.sleep(.35 if attempt == 0 else 2 * attempt)
                self.requests += 1
                with self.opener.open(Request(URL, data=body, headers={'User-Agent':'Mozilla/5.0', 'Referer':URL}), timeout=30) as response:
                    response_body = response.read(8 * 1024 * 1024 + 1)
                    if len(response_body) > 8 * 1024 * 1024:
                        raise ValueError('Unexpectedly large public response')
                    result = response_body.decode('utf-8')
                if 'ContentPlaceHolder_ContentPlaceHolderSub_ddlYear' not in result:
                    raise ValueError('Unexpected response from public timetable')
                target.write_text(result)
                return result
            except Exception:
                if attempt == 2:
                    raise
    def search(self, key, markup, changes, year, semester):
        fields = {k.removeprefix(PREFIX): v for k, v in Form(markup).fields.items() if k.startswith(PREFIX)}
        fields.update(changes)
        hidden = {
            'hdYY': str(year), 'hdTerm': semester,
            'hdCURR_KIND': fields.get('ddlSubj', ' '),
            'hdCAMPUS_FG': fields.get('ddlDaesang', ' '),
            'hdNOW_GRADE': fields.get('ddlNOW_GRADE', '0'),
            'hdCOLL': fields.get('ddlColl', ' '), 'hdDEPT': fields.get('ddlDept', ' '),
            'hdYY_FG': fields.get('ddlHakMoonApply_year', ' '),
            'hdSTUDY_AREA': fields.get('ddlCulture', ' '), 'hdDETAIL_AREA': fields.get('ddlDetail', ' '),
        }
        return self.request(key, markup, {**changes, **hidden}, 'lBtnLst')

def text(markup):
    markup = re.sub(r'<br\s*/?>', '\n', markup, flags=re.I)
    return unescape(re.sub(r'<[^>]+>', '', markup)).strip()

def table_rows(markup):
    found = re.search(r'<table\b[^>]*\bid="ContentPlaceHolder_ContentPlaceHolderSub_gvData"[^>]*>(.*?)</table>', markup, re.S)
    if not found:
        if '시간표 검색결과가 없습니다' in markup:
            return []
        raise ValueError('Missing public course table')
    if re.search(r"Page\$\d", found.group(1)):
        raise ValueError('Unexpected pagination; refusing an incomplete catalog')
    result = []
    for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>', found.group(1), re.S):
        cells = [text(c) for c in re.findall(r'<td\b[^>]*>(.*?)</td>', row, re.S)]
        if not cells:
            continue
        if len(cells) == 1 and cells[0] == '시간표 검색결과가 없습니다':
            continue
        if len(cells) != 14:
            raise ValueError(f'Unexpected course row: {len(cells)} columns')
        result.append(cells)
    return result

def meetings(schedule, classroom):
    """Retain real 50/75-minute module ends; the app rounds display separately."""
    compact = re.sub(r'\s+', '', schedule)
    if not compact:
        return [], 'unscheduled'
    tokens = re.findall(r'([월화수목금토일])(\d+)', compact)
    if ''.join(day + period for day, period in tokens) != compact:
        return [], 'unrecognized'
    rooms = [part.strip() for part in classroom.splitlines() if part.strip()]
    # The official cell can repeat a room whose own name contains a <br>,
    # e.g. "연암 / 고익배홀(100)". Only collapse an exactly repeated pattern.
    if len(tokens) > 1 and len(rooms) > len(tokens) and len(rooms) % len(tokens) == 0:
        width = len(rooms) // len(tokens)
        chunks = [rooms[i:i + width] for i in range(0, len(rooms), width)]
        if all(chunk == chunks[0] for chunk in chunks):
            rooms = ['\n'.join(chunks[0])]
    if len(rooms) not in (0, 1, len(tokens)):
        return [], 'unrecognized'
    entries = []
    for index, (day, period_text) in enumerate(tokens):
        weekday, period = '월화수목금토일'.index(day) + 1, int(period_text)
        if day in '화목':
            # The 2026-2 notice contradicts another official module table for
            # period 9. Preserve that raw notation instead of guessing a time.
            if period not in (*range(9), 10):
                return [], 'unrecognized'
            start, duration, break_minutes = 450 + period * 90, 75, 15
        elif day in '월수금':
            if period not in (*range(13), 14, 15):
                return [], 'unrecognized'
            start, duration, break_minutes = 480 + period * 60, 50, 10
        elif day == '토':
            # 2026 official freshman handbook, page 5, defines Saturday.
            if not 0 <= period <= 15:
                return [], 'unrecognized'
            start, duration, break_minutes = 480 + period * 60, 50, 10
        else:
            return [], 'unrecognized'  # Neither official module defines Sunday.
        entries.append((weekday, start, start + duration, rooms[index] if len(rooms) > 1 else rooms[0] if rooms else '', break_minutes))
    result = []
    for weekday, start, end, room, gap in sorted(set(entries)):
        if result and result[-1]['weekday'] == weekday and result[-1]['classroom'] == room and result[-1]['endMinute'] + gap == start:
            result[-1]['endMinute'] = end
        else:
            result.append({'weekday': weekday, 'startMinute':start, 'endMinute':end, 'classroom':room})
    return result, 'scheduled'

def course(cells, department, year, semester):
    campus = {'광주':'gwangju', '여수':'yeosu'}.get(cells[0])
    if not campus:
        raise ValueError('Unrecognized campus: ' + cells[0])
    identity = re.fullmatch(r'([A-Za-z0-9]+)-(\d+)', re.sub(r'\s+', '', cells[2]))
    if not identity:
        raise ValueError('Invalid subject/section: ' + cells[2])
    code, section = identity.groups()
    credits = float(re.match(r'\d+(?:\.\d+)?', cells[7]).group(0))
    schedules, status = meetings(cells[11], cells[12])
    title = cells[1]
    annotations = []
    parts = title.splitlines()
    annotation_pattern = re.compile(r'(?:(?:영어|독일어|이태리어|일본어|중국어|불어) \d+%|대학 간 학점교류 원격수업|대학 간 공동 교육과정|군 복무 원격수업|거점국립대학원격수업\([^\n]+\)|혼합수업\([^\n]+\)|콘텐츠 활용수업|실시간 화상 수업)')
    while len(parts) > 1 and annotation_pattern.fullmatch(parts[-1]):
        annotations.insert(0, parts.pop())
    title, annotation = '\n'.join(parts), '\n'.join(annotations)
    remarks = '\n'.join(v for v in [annotation, cells[13], ('수강 대상: ' + cells[9]) if cells[9].strip() else ''] if v)
    return {
        'sourceId':f'jnu-{campus}-{year}-{semester}-{code}-{section}', 'campus':campus,
        'academicYear':year, 'semester':semester, 'courseCode':code, 'courseName':title,
        'section':section, 'professor':cells[10], 'credits':credits,
        'departmentCredits':{department:credits}, 'departments':[department],
        'departmentClassifications':{department:cells[3]}, 'departmentRemarks':{department:remarks},
        'sourceSchedule':cells[11], 'sourceClassroom':cells[12], 'scheduleStatus':status, 'schedules':schedules,
    }

def collect(search, year, semester):
    initial = search.request('initial')
    form = Form(initial)
    if form.fields[PREFIX+'ddlYear'] != str(year):
        initial = search.request('year-'+str(year), initial, {'ddlYear':str(year)}, 'ddlYear')
    if Form(initial).fields[PREFIX+'ddlTerm'] != semester:
        initial = search.request('term-'+semester, initial, {'ddlTerm':semester}, 'ddlTerm')
    selected = Form(initial).fields
    if selected.get(PREFIX+'ddlYear') != str(year) or selected.get(PREFIX+'ddlTerm') != semester:
        raise ValueError('Public form did not select the requested year/semester')
    if selected.get(PREFIX+'ddlDaesang') != '0':
        raise ValueError('Public form must include both campuses')
    major = search.request('major', initial, {'ddlSubj':'2'}, 'ddlSubj')
    records, groups = [], []
    colleges = {}
    for option in Form(major).options('ddlColl'):
        colleges.setdefault(option['value'], option['text'].strip())
    if not colleges:
        raise ValueError('Missing public undergraduate college filters')
    for college_id, college_name in colleges.items():
        college = search.request('college-'+college_id, major, {'ddlColl':college_id}, 'ddlColl')
        for dept in Form(college).options('ddlDept'):
            key = 'major-'+college_id+'-'+dept['value']
            rows = table_rows(search.search(key, college, {'ddlDept':dept['value']}, year, semester))
            name = college_name+' / '+dept['text'].strip()
            records.extend((row, name) for row in rows)
            groups.append({'kind':'major','college':college_name,'department':dept['text'].strip(),'rows':len(rows)})
        print('college', college_name, 'rows', len(records), 'requests', search.requests, flush=True)
    general = search.request('general', initial, {'ddlSubj':'1'}, 'ddlSubj')
    admissions = {o['value']:o['text'] for o in Form(general).options('ddlHakMoonApply_year') if o['value'] != '1905' and int(o['value']) <= year}
    if not admissions or str(year) not in admissions:
        raise ValueError('Missing public undergraduate admission-year filters')
    for admission in admissions:
        admitted = search.request('admission-'+admission, general, {'ddlHakMoonApply_year':admission}, 'ddlHakMoonApply_year')
        for area in Form(admitted).options('ddlCulture'):
            area_page = search.request('area-'+admission+'-'+area['value'], admitted, {'ddlCulture':area['value']}, 'ddlCulture')
            details = Form(area_page).options('ddlDetail')
            for detail in details or [{'value':'','text':''}]:
                key = 'general-'+admission+'-'+area['value']+'-'+detail['value']
                rows = table_rows(search.search(key, area_page, {'ddlDetail':detail['value']}, year, semester))
                name = '교양·기타 / '+' / '.join(t.strip() for t in [area['text'],detail['text']] if t.strip())
                records.extend((row, name) for row in rows)
                groups.append({'kind':'general','admission':admission,'area':area['text'],'detail':detail['text'],'rows':len(rows)})
        print('general', admission, 'rows',len(records),'requests',search.requests,flush=True)
    return records, groups

def build(records, groups, year, semester, output, checked):
    courses = {}
    for cells, department in records:
        item = course(cells, department, year, semester)
        old = courses.get(item['sourceId'])
        if old is None:
            courses[item['sourceId']] = item
        else:
            for key in ('courseName','professor','sourceSchedule','sourceClassroom','schedules','credits'):
                if old[key] != item[key]:
                    raise ValueError('Conflicting duplicate '+item['sourceId']+' '+key)
            old['departments'] = sorted(set(old['departments']+item['departments']))
            for key in ('departmentCredits','departmentClassifications','departmentRemarks'):
                for department, value in item[key].items():
                    if department in old[key] and old[key][department] != value:
                        raise ValueError('Conflicting department metadata '+item['sourceId'])
                old[key].update(item[key])
    for campus in ('gwangju','yeosu'):
        subset = sorted((c for c in courses.values() if c['campus']==campus),key=lambda c:(c['courseCode'],c['section']))
        if not subset:
            raise ValueError('Empty campus')
        source_rows = sum(1 for cells, _ in records if cells[0] == {'gwangju':'광주','yeosu':'여수'}[campus])
        data={'schemaVersion':1,'universityId':'jnu','university':'jnu','campus':campus,'academicYear':year,'semester':semester,'publishedDate':checked,'sourceUrl':URL,'timeModuleSourceUrl':MODULE_SOURCE,'saturdayModuleSourceUrl':SATURDAY_MODULE_SOURCE,'retrievedAt':checked,'sourceRowCount':source_rows,'sourceQueryCount':len(groups),'counts':dict(Counter(c['scheduleStatus'] for c in subset)),'courses':subset}
        path=output/f'jnu-{campus}-{year}-{semester}.json'
        path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
        print(path,len(subset),data['counts'],flush=True)
    return {'groups':groups,'rowCount':len(records),'courseCount':len(courses),'statuses':dict(Counter(c['scheduleStatus'] for c in courses.values())),'unrecognized':[{k:c[k] for k in ('sourceId','courseName','sourceSchedule')} for c in courses.values() if c['scheduleStatus']=='unrecognized']}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch',action='store_true')
    parser.add_argument('--cache',type=Path,required=True)
    parser.add_argument('--output',type=Path,default=Path('assets/timetable'))
    parser.add_argument('--year',type=int,default=2026)
    parser.add_argument('--semester',default='2')
    parser.add_argument('--checked-at',default=date.today().isoformat())
    args=parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    search=PublicSearch(args.cache,args.fetch)
    raw=args.cache/'records.json'
    if raw.exists():
        saved=json.loads(raw.read_text())
        if saved.get('academicYear') != args.year or saved.get('semester') != args.semester:
            raise ValueError('Cached records belong to a different or unspecified year/semester; use a separate cache')
        records,groups=saved['records'],saved['groups']
    else:
        records,groups=collect(search,args.year,args.semester)
        raw.write_text(json.dumps({'academicYear':args.year,'semester':args.semester,'records':records,'groups':groups},ensure_ascii=False))
    report=build(records,groups,args.year,args.semester,args.output,args.checked_at)
    (args.cache/'report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':main()
