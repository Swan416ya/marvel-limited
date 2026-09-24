#!/usr/bin/env python3
"""扫描 bifrost 角色号段，落盘「id -> 名字/头像」表。

用途：官网没有「按名字查角色 id」的接口（/v1/catalog/characters 全 400/403），
只能反过来：拿 id 查详情、按返回的名字筛选。经典角色的 id 密集分布在
1009xxx-1011xxx 与 1017xxx-1018xxx。

用法：python tool/scan_characters.py [起] [止]   （默认扫经典号段）
输出：.tmp/characters.json
"""

import json
import sys
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / '.tmp' / 'characters.json'
PROXY = 'http://127.0.0.1:8322/proxy/'
UA = ('Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      'Chrome/126 Mobile Safari/537.36')

# 经典角色号段（含各时期补录的 id）
RANGES = [(1009000, 1011500), (1017000, 1018000)]


def fetch(cid: int):
    url = f'https://bifrost.marvel.com/catalog/characters/{cid}'
    target = PROXY + urllib.parse.quote(url, safe='')
    req = urllib.request.Request(target, headers={
        'User-Agent': UA, 'Referer': 'https://www.marvel.com/',
        'Accept': 'application/json', 'Accept-Encoding': 'identity'})
    for _ in range(2):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                data = json.loads(r.read())['data']
            name = data.get('name') or ''
            img = data.get('image_url') or ''
            return (str(cid), {'name': name,
                               'img': bool(img) and 'image_not_available' not in img})
        except urllib.error.HTTPError as e:
            if e.code in (403, 404):
                return (str(cid), None)
        except Exception:
            pass
    return (str(cid), None)


def main():
    args = [a for a in sys.argv[1:] if a.isdigit()]
    ranges = [(int(args[0]), int(args[1]))] if len(args) >= 2 else RANGES
    ids = [i for lo, hi in ranges for i in range(lo, hi)]
    found = {}
    if OUT.exists():
        try:
            found = json.loads(OUT.read_text(encoding='utf-8'))
        except Exception:
            found = {}
    todo = [i for i in ids if str(i) not in found]
    print(f'待扫 {len(todo)} 个 id（已有 {len(found)} 条）', flush=True)

    done = 0
    with ThreadPoolExecutor(max_workers=12) as ex:
        for cid, info in ex.map(fetch, todo):
            done += 1
            if info is not None:
                found[cid] = info
            if done % 200 == 0:
                print(f'  {done}/{len(todo)}  命中 {len(found)}', flush=True)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(found, ensure_ascii=False, indent=1),
                   encoding='utf-8')
    print(f'完成：命中 {len(found)} 个角色，写入 {OUT}')


if __name__ == '__main__':
    main()
