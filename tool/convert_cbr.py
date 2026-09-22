#!/usr/bin/env python3
"""把漫画库里的 CBR（RAR 压缩）批量转成 CBZ（zip），应用才能导入。

为什么需要：Dart 生态没有 RAR5 解压器，应用内只能解 zip。
实测你的漫画库（E:\\Comic Manager Library）里 80 个 .cbr 全是真 RAR。
本脚本用本机 7-Zip（C:\\Program Files\\7-Zip\\7z.exe）逐个转：
解压到临时目录 → 重新打包成同名 .cbz（放在原文件旁边）。

用法：

    python tool/convert_cbr.py                    # 转换整个漫画库
    python tool/convert_cbr.py "E:/某个目录"        # 只转指定目录（递归）
    python tool/convert_cbr.py --check            # 只统计不转换

- 已存在的同名 .cbz 会跳过（不重复转）。
- 原 .cbr 不删；确认应用里都导好了再自己清理。
- 转完在应用收藏页点「+」选择 .cbz 文件导入。
"""

import subprocess
import sys
import tempfile
from pathlib import Path

SEVEN_ZIP = Path(r'C:\Program Files\7-Zip\7z.exe')
DEFAULT_LIB = Path(r'E:\Comic Manager Library')


def run_7z(*args):
    result = subprocess.run(
        [str(SEVEN_ZIP), *args],
        capture_output=True, text=True, encoding='utf-8', errors='replace',
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f'7z exit {result.returncode}')


def is_rar(path: Path) -> bool:
    try:
        with open(path, 'rb') as f:
            return f.read(4) == b'Rar!'
    except OSError:
        return False


def convert(cbr: Path, cbz: Path) -> int:
    """解压 cbr 到临时目录再打包成 cbz，返回 cbz 字节数。"""
    with tempfile.TemporaryDirectory(prefix='cbr2cbz_') as tmp:
        tmpdir = Path(tmp)
        run_7z('x', str(cbr), f'-o{tmpdir}', '-y', '-aoa')
        run_7z('a', '-tzip', str(cbz), f'{tmpdir}\\*', '-mx=1')
        return cbz.stat().st_size


def main():
    if not SEVEN_ZIP.exists():
        print(f'没找到 7-Zip：{SEVEN_ZIP}')
        print('装一下 7-Zip 或者改脚本里的 SEVEN_ZIP 路径。')
        sys.exit(1)

    check_only = '--check' in sys.argv
    root = Path(sys.argv[1]) if len(sys.argv) > 1 and not sys.argv[1].startswith('-') else DEFAULT_LIB
    if not root.exists():
        print(f'目录不存在：{root}')
        sys.exit(1)

    cbrs = sorted(root.rglob('*.cbr'))
    print(f'扫描 {root}：{len(cbrs)} 个 .cbr')

    converted, skipped_zip, skipped_exists, failed = 0, 0, 0, 0
    for i, cbr in enumerate(cbrs, 1):
        cbz = cbr.with_suffix('.cbz')
        prefix = f'[{i}/{len(cbrs)}]'
        if cbz.exists():
            skipped_exists += 1
            continue
        if not is_rar(cbr):
            # 假 cbr（其实是 zip）：直接复制改名
            cbz.write_bytes(cbr.read_bytes())
            skipped_zip += 1
            print(f'{prefix} {cbr.name} 是假 CBR（zip），直接改名')
            continue
        if check_only:
            print(f'{prefix} {cbr.name} 需要 转换')
            continue
        try:
            size = convert(cbr, cbz)
            converted += 1
            print(f'{prefix} {cbr.name} -> {cbz.name} ({size // 1024}KB)')
        except Exception as e:
            failed += 1
            print(f'{prefix} {cbr.name} 失败: {e}')

    print(f'\n完成：{converted} 转换，{skipped_zip} 假CBR改名，'
          f'{skipped_exists} 已存在跳过，{failed} 失败')


if __name__ == '__main__':
    main()