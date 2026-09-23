#!/usr/bin/env python3
"""给每个大事件生成「逐期导读」元数据，写回 marvel_events.json。

为什么需要：官方阅读指南只覆盖一部分事件（同名/年份对不上就没有），
剩下的事件原来只有「某系列 #1-12」这种粗粒度条目，点进去还是搜索。
这个脚本把 coreOrder / optionalOrder 展开成**一本一本的书**，带上发行
日期，按发行时间排序后写进事件的 `readingOrder` 字段。应用里没有官方
指南就走这份数据，每期都能点进详情。

数据来源：Marvel Database（marvel.fandom.com）。
官网目录没有「按标题搜系列」的接口（lockjaw 联想只返回 5 条变体封面、
bifrost 的 /catalog/series 只认 byId），所以逐期数据从 wiki 取：
  1. `list=allpages&apprefix=<卷名> ` 枚举某一卷的全部期页面；
  2. 批量取这些页面的 wikitext，解出 ReleaseDate；
  3. 期号 → 页面名形如 "Ultimate Invasion Vol 1 1"。
卷号用「哪一卷的第 1 期年份最接近事件年份」判断（Ultimate Spider-Man
Vol 3 和 Vol 1 差了二十年，这个方法够用）。

期条目带 `id: "fandom:<页面名>"`，应用侧走既有 wiki 兜底链路打开详情。

用法：
    python tool/build_reading_orders.py            # 生成/补齐（跳过已有的）
    python tool/build_reading_orders.py --rebuild  # 全部重算
    python tool/build_reading_orders.py --only secret-wars-1984
"""

import json
import re
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EVENTS_FILE = ROOT / 'assets' / 'data' / 'marvel_events.json'

WIKI = 'https://marvel.fandom.com/api.php'
UA = ('Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36')

MONTHS = {m: i + 1 for i, m in enumerate(
    ['January', 'February', 'March', 'April', 'May', 'June', 'July',
     'August', 'September', 'October', 'November', 'December'])}


def http_json(params, tries=2):
    last = None
    url = WIKI + '?' + urllib.parse.urlencode(params)
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={
                'User-Agent': UA, 'Accept': 'application/json'})
            with urllib.request.urlopen(req, timeout=20) as r:
                return json.loads(r.read().decode('utf-8', 'replace'))
        except Exception as e:
            last = e
            time.sleep(0.5 * (i + 1))
    raise last


def year_hint(series, fallback):
    m = re.search(r'[（(]\s*(\d{4})', series)
    return int(m.group(1)) if m else fallback


def parse_date(raw):
    """'[[October 25, 2023]]' → '2023-10-25'；解不出返回空串。"""
    m = re.search(r'([A-Z][a-z]+)\s+(\d{1,2}),\s*(\d{4})', raw or '')
    if m:
        mon = MONTHS.get(m.group(1), 0)
        if mon:
            return f'{m.group(3)}-{mon:02d}-{int(m.group(2)):02d}'
    m2 = re.search(r'(\d{4})-(\d{2})-(\d{2})', raw or '')
    return m2.group(0) if m2 else ''


# ── 卷 → 期页面 ────────────────────────────────────────────────

_vol_cache = {}


def volume_pages(volume):
    """枚举 'X Vol n' 下的全部期页面，返回 {期号: 页面名}。"""
    if volume in _vol_cache:
        return _vol_cache[volume]
    out = {}
    cont = None
    for _ in range(1):
        params = {'action': 'query', 'list': 'allpages',
                  'apprefix': volume + ' ', 'aplimit': 200,
                  'apnamespace': 0, 'format': 'json'}
        if cont:
            params['apcontinue'] = cont
        try:
            d = http_json(params)
        except Exception:
            break
        for p in d.get('query', {}).get('allpages', []):
            t = p['title']
            m = re.match(rf'^{re.escape(volume)}\s+(\d+)(\.[A-Za-z]+)?$', t)
            if m:
                key = m.group(0).split()[-1]
                out.setdefault(key, t)
        cont = d.get('continue', {}).get('apcontinue')
        if not cont:
            break
    _vol_cache[volume] = out
    return out


_issue_cache = {}


def issue_info(pages):
    """批量取期页面 wikitext，解出 (发行日期, 故事标题, 封面文件)。"""
    todo = [p for p in pages if p not in _issue_cache]
    for i in range(0, len(todo), 25):
        chunk = todo[i:i + 25]
        try:
            d = http_json({'action': 'query', 'titles': '|'.join(chunk),
                           'prop': 'revisions|pageimages',
                           'rvslots': 'main', 'rvprop': 'content',
                           'piprop': 'name', 'formatversion': 2,
                           'format': 'json'})
        except Exception:
            continue
        for pg in d.get('query', {}).get('pages', []):
            title = pg.get('title')
            if not title:
                continue
            try:
                content = pg['revisions'][0]['slots']['main']['content']
            except Exception:
                content = ''
            date = parse_date(
                (re.search(r'\|\s*ReleaseDate\s*=\s*([^\n|}]*)', content)
                 or [None, ''])[1])
            story = ((re.search(r'\|\s*StoryTitle1\s*=\s*([^\n|}]*)', content)
                      or [None, ''])[1] or '').strip()
            _issue_cache[title] = (date, story, pg.get('pageimage'))
    return {p: _issue_cache.get(p) for p in pages}


def resolve_volume(series, fallback_year):
    """把我们的系列名换成 wiki 卷名：试 Vol 1..4，取第 1 期年份最近的一卷。

    四个候选的第 1 期**一次请求全拿到**（wiki 对端很慢，一次请求 20 秒起，
    分开探要四倍时间）。
    """
    base = re.sub(r'[（(].*$', '', series).strip()
    base = re.sub(r'\s*Vol\.?\s*\d+\s*$', '', base, flags=re.I).strip()
    # wiki 的卷名基本不带「The 」（The Thanos Quest → Thanos Quest Vol 1）
    base_no_the = re.sub(r'^the\s+', '', base, flags=re.I).strip()
    if not base:
        return None
    want_year = year_hint(series, fallback_year)
    names = [base] + ([base_no_the] if base_no_the != base else [])
    volumes = [f'{n} Vol {v}' for n in names for v in range(1, 5)]
    probes = {}
    for v in volumes:
        first = volume_pages(v).get('1')
        if first:
            probes[first] = v
    if not probes:
        return None
    info = issue_info(list(probes.keys()))
    best, best_gap = None, 999
    for page, v in probes.items():
        date = (info.get(page) or ('',))[0]
        if not date:
            continue
        gap = abs(int(date[:4]) - want_year)
        if gap <= 2:
            return v
        if gap < best_gap:
            best, best_gap = v, gap
    # 差得太远说明这个系列名在 wiki 上不叫这个，宁可不给也别塞错卷
    return best if best_gap <= 6 else None


def parse_numbers(spec, available):
    spec = (spec or '').replace('各', '').strip()
    if not spec:
        return list(available)
    want = set()
    for part in re.split(r'[,，、]', spec):
        part = part.strip()
        m = re.match(r'^(\d+)\s*[-–~]\s*(\d+)$', part)
        if m:
            want.update(str(n) for n in range(int(m.group(1)),
                                              int(m.group(2)) + 1))
        elif re.match(r'^\d+$', part):
            want.add(part)
    return [n for n in available if n in want]


def main():
    rebuild = '--rebuild' in sys.argv
    only = None
    if '--only' in sys.argv:
        # 支持逗号分隔的一串 id
        only = set(sys.argv[sys.argv.index('--only') + 1].split(','))

    doc = json.loads(EVENTS_FILE.read_text(encoding='utf-8'))
    events = doc['events']
    todo = [e for e in events
            if (only is None or e['id'] in only)
            and (rebuild or not e.get('readingOrder'))]
    print(f'事件 {len(events)} 条，本次处理 {len(todo)} 条')

    def expand_one(event, item, is_core):
        series = (item.get('series') or '').strip()
        if not series:
            return []
        # 「A / B / C」拆开；括号里补充的期号也当独立系列处理
        parts = [p.strip() for p in re.split(r'\s*/\s*', series) if p.strip()]
        extra = re.findall(r'[（(]([^)）]*\d+\s*[-–]\s*\d+[^)）]*)[)）]', series)
        out = []
        for part in parts + extra:
            part = re.sub(r'[（(].*$', '', part).strip()
            if not part:
                continue
            # 没写期号的系列不展开：那会把整卷上百期全拉进来（Ultimatum
            # 那种 206 期就是这么来的），那是噪音不是导读。这类留在
            # 「可选延伸」里按系列给个大方向就好。
            if not (item.get('issues') or '').strip():
                continue
            print(f'      · {part}', flush=True)
            volume = resolve_volume(part, event['year'])
            if not volume:
                out.append({'error': part})
                print(f'        ✗ {part}', flush=True)
                continue
            print(f'        → {volume}', flush=True)
            pages = volume_pages(volume)
            numbers = parse_numbers(item.get('issues'), list(pages.keys()))
            if not numbers and item.get('issues'):
                numbers = list(pages.keys())
            picked = {n: pages[n] for n in numbers if n in pages}
            if not picked:
                out.append({'error': f'{part}（{volume} 期号对不上）'})
                continue
            info = issue_info(list(picked.values()))
            for num, page in picked.items():
                date, story, image = info.get(page) or ('', '', None)
                out.append({
                    'id': f'fandom:{page}',
                    'series': re.sub(r'\s*Vol\.?\s*\d+\s*$', '', volume).strip(),
                    'number': num,
                    'date': date,
                    'title': story,
                    'cover': image,
                    'core': is_core,
                    'note': item.get('note'),
                })
        return out

    def build(event):
        print(f'  … {event["id"]}', flush=True)
        items, errors = [], []
        for group, is_core in ((event.get('coreOrder') or [], True),
                               (event.get('optionalOrder') or [], False)):
            for it in group:
                for got in expand_one(event, it, is_core):
                    if 'error' in got:
                        errors.append(got['error'])
                    else:
                        items.append(got)
        items.sort(key=lambda i: (i['date'] or '9999', i['series'], i['number']))
        return event, items, errors

    workers = 3
    with ThreadPoolExecutor(max_workers=workers) as pool:
        for event, items, errors in pool.map(build, todo):
            event['readingOrder'] = items
            flag = f'  ⚠ 未解析 {len(errors)}' if errors else ''
            print(f'  ✓ {event["id"]:<34} {len(items):>4} 期{flag}', flush=True)
            if errors:
                print('      ', '; '.join(errors[:3]))
            # 落盘一次：这批可能跑很久，中途挂掉不该把已算好的丢了
            EVENTS_FILE.write_text(
                json.dumps(doc, ensure_ascii=False, indent=2) + chr(10),
                encoding='utf-8')

    EVENTS_FILE.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + '\n',
                           encoding='utf-8')
    filled = [e for e in events if e.get('readingOrder')]
    counts = [len(e['readingOrder']) for e in filled]
    print(f'\n完成：{len(filled)}/{len(events)} 条带逐期导读，共 {sum(counts)} 期，'
          f'中位 {sorted(counts)[len(counts) // 2] if counts else 0} 期')
    empty = [e['id'] for e in events if not e.get('readingOrder')]
    if empty:
        print('仍是空的：', empty[:10])


if __name__ == '__main__':
    main()
