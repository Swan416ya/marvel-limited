#!/usr/bin/env python3
"""把大事件封面图下载并封进应用本体（一次性脚本，自己跑）。

为什么存在：事件页的封面图走网络加载，第一次打开慢且依赖 CDN。
这个脚本把 34 个事件的封面从官网 CDN 下载到
`assets/data/event_covers/<事件id>.jpg`，并写一个 manifest。
应用启动时读 manifest，有本地图就优先用本地的——离线也能看。

封面从哪来：官网官方阅读指南列表里同名事件的指南封面
（比如 "Civil War: The Main Event" 的封面就是内战的主视觉），
匹配规则和应用运行时一致。

用法：

    python tool/fetch_event_covers.py           # 下载 + 写 manifest
    python tool/fetch_event_covers.py --clean   # 删掉已下载的封面

跑完重启应用即生效。只依赖标准库。
"""

import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EVENTS_FILE = ROOT / 'assets' / 'data' / 'marvel_events.json'
COVER_DIR = ROOT / 'assets' / 'data' / 'event_covers'
MANIFEST = COVER_DIR / 'manifest.json'

UA = (
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36'
)


def get_json(url):
    req = urllib.request.Request(url, headers={
        'User-Agent': UA,
        'Referer': 'https://www.marvel.com/',
        'Accept': 'application/json',
        'Accept-Encoding': 'identity',
    })
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read())


def download(url, dest: Path):
    req = urllib.request.Request(url, headers={
        'User-Agent': UA,
        'Referer': 'https://www.marvel.com/',
    })
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
    dest.write_bytes(data)
    return len(data)


def match_guide_cover(guides, event):
    """和应用运行时同一套匹配规则：标题包含 + 偏好 complete/main event。"""
    key = event['title'].lower()
    best, best_score = None, -1
    for g in guides:
        t = g['title'].lower()
        if key not in t:
            continue
        score = 0
        if 'complete event' in t:
            score += 4
        if 'main event' in t:
            score += 3
        if str(event.get('year', '')) in t:
            score += 2
        if len(t) <= len(key) + 4:
            score += 1
        if score > best_score:
            best_score, best = score, g
    if best is None:
        return None
    images = best.get('images') or []
    if not images:
        return None
    img = images[0]
    return f"{img['path']}.{img['extension']}"


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
        'https://bifrost.marvel.com/v1/catalog/reading-lists/platform/web'
    )['data']['results']

    COVER_DIR.mkdir(parents=True, exist_ok=True)
    manifest = {}
    ok, miss = 0, 0
    for ev in events:
        eid = ev['id']
        dest = COVER_DIR / f'{eid}.jpg'
        if dest.exists():
            manifest[eid] = f'{eid}.jpg'
            ok += 1
            continue
        cover = ev.get('imageUrl') or match_guide_cover(guides, ev)
        if not cover:
            print(f'  ✗ {ev["title"]}: 没找到封面（官网指南无同名条目）')
            miss += 1
            continue
        try:
            size = download(cover, dest)
            manifest[eid] = f'{eid}.jpg'
            ok += 1
            print(f'  ✓ {ev["title"]} <- {cover} ({size // 1024}KB)')
        except Exception as e:
            print(f'  ✗ {ev["title"]}: 下载失败 {e}')
            miss += 1

    MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'\n完成：{ok} 张封面入库，{miss} 个没找到。')
    print(f'manifest: {MANIFEST}')
    if miss:
        print('没找到的会继续走运行时的网络加载/渐变兜底，不影响使用。')


if __name__ == '__main__':
    main()