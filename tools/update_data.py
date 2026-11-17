"""data.json 자동 최신화 — 깃허브 액션이 매일 돌린다 (손으로: py -3 tools/update_data.py)

0) 음악방송 1위: 한국어 위키백과 「리센느」 문서의 가요 프로그램 1위 표를 읽어 새 1위만 보탠다.
1) 수상 내역: 영어 위키백과 'Rescene' 문서의 Accolades 표(CC BY-SA 4.0)를 읽어 시상식·해별로 묶는다.
   - 위키 문서가 이미 앱에 있는 상을 빠뜨려도 지우지 않는다(합친다). 결과(수상/후보/발표 전)는 위키 쪽을 따른다.
2) 정렬: 수상 내역·소식은 언제나 최신이 맨 위.
3) 무언가 바뀌었을 때만 updated 날짜를 오늘로 바꾼다 → 앱은 켤 때마다 이 파일을 받아 새 정보를 보여 준다.
표준 라이브러리만 쓴다.
"""
import json
import re
import sys
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'data.json'
WIKI = 'https://en.wikipedia.org/w/index.php?title=Rescene&action=raw'
UA = 'rescene-fanbook-data-updater/1.0 (unofficial fan app; github.com/doridori5252-wq/rescene-fanbook)'

KO_AWARD = {
    'Asia Artist Awards': 'Asia Artist Awards', 'Asia Model Awards': 'Asia Model Awards',
    'The Fact Music Awards': '더팩트 뮤직 어워즈', 'Hanteo Music Awards': '한터뮤직어워즈',
    'Korea First Brand Awards': '대한민국 퍼스트브랜드 대상', 'Korea Grand Music Awards': '코리아 그랜드 뮤직 어워즈',
    'K-World Dream Awards': 'K-World Dream Awards', 'MAMA Awards': 'MAMA Awards',
    'Melon Music Awards': '멜론뮤직어워드', 'SPOTV K-Pop Awards': 'SPOTV K-Pop Awards',
    'Golden Disc Awards': '골든디스크어워즈', 'Seoul Music Awards': '서울가요대상',
    'Circle Chart Music Awards': '써클차트 뮤직 어워즈', 'Korean Music Awards': '한국대중음악상',
    'Newsis K-Expo Cultural Awards': '뉴시스 K-엑스포 문화대상', 'Asia Star Entertainer Awards': '아시아 스타 엔터테이너 어워즈',
}
KO_WORD = [
    ('Grand Honor\'s Choice (Daesang)', '그랜드 아너스 초이스 (대상)'), ('(Daesang)', '(대상)'), ('(Bonsang)', '(본상)'),
    ('Artist of the Year', '올해의 아티스트'), ('Rookie of the Year', '신인상'), ('Popularity Award', '인기상'),
    ('Best Artist', '베스트 아티스트'), ('Best Memory', '베스트 메모리'), ('Global Fan Choice', '글로벌 팬 초이스'),
    ('Hot Trend', '핫 트렌드'), ('Today\'s Choice', '투데이스 초이스'), ('Rising Star Award', '라이징스타상'),
    ('Rising Female Idol', '라이징 여자 아이돌'), ('Hallyu Special Award', '한류특별상'),
    ('Idol Group', '아이돌 그룹'), ('Female', '여자'), ('Singer', '가수'),
]
RESULT = {'won': 'won', 'nom': 'nom', 'pending': 'pend', 'tba': 'pend', 'n/a': 'nom'}


def ko(text):
    for a, b in KO_WORD:
        text = text.replace(a, b)
    return text.replace(' – ', ' · ')


def clean(cell):
    cell = re.sub(r'<ref[^>]*/>|<ref[^>]*>.*?</ref>', '', cell, flags=re.S)
    cell = re.sub(r'^\s*(?:[a-z-]+="[^"]*"\s*)+\|', '', cell)            # style="..." | 내용
    cell = re.sub(r'\[\[(?:[^|\]]*\|)?([^\]]*)\]\]', r'\1', cell)          # [[링크|글자]]
    cell = re.sub(r"''+", '', cell)
    return re.sub(r'\s+', ' ', cell).strip()


def parse_awards(wikitext):
    m = re.search(r'===\s*Awards and nominations\s*===(.*?)\n\|\}', wikitext, re.S)
    if not m:
        raise SystemExit('위키 문서에서 수상 표를 찾지 못했어요 — 문서 구조가 바뀌었는지 확인')
    rows, ceremony, year = [], None, None
    for raw in m.group(1).split('\n|-')[1:]:
        lines = [l for l in raw.strip().split('\n') if l.strip()]
        cells = []
        for l in lines:
            if l.startswith('!'):
                ceremony = clean(l[1:])
            elif l.startswith('|'):
                cells.append(l[1:])
        res = next((RESULT[t.lower()] for c in cells for t in re.findall(r'\{\{\s*(won|nom|pending|tba|n/a)\s*[|}]', c, re.I)), None)
        if res is None:
            continue
        cat = None
        for c in cells:
            if '<ref' in c or re.search(r'\{\{\s*(won|nom|pending|tba|n/a)', c, re.I):
                continue
            v = clean(c)
            if re.fullmatch(r'\d{4}', v):
                year = v
            elif 'text-align:left' in c and v:
                cat = v
        if ceremony and year and cat:
            rows.append((year, ceremony, cat, res))
    if len(rows) < 5:
        raise SystemExit(f'수상 줄이 {len(rows)}개뿐이에요 — 표 읽기가 잘못됐을 수 있어 멈춥니다')
    return rows


def group(rows):
    out = {}
    for year, cer, cat, res in rows:
        key = (year, KO_AWARD.get(cer, cer))
        g = out.setdefault(key, {'cats': [], 'res': set()})
        g['cats'].append(ko(cat)); g['res'].add(res)
    awards = []
    for (year, name), g in out.items():
        r = 'won' if 'won' in g['res'] else 'pend' if 'pend' in g['res'] else 'nom'
        awards.append([year, name, ', '.join(g['cats']), r])
    return awards


KOWIKI = 'https://ko.wikipedia.org/w/index.php?title=%EB%A6%AC%EC%84%BC%EB%8A%90&action=raw'
SHOW = {'더 쇼': '더쇼', '쇼! 음악중심': '음악중심', 'SBS 인기가요': '인기가요', '쇼 챔피언': '쇼챔피언',
        '엠카운트다운': '엠카운트다운', 'M! 카운트다운': '엠카운트다운', '뮤직뱅크': '뮤직뱅크', '쇼! 챔피언': '쇼챔피언'}


def parse_wins(wikitext):
    """한국어 위키백과 '가요 프로그램 1위' 표 → [{song,date,show,tag}]"""
    m = re.search(r'===\s*가요 프로그램 1위\s*===(.*?)\n\|\}', wikitext, re.S)
    if not m:
        return []
    out, year, song = [], None, None
    for line in m.group(1).split('\n'):
        y = re.match(r'!\s*(\d{4})년', line)
        if y:
            year = y.group(1); continue
        s = re.match(r"\*\s*'''(.+?)'''", line)
        if s:
            song = s.group(1).strip(); continue
        w = re.match(r'\*\*\s*\[\[(\d+)월 (\d+)일\]\].*?《\[\[(?:[^|\]]*\|)?([^\]]+)\]\]》\s*(.*)', line)
        if w and year and song:
            mo, da, show, rest = w.groups()
            note = re.search(r'\(([^)]*)\)', rest)
            tag = note.group(1) if note else ('챔피언 송' if '챔피언' in rest else '1위')
            out.append({'song': song, 'date': f'{year}.{int(mo):02d}.{int(da):02d}', 'show': SHOW.get(show, show), 'tag': tag})
    return out


def merge_wins(old, new):
    by = {(w['date'], w['show']): w for w in old}
    for w in new:
        by.setdefault((w['date'], w['show']), w)   # 이미 있는 건 앱에서 붙인 꼬리표(첫 1위·역주행)를 지킨다
    return sorted(by.values(), key=lambda w: w['date'], reverse=True)


ORDER = {'pend': 0, 'won': 1, 'nom': 2}


def merge(old, new):
    by = {(a[0], a[1]): a for a in old}
    for a in new:
        by[(a[0], a[1])] = a            # 위키 쪽이 최신
    return sorted(by.values(), key=lambda a: (-int(a[0]), ORDER.get(a[3], 3), a[1]))


def main():
    data = json.loads(DATA.read_text(encoding='utf-8'))
    before = json.dumps(data, ensure_ascii=False, sort_keys=True)
    req = urllib.request.Request(WIKI, headers={'User-Agent': UA})
    wikitext = urllib.request.urlopen(req, timeout=30).read().decode('utf-8')
    data['awards'] = merge(data.get('awards', []), group(parse_awards(wikitext)))
    data['awardsSource'] = '위키백과 영어판 「Rescene」 문서 (CC BY-SA 4.0)'
    data['news'] = sorted(data.get('news', []), key=lambda x: x['date'], reverse=True)
    try:
        req = urllib.request.Request(KOWIKI, headers={'User-Agent': UA})
        kotext = urllib.request.urlopen(req, timeout=30).read().decode('utf-8')
        data['wins'] = merge_wins(data.get('wins', []), parse_wins(kotext))
    except Exception as e:                       # 한국어 문서를 못 읽어도 수상 내역 갱신은 계속
        print('음악방송 1위 갱신 건너뜀:', e)
    data['wins'] = sorted(data.get('wins', []), key=lambda x: x['date'], reverse=True)
    after = json.dumps(data, ensure_ascii=False, sort_keys=True)
    if after != before:
        data['updated'] = datetime.now(timezone(timedelta(hours=9))).strftime('%Y-%m-%d')
        DATA.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print('바뀜:', len(data['awards']), '개 시상식')
    else:
        print('바뀐 것 없음')


if __name__ == '__main__':
    sys.exit(main())
