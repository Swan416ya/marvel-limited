# marvel.com/comics 首页数据源

页面 HTML 内嵌 JSON（无独立 XHR，直接抓 HTML 解析即可，GET https://www.marvel.com/comics 带 UA）：

- `newComicsThisWeek` — 本周新刊（15 条，含 headline/releaseDate/id/封面/链接）→ 主页 Banner「最近更新」
- `bestSelling` — 畅销榜（20 条）
- `newInMarvelUnlimited` — MU 新上架（20 条）
- `freeInMarvelUnlimited` — MU 免费（20 条）
- `mastheadSliders` — 官网 banner 轮播（图片 large 字段可做横幅底图）

大事件指南继续用 bifrost reading-lists 接口（766 个，已验证）。
系列期数：bifrost byId=comic_series 接口实测部分系列返回 total=0（如 X OF SWORDS 31037），series 页面 SSR HTML 也是 0 results（水合后才有数据）。系列期数数据在 hydration blob 里，无独立 XHR。需要另找方案：从 guide contents 或首页 issue 的 series id 入手。

## 大事件专属列表

766 个 guide 中带 "Complete Event" 字样的有 16 个，例如：Civil War (114)、Secret Invasion (133)、Infinity (47)、Age of Ultron (87)、World War Hulk (81)、House of M (258)、Empyre (1968)、Age of Apocalypse (84)、Avengers vs. X-Men (41)、Spider-Verse (1020)、Spider-Geddon (1395)、Spider-Island (248)、Age of X-Man (1541)、Sins of Sinister (2377)、X-Men: Onslaught (1117)、X-Men: Battle of the Atom (136)。
