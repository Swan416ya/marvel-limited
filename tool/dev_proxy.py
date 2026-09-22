#!/usr/bin/env python3
"""开发用 CORS 代理（Web 端联调用）。

为什么需要它：浏览器里直接请求 bifrost.marvel.com 和 marvel.fandom.com
会被跨域策略拒绝，所以 Web 端的两个 client 会把请求发到本地代理——

    http://127.0.0.1:8322/proxy/<原始 URL>[?原查询串]

本脚本就是那个代理：取出 `/proxy/` 之后的部分当目标地址，代请求一次，
再把响应体原样返回，并补上 `Access-Control-Allow-Origin: *`。
Android / 桌面端直连，不需要它。

用法：

    python tool/dev_proxy.py            # 默认 127.0.0.1:8322
    python tool/dev_proxy.py 9000       # 换端口（记得同步改 client 里的 _proxy）

只依赖标准库。日志一行一个请求，方便对着看哪个接口挂了。
"""

import gzip
import sys
import time
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.parse import unquote
from urllib.request import Request, urlopen

DEFAULT_PORT = 8322
PROXY_PREFIX = "/proxy/"
TIMEOUT = 30

# 大响应偶尔会被 CDN 中途掐断（IncompleteRead），重试几次
RETRIES = 3

# 目标站点会检查 UA/Referer，照抄 App 里用的那套
UA = (
    "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36"
)


def fetch(target):
    """取回目标地址，返回 (status, content_type, body)。

    带 gzip 与重试：bifrost 的指南列表未压缩有 450KB，压完 130KB，
    体积小得多也更不容易被中途掐断；万一还是断了就重来。
    """
    headers = {
        "User-Agent": UA,
        "Accept": "*/*",
        "Accept-Encoding": "gzip",
    }
    if "marvel.com" in target:
        headers["Referer"] = "https://www.marvel.com/"

    last_error = None
    for attempt in range(RETRIES):
        try:
            with urlopen(Request(target, headers=headers), timeout=TIMEOUT) as resp:
                raw = resp.read()
                encoding = (resp.headers.get("Content-Encoding") or "").lower()
                if "gzip" in encoding:
                    raw = gzip.decompress(raw)
                elif "deflate" in encoding:
                    raw = zlib.decompress(raw)
                return (
                    resp.status,
                    resp.headers.get("Content-Type", "application/json"),
                    raw,
                )
        except HTTPError as e:
            # 4xx/5xx 重试也没意义，直接把它转给前端
            try:
                body = e.read()
            except Exception:
                body = b""
            return e.code, "application/json", body
        except Exception as e:  # IncompleteRead / URLError / 超时
            last_error = e
            time.sleep(0.4 * (attempt + 1))
    raise last_error


class ProxyHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_OPTIONS(self):  # noqa: N802 (标准库命名)
        self.send_response(204)
        self._cors()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):  # noqa: N802
        if not self.path.startswith(PROXY_PREFIX):
            self._text(
                200,
                "dev_proxy 在跑。用法：/proxy/<原始 URL>\n"
                "例如 /proxy/https://bifrost.marvel.com/v1/catalog/reading-lists/platform/web\n",
            )
            return

        target = unquote(self.path[len(PROXY_PREFIX):])
        if not target.startswith(("http://", "https://")):
            self._text(400, f"目标地址不合法：{target}\n")
            return

        try:
            status, content_type, body = fetch(target)
            self._log(f"{status} {len(body)}B {target}")
            self.send_response(status)
            self._cors()
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except Exception as e:
            self._log(f"502 {target} :: {type(e).__name__} {e}")
            self._text(502, f"代理转发失败：{type(e).__name__}: {e}\n")

    def do_POST(self):  # noqa: N802
        """转发 POST（官网 lockjaw typeahead 用的是 POST 表单）。"""
        if not self.path.startswith(PROXY_PREFIX):
            self._text(400, "只支持 /proxy/<原始 URL>\n")
            return
        target = unquote(self.path[len(PROXY_PREFIX):])
        if not target.startswith(("http://", "https://")):
            self._text(400, f"目标地址不合法：{target}\n")
            return
        length = int(self.headers.get("Content-Length", "0") or 0)
        body = self.rfile.read(length) if length else None
        headers = {"User-Agent": UA, "Accept": "*/*"}
        content_type = self.headers.get("Content-Type")
        if content_type:
            headers["Content-Type"] = content_type
        if "marvel.com" in target:
            headers["Referer"] = "https://www.marvel.com/"
        try:
            req = Request(target, data=body, headers=headers, method="POST")
            with urlopen(req, timeout=TIMEOUT) as resp:
                data = resp.read()
                self._log(f"POST {resp.status} {len(data)}B {target}")
                self.send_response(resp.status)
                self._cors()
                self.send_header(
                    "Content-Type",
                    resp.headers.get("Content-Type", "application/json"),
                )
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
        except HTTPError as e:
            data = e.read()
            self._log(f"POST {e.code} {target}")
            self.send_response(e.code)
            self._cors()
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except Exception as e:
            self._log(f"POST 502 {target} :: {e}")
            self._text(502, f"代理转发失败：{e}\n")

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")

    def _text(self, status, text):
        body = text.encode("utf-8")
        self.send_response(status)
        self._cors()
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _log(self, line):
        print(f"[proxy] {line}", flush=True)

    def log_message(self, fmt, *args):
        pass  # 用上面的 _log，别把标准库那行噪声打出来


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PORT
    server = ThreadingHTTPServer(("127.0.0.1", port), ProxyHandler)
    print(f"[proxy] listening on http://127.0.0.1:{port}/proxy/  (Ctrl+C 停止)", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[proxy] bye", flush=True)


if __name__ == "__main__":
    main()