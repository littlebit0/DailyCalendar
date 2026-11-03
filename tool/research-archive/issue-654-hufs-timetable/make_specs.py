# -*- coding: utf-8 -*-
"""Build DailyCalendar-Class spec files for HUFS (issue 654) from saved official pages."""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REL = 'work/issue-654-hufs-timetable/src/'


def url(page):
    return f'https://www.hufs.ac.kr/hufs/{page}/subview.do'


def quote(page, needle):
    text = (HERE / 'src' / f'p{page}.txt').read_text(encoding='utf-8')
    if needle not in text:
        raise SystemExit(f'quote not found in p{page}: {needle}')
    return needle


def ev(page, needle, note=''):
    q = quote(page, needle)
    return f"한국외국어대학교 공식 페이지(2026-10-23 확인) 원문: \"{q}\"{(' ' + note) if note else ''}"


assign = []


def a(label, college, page, needle, note=''):
    assign.append({'label': label, 'college': college, 'url': url(page),
                   'file': REL + f'p{page}.html', 'evidence': ev(page, needle, note)})


TT = '학과소개 영어통번역학부(~2022) 독일어통번역학과(~2023) 스페인어통번역학과(~2023) 이탈리아어통번역학과(~2023) 중국어통번역학과(~2022) 일본어통번역학과(~2022) 아랍어통번역학과(~2020) 말레이·인도네시아어통번역학과(~2023) 태국어통번역학과(~2022)'
for label in ['영어통번역학부', '독일어통번역학과', '스페인어통번역학과', '이탈리아어통번역학과',
              '중국어통번역학과', '일본어통번역학과', '말레이.인도네시아어통번역학과', '태국어통번역학과']:
    a(label, '통번역대학', 11241, TT)
a('영미권통상통번역전공', '통번역대학', 11241,
  '영어통번역학부는 영미권통상통번역전공, 영미문학문화통번역전공, 영어학전공, 영어통번역심화전공의 4개 전공으로 나뉘어 있다.')
GI = '학과소개 프랑스학과(~2022) 브라질학과(~2022) 인도학과(~2022) 러시아학과(~2022)'
for label in ['프랑스학과', '브라질학과', '인도학과', '러시아학과']:
    a(label, '국제지역대학', 11243, GI)
a('그리스‧불가리아학과', '국가전략언어대학', 11242,
  '학과소개 폴란드학과 루마니아학과 체코·슬로바키아학과 헝가리학과 세르비아·크로아티아학과 그리스·불가리아학과')
a('융합인재학부', '융합인재대학', 11247, '융합인재대학 홈페이지 바로가기 융합인재학부')
a('정보통신공학과', '공과대학', 11246, '학과소개 컴퓨터공학부 정보통신공학과')
SS = '학과소개 정치외교학과 행정학과 미디어커뮤니케이션학부'
for label in ['정치외교학과', '행정학과']:
    a(label, '사회과학대학', 11229, SS, '(대학 위치 서울캠퍼스, 강좌는 글로벌캠퍼스 개설)')
HU = '학과소개 철학과 사학과 언어인지과학과'
for label in ['철학과', '사학과']:
    a(label, '인문대학', 11238, HU, '(대학 위치 글로벌캠퍼스, 강좌는 서울캠퍼스 개설)')
a('영어통번역학과', '영어대학', 11224,
  "영어통번역(EICC)학과는 한국외대를 이끌어온 선도학과인 ‘영어통번역학과’의 후신(後身)으로서",
  '/ ' + quote(11224, '학과소개 ELLT학과 영미문학·문화학과 영어통번역(EICC)학과'))
a('차이나데이터큐레이션전공', '중국학대학', 11227,
  '중국언어문화학부는 차이나링귀스틱 트랙, 차이나 컬처 트랙, 차이나데이터큐레이션 전공으로')
FR = '‘프랑스응용어문학전공’, ‘FATI(프랑스어통번역)전공’, 그리고 ‘프랑스·EU 전공’으로 세분화된 전공체계'
for label in ['프랑스응용어문학전공', '프랑스·EU전공']:
    a(label, '서양어대학', 11225, FR, '/ ' + quote(11225, '학과소개 프랑스어학부 독일어과'))

add = []


def m(label, campus, college=None, group=None, page=None, needle=None, note='', standalone=False,
      file=None, link=None, evidence=None):
    add.append({'label': label, 'campus': campus, 'college': college, 'group': group,
                'url': link or url(page), 'file': file or (REL + f'p{page}.html'),
                'evidence': evidence or ev(page, needle, note), 'standaloneCollege': standalone})


m('반도체전자공학부(반도체공학전공)', 'global', '공과대학', page=11246,
  needle='반도체전자공학부(반도체공학전공) [신설]')
m('반도체전자공학부(전자공학전공)', 'global', '공과대학', page=11246,
  needle='반도체전자공학부(전자공학전공) [개편]')
m('공과대학(공통)', 'global', '공과대학', page=11246, needle='공과대학 대학소개', standalone=True,
  note='/ 공식 시간표 라벨 자체가 "공과대학(공통)"(공과대학 직접 개설)')
m('말레이.인도네시아어과', 'seoul', '아시아언어문화대학', page=11226,
  needle='학과소개 말레이·인도네시아어과 아랍어과 태국학과')
MOD = '- 모듈1(통번역: 영어, 아랍어, 중국어) - 모듈2(국제전략: 미주·영연방, 중동·이슬람, 중화권, 이탈리아·EU) - 모듈3(문화산업콘텐츠: 테크노미디어디자인, 패션관광문화산업, 게임한류문화산업) - 모듈4(융합비즈니스) - 모듈5(ICT & AI)'
for label in ['영어통번역세부모듈', '아랍어통번역세부모듈', '중국어통번역세부모듈',
              '미국․영연방전략세부모듈', '중동․이슬람전략세부모듈', '중화권전략세부모듈',
              '이탈리아․EU전략세부모듈', '테크노미디어디자인세부모듈', '패션관광문화산업세부모듈',
              '게임한류문화산업세부모듈', '융합비즈니스세부모듈', 'ICT&AI세부모듈']:
    m(label, 'global', '융합인재대학', page=11247, needle=MOD,
      note='/ ' + quote(11247, '융합인재학부에는 모듈도 있고 세부모듈도 있던데'))
m('AI융합전공(Software&AI)', 'global', group='일반융합전공', page=11254,
  needle='일반융합전공 일반융합전공 --> BRICs(브릭스)전공 EU(유럽연합)전공 동북아외교통상전공 문화콘텐츠학전공 국가리더전공 세계문화예술경영전공 디지털인문한국학전공 AI융합전공',
  note='/ 2026-1 수강편람(서울): "⑧ AI융합전공(공통과정, Software&AI트랙, Language&AI트랙, Business&AI트랙)"')
MINERVA = '미네르바대학은 한국외국어대학교 학부생들의 교양교육, 기초교육을 주관하고'
m('교양 · 전체', 'global', '미네르바대학', page=15542, needle=MINERVA, standalone=True,
  note='/ ' + quote(15542, '미네르바대학은 양 캠퍼스 통합 단과대학으로 운영되고 있으며'))
m('교양 · 전체', 'seoul', '미네르바대학', page=15542, needle=MINERVA, standalone=True,
  note='/ ' + quote(15542, '미네르바대학은 양 캠퍼스 통합 단과대학으로 운영되고 있으며'))
m('교양 · 마이크로디그리(영어)', 'global', '미네르바대학', page=15542, needle=MINERVA, standalone=True,
  note='/ 산하 "' + quote(15542, '산하에 교양교육연구센터, 기초교육센터, 외국어교육센터, 인성교육센터') +
  '" / 마이크로디그리 승인 현황(https://www.hufs.ac.kr/hufs/13511/subview.do): 공학영어·자연과학영어·사회과학영어·비지니스영어 주관운영 "외국어교육센터"')

official = json.loads((HERE / 'micro-official.json').read_text(encoding='utf-8'))
alias = {'비즈니스영어': '비지니스영어'}
for row in (HERE / 'micro-raw.txt').read_text(encoding='utf-8').split(', '):
    campus, label = row.strip().split(' ', 1)
    name = label.split(' · ', 1)[1]
    key = re.sub(r'\s', '', alias.get(name, name))
    n, c, oname, credits, org = official[key]
    note = f' (공식 표기 "{oname}")' if alias.get(name) else ''
    m(label, campus, group='마이크로디그리', page=13511,
      evidence=ev(13511, '마이크로디그리 승인 현황') +
      f' 표 {n}행: 주관캠퍼스 "{c}", 명칭 "{oname}", 최소이수학점 {credits}학점, 주관운영 "{org}"{note}')

(HERE / 'assign-spec.json').write_text(json.dumps(assign, ensure_ascii=False, indent=1), encoding='utf-8')
(HERE / 'add-spec.json').write_text(json.dumps(add, ensure_ascii=False, indent=1), encoding='utf-8')
print('assign', len(assign), 'add', len(add))
