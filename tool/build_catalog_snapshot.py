#!/usr/bin/env python3
"""把官网目录的关键数据集打包成应用内的「冷启动快照」。

为什么需要：Web/首启每次都要走网络拉大响应（指南列表 450KB、日历
700KB、单个指南的期数几百 KB），代理一抖就转圈半天。这个脚本把
三样东西的**精简版**固化进应用：
  1. guides    —— 官方阅读指南列表（id/标题/简介/封面）；
  2. latest    —— 全站最新已上架 issue（去重成系列，供系列页/首页）；
  3. guideIssues —— 最热门 N 个指南的逐期清单（指南详情秒开）。

应用侧的用法是 stale-while-revalidate：磁盘缓存没有命中时先用快照
顶上（立即出内容），后台再拉网络数据刷新。快照会旧，但「先看到东西」
比「等最新的」体验好得多——刷新一下就是新的。

用法：
    python tool/build_catalog_snapshot.py            # 全量重建
    python tool/build_catalog_snapshot.py --top 40   # 预取前 40 个指南的期数
"""

import json
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'data' / 'catalog_snapshot.json'

BIFROST = 'https://bifrost.marvel.com'
UA = ('Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36')

# 直连 bifrost 在国内网络经常被掐，先试本地开发代理
TARGETS = [
    lambda u: 'http://127.0.0.1:8322/proxy/' + urllib.parse.quote(u, safe=':/?&='),
    lambda u: u,
]


def get(url, tries=3):
    import time
    last = None
    for make in TARGETS:
        for i in range(tries):
            try:
                req = urllib.request.Request(make(url), headers={
                    'User-Agent': UA,
                    'Referer': 'https://www.marvel.com/',
                    'Accept': 'application/json',
                    'Accept-Encoding': 'identity',
                })
                with urllib.request.urlopen(req, timeout=40) as r:
                    return json.loads(r.read().decode('utf-8', 'replace'))
            except Exception as e:
                last = e
                time.sleep(0.6 * (i + 1))
    raise last


def series_from_title(title):
    """'Civil War (2006) #3' → ('Civil War', '3')。"""
    m = re.match(r'^(.*?)\s*(?:[(（][^)）]*[)）])?\s*#(\d+)', title)
    if m:
        return m.group(1).strip(), m.group(2)
    return title.split('#')[0].strip(), ''


def main():
    top = 30
    if '--top' in sys.argv:
        top = int(sys.argv[sys.argv.index('--top') + 1])

    print('拉官方阅读指南列表…')
    guides_raw = get(
        f'{BIFROST}/v1/catalog/reading-lists/platform/web')['data']['results']
    guides = [
        {
            'id': str(g['id']),
            'title': g.get('title') or '',
            'description': (g.get('description') or '')[:200],
            'coverUrl': (
                f"{g['images'][0]['path']}.{g['images'][0]['extension']}"
                if g.get('images') else None),
        }
        for g in guides_raw
    ]
    print(f'  指南 {len(guides)} 条')

    print('拉全站最新已上架 issue（日历窗口）…')
    import datetime
    now = datetime.date.today()
    start = now - datetime.timedelta(days=(now.weekday() + 6) % 7 + 21)
    cal = get(f'{BIFROST}/v1/catalog/comics/calendar?' + urllib.parse.urlencode({
        'byType': 'date', 'offset': 0, 'limit': 100,
        'orderBy': 'release_date+desc', 'variants': 'false',
        'formatType': 'issue',
        'dateStart': start.isoformat(), 'dateEnd': now.isoformat(),
    }))
    issues_raw = cal['data']['results']
    latest = [
        {
            'id': str(i['id']),
            'title': i.get('title') or '',
            'seriesTitle': (i.get('metadata', {}).get('series', {}) or {})
                .get('title', '')
                or series_from_title(i.get('title') or '')[0],
            'seriesId': str((i.get('metadata', {}).get('series', {}) or {})
                .get('id', '')),
            'issueNumber': str(i.get('issue_number') or ''),
            'releaseDate': (i.get('release_date') or '')[:10],
            'coverUrl': (
                f"{i['image_url']}/portrait_uncanny.{i.get('thumb_ext') or 'jpg'}"
                if i.get('image_url') and 'image_not_available' not in i['image_url']
                else None),
        }
        for i in issues_raw
        if str(i.get('is_variant')) != '1'
    ]
    print(f'  最新 issue {len(latest)} 条')

    print(f'预取前 {top} 个指南的逐期清单…')
    guide_issues = {}
    for n, g in enumerate(guides[:top], 1):
        gid = g['id']
        try:
            body = get(f'{BIFROST}/v1/catalog/reading-lists/{gid}'
                       '?limit=1000&offset=0')
            contents = body['data']['results'][0].get('contents') or []
        except Exception as e:
            print(f'  ✗ {g["title"][:36]}: {str(e)[:50]}')
            continue
        items = []
        for c in contents:
            series, number = series_from_title(c.get('title') or '')
            thumb = c.get('thumbnail') or {}
            items.append({
                'id': str(c['id']),
                'title': c.get('title') or '',
                'seriesTitle': series,
                'issueNumber': number,
                'releaseDate': (c.get('release_date') or '')[:10],
                'coverUrl': (
                    f"{thumb['path']}.{thumb['extension']}"
                    if thumb.get('path') else None),
            })
        guide_issues[gid] = items
        print(f'  ✓ [{n}/{top}] {g["title"][:40]} {len(items)} 期')

    snapshot = {
        'generatedAt': datetime.datetime.now().isoformat(timespec='seconds'),
        'guides': guides,
        'latest': latest,
        'guideIssues': guide_issues,
    }
    OUT.write_text(json.dumps(snapshot, ensure_ascii=False), encoding='utf-8')
    size = OUT.stat().st_size
    print(f'\n快照写入 {OUT}（{size / 1024:.0f}KB）')


if __name__ == '__main__':
    main()