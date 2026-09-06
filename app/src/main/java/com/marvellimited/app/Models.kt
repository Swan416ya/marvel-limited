package com.marvellimited.app

/** 漫画 issue（一期） */
data class Issue(
    val id: String,
    val title: String,
    val seriesTitle: String = "",
    val seriesId: String? = null,
    val issueNumber: String = "",
    val releaseDate: String = "",
    val description: String = "",
    val coverUrl: String? = null,
    val creators: List<String> = emptyList(),
    val isWiki: Boolean = false,
)

/** 阅读指南（大事件专题） */
data class Guide(
    val id: String,
    val title: String,
    val description: String = "",
    val coverUrl: String? = null,
)

/** 官网首页内嵌栏目的一期 */
data class HomeIssue(
    val id: String,
    val title: String,
    val releaseDate: String = "",
    val coverUrl: String? = null,
    val issueLink: String = "",
)

/** 官网首页四栏目数据 */
data class HomePageData(
    val newThisWeek: List<HomeIssue> = emptyList(),
    val bestSelling: List<HomeIssue> = emptyList(),
    val newInUnlimited: List<HomeIssue> = emptyList(),
    val freeInUnlimited: List<HomeIssue> = emptyList(),
)

/** bifrost JSON 解析 */
object Parse {
    fun homeIssue(json: Map<*, *>): HomeIssue {
        val image = json["image"] as? Map<*, *>
        val link = json["link"] as? Map<*, *>
        return HomeIssue(
            id = json["id"].toString(),
            title = json["headline"]?.toString() ?: "",
            releaseDate = json["releaseDate"]?.toString() ?: "",
            coverUrl = image?.get("filename")?.toString(),
            issueLink = link?.get("link")?.toString() ?: "",
        )
    }

    fun guide(json: Map<*, *>): Guide {
        val images = json["images"] as? List<*>
        val img = images?.firstOrNull() as? Map<*, *>
        return Guide(
            id = json["id"].toString(),
            title = json["title"]?.toString() ?: "",
            description = stripHtml(json["description"]?.toString() ?: ""),
            coverUrl = img?.let { it["path"].toString() + "." + it["extension"] },
        )
    }

    fun issueFromGuideContent(json: Map<*, *>): Issue {
        val title = json["title"]?.toString() ?: ""
        val thumb = json["thumbnail"] as? Map<*, *>
        return Issue(
            id = json["id"].toString(),
            title = title,
            seriesTitle = seriesOf(title),
            issueNumber = numberOf(title),
            releaseDate = json["release_date"]?.toString() ?: "",
            description = stripHtml(json["description"]?.toString() ?: ""),
            coverUrl = thumb?.let { it["path"].toString() + "/portrait_uncanny." + it["extension"] },
            creators = (json["creators_short"]?.toString() ?: "")
                .split(",").map { it.trim() }.filter { it.isNotEmpty() },
        )
    }

    fun issueFromSeries(json: Map<*, *>): Issue {
        val meta = json["metadata"] as? Map<*, *> ?: json
        val series = meta["series"] as? Map<*, *>
        val imageBase = json["image_url"]?.toString() ?: ""
        val ext = json["thumb_ext"]?.toString() ?: "jpg"
        val creators = (json["creators"] as? List<*>)?.map { it.toString() } ?: emptyList()
        return Issue(
            id = json["id"].toString(),
            title = json["title"]?.toString() ?: "",
            seriesTitle = series?.get("title")?.toString() ?: "",
            seriesId = series?.get("id")?.toString(),
            issueNumber = json["issue_number"].toString(),
            releaseDate = json["release_date"]?.toString() ?: "",
            description = stripHtml(json["summary"]?.toString() ?: meta["description"]?.toString() ?: ""),
            coverUrl = if (imageBase.isEmpty()) null else {
                if (imageBase.startsWith("http")) imageBase + "/portrait_uncanny." + ext
                else "https://cdn.marvel.com/u/prod/marvel" + imageBase + "/portrait_uncanny." + ext
            },
            creators = creators,
        )
    }

    fun seriesOf(title: String): String {
        val i = title.lastIndexOf(" #")
        return if (i > 0) title.substring(0, i) else title
    }

    fun numberOf(title: String): String {
        val i = title.lastIndexOf(" #")
        return if (i > 0) title.substring(i + 2) else ""
    }

    fun stripHtml(s: String): String =
        s.replace(Regex("<[^>]*>"), "").trim()

    /** issue 排序键：纯数字按数值，带字母后缀排最后 */
    fun sortKey(n: String): Double {
        n.toDoubleOrNull()?.let { return it }
        val base = Regex("^\\d+").find(n)?.value?.toDoubleOrNull() ?: 99999.0
        return base + 0.75
    }
}
