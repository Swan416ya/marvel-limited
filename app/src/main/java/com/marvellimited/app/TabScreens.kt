package com.marvellimited.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items as gridItems
import androidx.compose.foundation.lazy.items as listItems
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.launch

/** 搜索结果的类型 */
sealed interface SearchResult {
    data class SeriesResult(val title: String) : SearchResult
    data class GuideResult(val guide: Guide) : SearchResult
    data class IssueResult(val issue: Issue) : SearchResult
}

private val SearchFilters = listOf("全部", "系列", "大事件", "指南", "期")
private const val PageSize = 20

/** 搜索页：支持系列/事件/指南/期号搜索 + 分类筛选 */
@OptIn(FlowPreview::class)
@Composable
fun SearchScreen(nav: (Any) -> Unit, initialQuery: String = "") {
    var query by remember { mutableStateOf(initialQuery) }
    var filter by remember { mutableStateOf("全部") }
    var allResults by remember { mutableStateOf<List<SearchResult>>(emptyList()) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var searched by remember { mutableStateOf(false) }
    var visibleCount by remember { mutableStateOf(PageSize) }
    val scope = rememberCoroutineScope()
    val queryFlow = remember { MutableStateFlow(initialQuery) }

    // 首次进入带初始词则直接搜
    LaunchedEffect(initialQuery) {
        if (initialQuery.isNotBlank() && allResults.isEmpty() && !loading) {
            searchAll(initialQuery).let { allResults = it; searched = true }
        }
    }

    fun doSearch(q: String) {
        scope.launch {
            loading = true; error = null; searched = true; visibleCount = PageSize
            try { allResults = searchAll(q) } catch (e: Exception) { error = e.message }
            loading = false
        }
    }

    LaunchedEffect(Unit) {
        queryFlow.debounce(400).collect { q ->
            if (q.isNotBlank() && q == query) doSearch(q.trim())
            else if (q.isBlank()) { allResults = emptyList(); searched = false }
        }
    }

    val filtered = allResults.filter {
        when (filter) {
            "系列" -> it is SearchResult.SeriesResult
            "大事件" -> it is SearchResult.GuideResult && it.guide.title.contains("Complete Event", true)
            "指南" -> it is SearchResult.GuideResult && !it.guide.title.contains("Complete Event", true)
            "期" -> it is SearchResult.IssueResult
            else -> true
        }
    }

    Column(Modifier.fillMaxSize()) {
        Spacer(Modifier.height(WindowInsets.statusBars.asPaddingValues().calculateTopPadding()))
        OutlinedTextField(
            value = query,
            onValueChange = {
                query = it; queryFlow.value = it
            },
            placeholder = { Text("搜索系列、大事件、指南或期号") },
            leadingIcon = { Icon(Icons.Filled.Search, null) },
            singleLine = true,
            shape = RoundedCornerShape(14.dp),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = { doSearch(query.trim()) }),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
        )

        // 分类筛选
        LazyRow(
            contentPadding = PaddingValues(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(bottom = 4.dp),
        ) {
            listItems(SearchFilters) { f ->
                FilterChip(
                    selected = filter == f,
                    onClick = { filter = f; visibleCount = PageSize },
                    label = { Text(f, fontSize = 13.sp) },
                )
            }
        }

        when {
            loading -> LoadingState()
            error != null -> ErrorState(error!!) { doSearch(query.trim()) }
            !searched -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("输入关键词开始搜索", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            filtered.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("没有找到相关内容", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            else -> LazyColumn(contentPadding = PaddingValues(bottom = 24.dp)) {
                items(filtered.take(visibleCount), key = {
                    when (it) {
                        is SearchResult.SeriesResult -> "s:" + it.title
                        is SearchResult.GuideResult -> "g:" + it.guide.id
                        is SearchResult.IssueResult -> "i:" + it.issue.id
                    }
                }) { r ->
                    when (r) {
                        is SearchResult.SeriesResult -> SeriesSearchRow(r.title, nav)
                        is SearchResult.GuideResult -> GuideRowItem(r.guide, nav)
                        is SearchResult.IssueResult -> IssueRow(r.issue, nav)
                    }
                }
                if (visibleCount < filtered.size) {
                    item {
                        TextButton(
                            onClick = { visibleCount += PageSize },
                            modifier = Modifier.fillMaxWidth(),
                        ) { Text("加载更多（" + (filtered.size - visibleCount).coerceAtLeast(0) + " 条）") }
                    }
                }
            }
        }
    }
}

/** 搜索所有类型 */
private suspend fun searchAll(q: String): List<SearchResult> {
    val guides = MarvelApi.guides()
    val guideHits = guides.filter { it.title.contains(q, true) }
        .sortedByDescending { it.title.contains("Complete Event", true) }
        .map { SearchResult.GuideResult(it) }
    val seriesHits = MarvelApi.searchSeries(q).take(10).map { SearchResult.SeriesResult(it) }
    val issueHits = MarvelApi.searchIssues(q).take(10).map { SearchResult.IssueResult(it) }
    return guideHits + seriesHits + issueHits
}

/** 搜索行：系列 */
@Composable
private fun SeriesSearchRow(title: String, nav: (Any) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickableNoRipple { nav(SeriesNav(null, title, title)) }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center,
        ) {
            Text("系", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 14.sp, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.width(12.dp))
        Text(
            title,
            fontSize = 15.sp,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Text("系列", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** 书架页：按系列去重显示收藏的漫画 */
@Composable
fun ShelfScreen(nav: (Any) -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var favs by remember { mutableStateOf<List<Issue>?>(null) }

    LaunchedEffect(Unit) { favs = Favorites.load(context) }

    Column(Modifier.fillMaxSize()) {
        Spacer(Modifier.height(WindowInsets.statusBars.asPaddingValues().calculateTopPadding()))
        Text(
            "书架",
            style = LargeTitle,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 8.dp),
        )
        when {
            favs == null -> LoadingState()
            favs!!.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("📚", fontSize = 40.sp)
                    Spacer(Modifier.height(10.dp))
                    Text("书架还是空的", color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "在漫画详情页点 ❤️ 就会出现在这里",
                        fontSize = 12.5.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            else -> {
                val bySeries = favs!!.groupBy { it.seriesTitle.ifEmpty { it.title } }
                LazyVerticalGrid(
                    columns = GridCells.Adaptive(150.dp),
                    contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 24.dp),
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    gridItems(bySeries.entries.toList(), key = { it.key }) { (series, issuesInSeries) ->
                        val first = issuesInSeries.first()
                        ShelfSeriesCard(series, issuesInSeries.size, first.coverUrl, first.seriesId, nav)
                    }
                }
            }
        }
    }
}

/** 书架里的一张系列卡 */
@Composable
fun ShelfSeriesCard(
    series: String,
    count: Int,
    coverUrl: String?,
    seriesId: String?,
    nav: (Any) -> Unit,
) {
    Column(Modifier.width(150.dp)) {
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(0.66f)
                .clip(RoundedCornerShape(14.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .clickableNoRipple { nav(SeriesNav(seriesId, series)) },
        ) {
            GlideImage(
                url = coverUrl,
                contentDescription = series,
                modifier = Modifier.fillMaxSize(),
            )
        }
        Text(
            series,
            fontSize = 13.sp,
            lineHeight = 17.sp,
            color = MaterialTheme.colorScheme.onSurface,
            fontWeight = FontWeight.SemiBold,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 6.dp),
        )
        Text(
            count.toString() + " 期",
            fontSize = 11.5.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 2.dp),
        )
    }
}

