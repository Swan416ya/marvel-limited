#!/usr/bin/env python3
"""把系列页顶部的英雄头像下载并封进应用本体。

为什么：头像图床（cdn.marvel.com）直连经常被掐断（实测连接重置），
应用里时灵时不灵。封进本体后离线可用、秒开。

用法：

    python tool/fetch_hero_avatars.py        # 下载 12 个英雄头像
    python tool/fetch_hero_avatars.py --clean

跑完重启应用即生效。图很小（每个 ~15KB）。
"""

import json
import sys
import urllib.request
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / 'assets' / 'data' / 'hero_avatars'
MANIFEST = OUT_DIR / 'manifest.json'

# 与 lib/features/series_hub/heroes.dart 保持一致
HEROES = {
    '1009610': 'Spider-Man (Peter Parker)',
    '1009368': 'Iron Man',
    '1009165': 'Avengers',
    '1009726': 'X-Men',
    '1009664': 'Thor',
    '1009351': 'Hulk (Bruce Banner)',
    '1009282': 'Doctor Strange',
    '1009718': 'Wolverine (Logan)',
    '1011299': 'Guardians of the Galaxy',
    '1009268': 'Deadpool',
    '1009220': 'Captain America (Steve Rogers)',
    '1009299': 'Fantastic Four',
}

PROXY = 'http://127.0.0.1:8322/proxy/'
UA = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/126 Mobile Safari/537.36'


def get_json(url):
    target = PROXY + urllib.parse.quote(url, safe='')
    req = urllib.request.Request(target, headers={
        'User-Agent': UA, 'Referer': 'https://www.marvel.com/',
        'Accept': 'application/json', 'Accept-Encoding': 'identity'})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read())


def download(url, dest: Path):
    target = PROXY + urllib.parse.quote(url, safe='')
    req = urllib.request.Request(target, headers={
        'User-Agent': UA, 'Referer': 'https://www.marvel.com/'})
    last = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                data = r.read()
            dest.write_bytes(data)
            return len(data)
        except Exception as e:
            last = e
    raise last


def main():
    if '--clean' in sys.argv:
        if OUT_DIR.exists():
            for f in OUT_DIR.glob('*'):
                if f.is_file():
                    f.unlink()
            print('已清空 hero_avatars')
        return

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    manifest = {}
    ok, fail = 0, 0
    for cid, name in HEROES.items():
        dest = OUT_DIR / f'{cid}.jpg'
        if dest.exists():
            manifest[cid] = f'{cid}.jpg'
            ok += 1
            continue
        try:
            detail = get_json(f'https://bifrost.marvel.com/catalog/characters/{cid}')
            data = detail['data']
            base = data['image_url']
            ext = data.get('image_extension', 'jpg')
            if not base or 'image_not_available' in base:
                print(f'  ✗ {name}: 官方无头像')
                fail += 1
                continue
            size = download(f'{base}/standard_fantastic.{ext}', dest)
            manifest[cid] = f'{cid}.jpg'
            ok += 1
            print(f'  ✓ {name} ({size // 1024}KB)')
        except Exception as e:
            print(f'  ✗ {name}: {e}')
            fail += 1

    MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'\n完成：{ok} 个头像入库，{fail} 个失败。manifest: {MANIFEST}')


if __name__ == '__main__':
    main()