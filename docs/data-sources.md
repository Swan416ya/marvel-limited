# marvel.com/comics 首页数据源

页面 HTML 内嵌 JSON（无独立 XHR，直接抓 HTML 解析即可，GET https://www.marvel.com/comics 带 UA）：

- `newComicsThisWeek` — 本周新刊（15 条，含 headline/releaseDate/id/封面/链接）→ 主页 Banner「最近更新」
- `bestSelling` — 畅销榜（20 条）
- `newInMarvelUnlimited` — MU 新上架（20 条）
- `freeInMarvelUnlimited` — MU 免费（20 条）
- `mastheadSliders` — 官网 banner 轮播（图片 large 字段可做横幅底图）

大事件指南继续用 bifrost reading-lists 接口（766 个，已验证）。
系列期数继续用 bifrost byId=comic_series 接口（已验证）。

