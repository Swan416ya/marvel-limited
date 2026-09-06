package com.marvellimited.app

import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.util.concurrent.TimeUnit

/** 漫威数据源：bifrost（官网目录）+ fandom wiki（补全下架期数） */
object MarvelApi {
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()
    private val gson = Gson()

    private val headers = mapOf(
        "User-Agent" to "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/126.0.0.0 Mobile Safari/537.36",
        "Referer" to "https://www.marvel.com/",
        "Accept" to "application/json",
    )

    private suspend fun get(url: String): String = withContext(Dispatchers.IO) {
        val req = Request.Builder().url(url).apply {
            headers.forEach { (k, v) -> header(k, v) }
        }.build()
        client.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) throw RuntimeException("HTTP " + resp.code)
            resp.body!!.string()
        }
    }

    private inline fun <reified T> parseJson(s: String): T =
        gson.fromJson(s, object : TypeToken<T>() {}.type)

    /** 官网漫画首页：HTML 内嵌四栏目数据 */
    suspend fun homePage(): HomePageData {
        val html = get("https://www.marvel.com/comics")
        fun section(name: String): List<HomeIssue> {
            val start = html.indexOf("\"" + name + "\":")
            if (start < 0) return emptyList()
            val arrStart = html.indexOf('[', start)
            if (arrStart < 0) return emptyList()
            var depth = 0
            var inStr = false
            var escape = false
            var end = -1
            for (i in arrStart until html.length) {
                val c = html[i]
                if (escape) { escape = false; continue }
                when {
                    c == '\\' && inStr -> escape = true
                    c == '"' -> inStr = !inStr
                    !inStr && c == '[' -> depth++
                    !inStr && c == ']' -> {
                        depth--
                        if (depth == 0) { end = i; break }
                    }
                }
            }
            if (end < 0) return emptyList()
            val arrJson = html.substring(arrStart, end + 1)
            return try {
                val list = parseJson<List<Map<String, Any?>>>(arrJson)
                list.map(Parse::homeIssue)
            } catch (e: Exception) {
                emptyList()
            }
        }
        return HomePageData(
            newThisWeek = section("newComicsThisWeek"),
            bestSelling = section("bestSelling"),
            newInUnlimited = section("newInMarvelUnlimited"),
            freeInUnlimited = section("freeInMarvelUnlimited"),
        )
    }

    /** 官方阅读指南列表（大事件专题） */
    suspend fun guides(): List<Guide> {
        val body = parseJson<Map<String, Any?>>(
            get("https://bifrost.marvel.com/v1/catalog/reading-lists/platform/web"))
        val results = (body["data"] as Map<*, *>)["results"] as List<*>
        return results.mapNotNull { it as? Map<*, *> }.map(Parse::guide)
    }

    /** 指南详情：按官方顺序的 issue 列表 */
    suspend fun guideIssues(guideId: String): List<Issue> {
        val body = parseJson<Map<String, Any?>>(
            get("https://bifrost.marvel.com/v1/catalog/reading-lists/" + guideId + "?limit=1000&offset=0"))
        val results = (body["data"] as Map<*, *>)["results"] as List<*>
        val list = results.firstOrNull() as? Map<*, *> ?: return emptyList()
        val contents = list["contents"] as? List<*> ?: return emptyList()
        return contents.mapNotNull { it as? Map<*, *> }.map(Parse::issueFromGuideContent)
    }

    /** 系列全部期数（官网目录） */
    suspend fun seriesIssues(seriesId: String): List<Issue> {
        val all = mutableListOf<Issue>()
        var offset = 0
        while (true) {
            val url = "https://bifrost.marvel.com/v1/catalog/comics/" +
                "?byId=" + seriesId + "&byZone=marvel_site_zone&byType=comic_series" +
                "&orderBy=release_date+desc&formatType=issue,digitalcomic,collection,digitalverticalcomic" +
                "&limit=50&offset=" + offset + "&variants=false&getThumb=1"
            val body = parseJson<Map<String, Any?>>(get(url))
            val data = body["data"] as Map<*, *>
            val results = data["results"] as List<*>
            all += results.mapNotNull { it as? Map<*, *> }.map(Parse::issueFromSeries)
            val total = (data["total"] as Number).toInt()
            offset += 50
            if (offset >= total || results.isEmpty()) break
        }
        return all.sortedBy { Parse.sortKey(it.issueNumber) }
    }

    /** 系列全部期数（fandom wiki allpages 枚举 + 并发解析 wikitext） */
    suspend fun seriesIssuesByFandom(seriesTitle: String): List<Issue> {
        val vol = seriesTitle.trim().replace(Regex(" Vol \\d+$"), "")
        // 先在 wiki 里找该系列对应的 "XXX Vol N" 页面名
        val candidates = searchSeries(vol)
        val seriesPage = candidates.firstOrNull { it.equals(seriesTitle.trim(), ignoreCase = true) }
            ?: candidates.firstOrNull()
            ?: vol.let { it + " Vol 1" } // 兜底：直接拿名字试
        val nums = fandomSeriesIssueNumbers(seriesPage)
        if (nums.isEmpty()) return emptyList()
        val issues = coroutineScope {
            nums.map { num ->
                async(Dispatchers.IO) { fandomIssue(seriesPage, num) }
            }.awaitAll().filterNotNull()
        }
        return issues
    }

    /** fandom wiki：系列名搜索（opensearch） */
    suspend fun searchSeries(query: String): List<String> {
        val url = "https://marvel.fandom.com/api.php?action=opensearch&search=" +
            java.net.URLEncoder.encode(query, "UTF-8") + "&limit=15&format=json"
        val body = parseJson<List<Any?>>(get(url))
        return (body.getOrNull(1) as? List<*>)?.map { it.toString() }
            ?.filter { Regex(" Vol \\d+$").containsMatchIn(it) } ?: emptyList()
    }

    /** fandom wiki：全站搜索（任意页，含 issue 页） */
    suspend fun searchIssues(query: String): List<Issue> {
        val url = "https://marvel.fandom.com/api.php?action=query&list=search&srsearch=" +
            java.net.URLEncoder.encode(query, "UTF-8") + "&srlimit=15&format=json"
        return try {
            val body = parseJson<Map<String, Any?>>(get(url))
            val search = ((body["query"] as Map<*, *>)["search"] as? List<*>) ?: return emptyList()
            search.mapNotNull { it as? Map<*, *> }
                .mapNotNull { p -> p["title"]?.toString() }
                // 只保留 "系列名 + 期号" 形态的页面
                .filter { title ->
                    val m = Regex("^(.+) Vol \\d+ (\\d+[A-Za-z]?)$").find(title) ?: return@filter false
                    true
                }
                .map { title ->
                    val m = Regex("^(.+) Vol (\\d+) (\\d+[A-Za-z]?)$").find(title)!!
                    Issue(
                        id = "fandom:" + title,
                        title = title,
                        seriesTitle = m.groupValues[1] + " Vol " + m.groupValues[2],
                        issueNumber = m.groupValues[3],
                        isWiki = true,
                    )
                }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /** fandom wiki：某系列全部 issue 页（allpages 枚举） */
    suspend fun fandomSeriesIssueNumbers(seriesPageName: String): List<String> {
        val url = "https://marvel.fandom.com/api.php?action=query&list=allpages" +
            "&apprefix=" + java.net.URLEncoder.encode(seriesPageName + " ", "UTF-8") +
            "&aplimit=500&format=json"
        val body = parseJson<Map<String, Any?>>(get(url))
        val pages = ((body["query"] as Map<*, *>)["allpages"] as? List<*>) ?: return emptyList()
        val prefix = seriesPageName + " "
        return pages.mapNotNull { (it as? Map<*, *>)?.get("title")?.toString() }
            .filter { it.startsWith(prefix) && Regex("^\\d+$").matches(it.substring(prefix.length)) }
            .map { it.substring(prefix.length) }
            .sortedBy { it.toIntOrNull() ?: 0 }
    }

    /** fandom wiki：issue 详情（wikitext 解析封面和日期） */
    suspend fun fandomIssue(seriesPageName: String, issueNumber: String): Issue? {
        val pageName = seriesPageName + " " + issueNumber
        val url = "https://marvel.fandom.com/api.php?action=parse&page=" +
            java.net.URLEncoder.encode(pageName, "UTF-8") + "&prop=wikitext&format=json"
        return try {
            val body = parseJson<Map<String, Any?>>(get(url))
            val parse = body["parse"] as? Map<*, *> ?: return null
            val wikitext = ((parse["wikitext"] as Map<*, *>)["*"]).toString()
            if (wikitext.startsWith("#REDIRECT")) {
                val m = Regex("\\[\\[([^\\]|]+)").find(wikitext) ?: return null
                fandomIssueByPage(m.groupValues[1], seriesPageName, issueNumber)
            } else {
                issueFromWikitext(pageName, wikitext, seriesPageName, issueNumber)
            }
        } catch (e: Exception) {
            null
        }
    }

    private suspend fun fandomIssueByPage(pageName: String, series: String, num: String): Issue? {
        val url = "https://marvel.fandom.com/api.php?action=parse&page=" +
            java.net.URLEncoder.encode(pageName, "UTF-8") + "&prop=wikitext&format=json"
        return try {
            val body = parseJson<Map<String, Any?>>(get(url))
            val parse = body["parse"] as? Map<*, *> ?: return null
            val wikitext = ((parse["wikitext"] as Map<*, *>)["*"]).toString()
            issueFromWikitext(pageName, wikitext, series, num)
        } catch (e: Exception) {
            null
        }
    }

    private suspend fun issueFromWikitext(pageName: String, wikitext: String, series: String, num: String): Issue? {
        fun field(name: String): String {
            val m = Regex("\\|\\s*" + name + "\\s*=([^\\n|]*)").find(wikitext) ?: return ""
            return m.groupValues[1].trim()
        }
        val releaseDate = field("ReleaseDate")
        if (releaseDate.isEmpty()) return null
        val imageFile = field("Image1")
        val cover = if (imageFile.isNotEmpty()) fandomImageUrl(imageFile) else null
        return Issue(
            id = "fandom:" + pageName,
            title = series + " #" + num,
            seriesTitle = series,
            issueNumber = num,
            releaseDate = releaseDate,
            description = field("Solicit"),
            coverUrl = cover,
            isWiki = true,
        )
    }

    private suspend fun fandomImageUrl(fileName: String): String? {
        return try {
        val url = "https://marvel.fandom.com/api.php?action=query&titles=" +
            java.net.URLEncoder.encode("File:" + fileName, "UTF-8") +
            "&prop=imageinfo&iiprop=url&format=json"
        val body = parseJson<Map<String, Any?>>(get(url))
        val pages = (body["query"] as Map<*, *>)["pages"] as Map<*, *>
        for (p in pages.values) {
            val infos = (p as Map<*, *>)["imageinfo"] as? List<*>
            if (infos != null && infos.isNotEmpty()) {
                return (infos.first() as Map<*, *>)["url"].toString()
            }
        }
        null
        } catch (e: Exception) {
            null
        }
    }
}
