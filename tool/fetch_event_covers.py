#!/usr/bin/env python3
"""把大事件封面图下载并封进应用本体（一次性脚本，自己跑）。

为什么存在：事件页的封面图走网络加载，第一次打开慢且依赖 CDN。
这个脚本把事件封面下载到 `assets/data/event_covers/<事件id>.jpg`，
并写一个 manifest。应用启动时读 manifest，有本地图就优先用本地的
——离线也能看。

封面从哪来（按优先级）：
1. 官方阅读指南列表里**年份对得上**的同名指南封面。同名事件很多
   （1984/2015 都叫 Secret Wars），所以候选按标题评分排好后要逐个拉
   期数、用发行年份验明正身——跟应用运行时同一套规则，错了宁可不给。
2. wiki（marvel.fandom.com）事件页的配图：`prop=pageimages`，按
   "<标题> (Event)" → 搜索结果里像事件页的条目 的顺序找。

用法：

    python tool/fetch_event_covers.py           # 下载 + 写 manifest
    python tool/fetch_event_covers.py --clean   # 删掉已下载的封面

跑完重启应用即生效。只依赖标准库。
"""

import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EVENTS_FILE = ROOT / 'assets' / 'data' / 'marvel_events.json'
COVER_DIR = ROOT / 'assets' / 'data' / 'event_covers'
MANIFEST = COVER_DIR / 'manifest.json'

BIFROST = 'https://bifrost.marvel.com'
WIKI = 'https://marvel.fandom.com/api.php'

UA = (
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36'
)


def http_get(url, timeout=60, tries=3):
    """带重试的 GET：图片 CDN 会随机掐断连接（WinError 10054）与 502。"""
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={
                'User-Agent': UA,
                'Referer': 'https://www.marvel.com/',
                'Accept': 'application/json,image/*,*/*',
                'Accept-Encoding': 'identity',
            })
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except Exception as e:
            last = e
            time.sleep(0.8 * (i + 1))
    raise last


def get_json(url):
    return json.loads(http_get(url))


def wiki_api(params):
    return get_json(WIKI + '?' + urllib.parse.urlencode(params))


# ── 官方指南匹配（与应用 EventDetailPage._candidates/_yearFits 同规则）──

def normalize(s):
    s = s.lower().replace('\u2019', "'")
    s = re.sub(r"[^a-z0-9:()\-, ]", ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def candidates(guides, event):
    key = normalize(event['title'])
    if not key:
        return []
    out = []
    for g in guides:
        t = normalize(g['title'])
        at = t.find(key)
        if at < 0:
            continue
        before = ' ' if at == 0 else t[at - 1]
        after = ' ' if at + len(key) >= len(t) else t[at + len(key)]
        if before not in ' :-(' or after not in ' :-(':
            continue
        tail = t[at + len(key):].strip()
        if re.match(r'^(ii|iii|iv|v|vi|vii|2|3|4)\b', tail):
            continue
        score = 0
        if 'complete event' in t:
            score += 6
        if 'main event' in t:
            score += 5
        if re.search(r'\b%d\b' % event['year'], t):
            score += 4
        if tail == '':
            score += 3
        if t.startswith(key):
            score += 2
        if tail.startswith('road to') or tail.startswith('the road to'):
            score -= 2
        out.append((score, g))
    out.sort(key=lambda x: -x[0])
    return [g for _, g in out[:3]]


def year_fits(issues, event_year):
    years = []
    for c in issues:
        m = re.match(r'^(\d{4})', str(c.get('release_date') or ''))
        if m:
            years.append(int(m.group(1)))
    if not years:
        return True
    return event_year >= min(years) - 2 and event_year <= max(years) + 2


def guide_cover(guides, event, cache):
    """按标题评分 + 年份校验取官方指南封面。"""
    for g in candidates(guides, event):
        gid = g['id']
        if gid not in cache:
            try:
                data = get_json(
                    f'{BIFROST}/v1/catalog/reading-lists/{gid}'
                    '?limit=1000&offset=0')
                cache[gid] = data['data']['results'][0].get('contents') or []
            except Exception:
                cache[gid] = []
        if not year_fits(cache[gid], event['year']):
            print(f'    年份不符，跳过指南 {g["title"]!r}')
            continue
        images = g.get('images') or []
        if not images:
            continue
        img = images[0]
        return f"{img['path']}.{img['extension']}", f'官方指南 {g["title"]!r}'
    return None, None


# ── wiki 兜底 ───────────────────────────────────────────────────

def wiki_cover(event):
    """wiki 事件页配图：先直接试几个可能的页面名，再走搜索。"""
    title = event['title'].split('/')[0].strip()
    tries = [
        f'{title} ({event["year"]} Event)',
        f'{title} (Event)',
        f'{title} (event)',
        title,
    ]
    # 搜索补几个候选（wiki 对事件页常带 (Event) 后缀）
    try:
        s = wiki_api({'action': 'query', 'list': 'search', 'srsearch': title,
                      'srlimit': 5, 'format': 'json'})
        for h in s['query']['search']:
            t = h['title']
            if t not in tries and ('Event' in t or t == title):
                tries.append(t)
    except Exception:
        pass

    for page in tries:
        try:
            # 640 而不是更大：wikia 的 /scale-to-width-down/N 在 N 超过原图宽度时
            # 会 404，640 基本都能命中
            r = wiki_api({'action': 'query', 'titles': page,
                          'prop': 'pageimages', 'pithumbsize': 640,
                          'redirects': 1, 'format': 'json'})
            for v in r['query']['pages'].values():
                src = (v.get('thumbnail') or {}).get('source')
                if src:
                    return src, f'wiki {v.get("title")!r}'
        except Exception:
            continue
    return None, None


def wiki_original(url):
    """去掉 /scale-to-width-down/N：wikia 请求的尺寸超过原图宽度会 404。"""
    stripped = re.sub(r'/scale-to-width-down/\d+', '', url)
    return stripped if stripped != url else None


def ext_of(url):
    path = urllib.parse.urlparse(url).path.lower()
    for e in ('.jpg', '.jpeg', '.png', '.webp'):
        if path.endswith(e):
            return 'jpg' if e == '.jpeg' else e.lstrip('.')
    return 'jpg'


def normalize(files):
    """统一压成「最长边 900、JPEG q82」。

    不压的话 34 张原图合计 16MB+，直接把 APK 撑大；而卡片上显示区域
    也就 400×175 逻辑像素（3x 屏约 1200×525），900 宽足够清楚。
    需要 Pillow；没装就跳过压缩（图仍可用，只是包大）。
    """
    try:
        from PIL import Image
    except ImportError:
        print('（没装 Pillow，跳过压缩）')
        return
    saved = 0
    for f in files:
        try:
            im = Image.open(f)
            if im.mode not in ('RGB', 'L'):
                im = im.convert('RGB')
            if im.width > 900:
                im = im.resize(
                    (900, round(im.height * 900 / im.width)), Image.LANCZOS)
            target = f.with_suffix('.jpg')
            before = f.stat().st_size
            im.save(target, 'JPEG', quality=82, optimize=True)
            if target != f and f.exists():
                f.unlink()
            saved += max(0, before - target.stat().st_size)
        except Exception as e:
            print(f'  （{f.name} 压缩失败，保留原图：{e}）')
    if saved:
        print(f'压缩省下 {saved // 1024 // 1024}MB')


def main():
    if '--clean' in sys.argv:
        if COVER_DIR.exists():
            for f in COVER_DIR.glob('*'):
                if f.is_file():
                    f.unlink()
            print('已清空 event_covers')
        return

    events = json.loads(EVENTS_FILE.read_text(encoding='utf-8'))['events']
    print(f'事件总数: {len(events)}，拉官方指南列表…')
    guides = get_json(
        f'{BIFROST}/v1/catalog/reading-lists/platform/web')['data']['results']

    COVER_DIR.mkdir(parents=True, exist_ok=True)
    manifest = {}
    ok, miss, issue_cache = 0, 0, {}
    for ev in events:
        eid = ev['id']
        existing = next((p for p in COVER_DIR.glob(f'{eid}.*')), None)
        if existing is not None:
            manifest[eid] = existing.name
            ok += 1
            continue

        cover, why = (ev.get('imageUrl'), '数据集') if ev.get('imageUrl') \
            else guide_cover(guides, ev, issue_cache)
        if not cover:
            cover, why = wiki_cover(ev)
        # 官方指南的图挂了就退回 wiki，反之亦然
        alt = wiki_cover(ev) if cover else (None, None)
        if alt[0] == cover:
            alt = (None, None)
        # 缩略图下载失败时，试一次「去掉缩放、拿原图」
        orig = wiki_original(cover or '') or wiki_original(alt[0] or '')
        alts = [a for a in (alt, (orig, 'wiki 原图') if orig else (None, None))
                if a[0]]
        if not cover:
            print(f'  ✗ {ev["title"]}: 没找到封面')
            miss += 1
            continue

        name = f'{eid}.{ext_of(cover)}'
        data = None
        for url, source in ((cover, why), *alts):
            if not url:
                continue
            try:
                data = http_get(url)
                why, cover = source, url
                break
            except Exception as e:
                print(f'    {source} 下载失败：{str(e)[:70]}')
        if data is None:
            print(f'  ✗ {ev["title"]}: 所有来源都失败')
            miss += 1
            continue
        try:
            (COVER_DIR / name).write_bytes(data)
            manifest[eid] = name
            ok += 1
            print(f'  ✓ {ev["title"]} <- {why} ({len(data) // 1024}KB)')
        except Exception as e:
            print(f'  ✗ {ev["title"]}: 写文件失败 {e}')
            miss += 1

    normalize([f for f in COVER_DIR.glob('*') if f.is_file()
               and f.name != 'manifest.json'])
    # 压缩可能改了扩展名，manifest 以磁盘上的实际情况为准重建
    manifest = {}
    for ev in events:
        f = next((p for p in COVER_DIR.glob(f'{ev["id"]}.*')), None)
        if f is not None:
            manifest[ev['id']] = f.name

    MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    total = sum(f.stat().st_size for f in COVER_DIR.glob('*')
                if f.is_file() and f.name != 'manifest.json')
    print(f'\n完成：{len(manifest)} 张封面入库，{miss} 个没找到，'
          f'合计 {total / 1024 / 1024:.1f}MB。')
    print(f'manifest: {MANIFEST}')
    if miss:
        print('没找到的会继续走运行时的网络加载/渐变兜底，不影响使用。')


if __name__ == '__main__':
    main()