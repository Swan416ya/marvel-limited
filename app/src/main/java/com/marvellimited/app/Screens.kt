package com.marvellimited.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** 顶部返回栏（叠在渐变上） */
@Composable
fun DetailTopBar(title: String, onBack: () -> Unit, action: @Composable () -> Unit = {}) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(
                    0f to Color(0xCC0A0A0C),
                    1f to Color.Transparent,
                ),
            )
            .padding(horizontal = 4.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = onBack) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回", tint = Color.White)
        }
        Text(
            title,
            color = Color.White,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        action()
    }
}

/** 指南详情：按官方顺序的 issue 网格 */
@Composable
fun GuideDetailScreen(guide: Guide, stack: SnapshotStateList<Any?>) {
    var issues by remember { mutableStateOf<List<Issue>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var reload by remember { mutableStateOf(0) }
    val nav: (Any) -> Unit = { stack.add(it) }
    val back: () -> Unit = { stack.remove(guide) }

    LaunchedEffect(reload) {
        error = null
        try {
            issues = MarvelApi.guideIssues(guide.id)
        } catch (e: Exception) {
            error = e.message ?: "加载失败"
        }
    }

    Column(Modifier.fillMaxSize()) {
        DetailTopBar(guide.title, back)
        when {
            error != null -> ErrorState(error!!) { reload++ }
            issues == null -> LoadingState()
            else -> {
                Text(
                    issues!!.size.toString() + " 期 · 按官方阅读顺序",
                    fontSize = 13.sp,
                    color = Color(0x559A9AA3),
                    modifier = Modifier.padding(start = 20.dp, bottom = 4.dp),
                )
                LazyVerticalGrid(
                    columns = GridCells.Adaptive(100.dp),
                    contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 24.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    itemsIndexed(issues!!) { i, issue ->
                        IssueCell(issue, i + 1, nav)
                    }
                }
            }
        }
    }
}

/** 指南里的一期：封面 + 顺序角标 */
@Composable
fun IssueCell(issue: Issue, order: Int, nav: (Any) -> Unit) {
    Column(Modifier.width(100.dp)) {
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(0.66f)
                .clip(RoundedCornerShape(9.dp))
                .background(Color(0xFF16161A))
                .clickableNoRipple { nav(issue) },
        ) {
            if (issue.coverUrl != null) {
                GlideImage(
                    url = issue.coverUrl,
                    contentDescription = issue.title,
                    modifier = Modifier.fillMaxSize(),
                )
            }
            Text(
                order.toString(),
                color = Color.White,
                fontSize = 10.5.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier
                    .padding(5.dp)
                    .background(Color(0xB8000000), RoundedCornerShape(100))
                    .padding(horizontal = 6.dp, vertical = 1.dp),
            )
        }
        Text(
            issue.title,
            fontSize = 11.sp,
            color = Color(0xCC9A9AA3),
            lineHeight = 14.sp,
            fontWeight = FontWeight.Medium,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 5.dp),
        )
    }
}

/** Issue 详情 */
@Composable
fun IssueDetailScreen(issue: Issue, stack: SnapshotStateList<Any?>) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var isFav by remember { mutableStateOf(Favorites.has(context, issue.id)) }
    var showAddToList by remember { mutableStateOf(false) }
    val nav: (Any) -> Unit = { stack.add(it) }
    val back: () -> Unit = { stack.remove(issue) }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
    ) {
        DetailTopBar(
            issue.title,
            back,
            action = {
                IconButton(onClick = {
                    isFav = Favorites.toggle(context, issue)
                }) {
                    Icon(
                        if (isFav) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                        "收藏",
                        tint = if (isFav) Color(0xFFFF375F) else Color.White,
                    )
                }
            },
        )
        Row(Modifier.padding(horizontal = 20.dp)) {
            Box(
                Modifier
                    .width(172.dp)
                    .aspectRatio(0.66f)
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color(0xFF16161A)),
            ) {
                if (issue.coverUrl != null) {
                    GlideImage(
                        url = issue.coverUrl,
                        contentDescription = issue.title,
                        modifier = Modifier.fillMaxSize(),
                    )
                }
            }
            Spacer(Modifier.width(16.dp))
            Column(Modifier.weight(1f)) {
                Text(issue.title, style = Title2, color = Color.White)
                if (issue.releaseDate.isNotEmpty()) {
                    Text(
                        issue.releaseDate,
                        fontSize = 13.sp,
                        color = Color(0x809A9AA3),
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
                if (issue.creators.isNotEmpty()) {
                    Text(
                        issue.creators.take(5).joinToString(" · "),
                        fontSize = 13.sp,
                        color = Color(0x809A9AA3),
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
                if (issue.seriesTitle.isNotEmpty()) {
                    TextButton(
                        onClick = {
                            nav(SeriesNav(issue.seriesId, issue.seriesTitle))
                        },
                        contentPadding = PaddingValues(0.dp),
                    ) {
                        Text("查看系列 →", fontSize = 13.5.sp)
                    }
                }
            }
        }
        if (issue.description.isNotEmpty()) {
            Text(
                issue.description,
                fontSize = 14.sp,
                lineHeight = 22.sp,
                color = Color(0x809A9AA3),
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 14.dp),
            )
        }
        Column(Modifier.padding(horizontal = 20.dp)) {
            OutlinedButton(
                onClick = { showAddToList = true },
                modifier = Modifier.fillMaxWidth().height(50.dp),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text("加入书单", fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(10.dp))
            Button(
                onClick = { /* TODO: 导入 CBZ */ },
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                ),
                modifier = Modifier.fillMaxWidth().height(50.dp),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text("导入本地文件 (CBZ/ZIP)", fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(10.dp))
            OutlinedButton(
                onClick = {
                    val q = issue.seriesTitle + " #" + issue.issueNumber
                    val intent = android.content.Intent(
                        android.content.Intent.ACTION_VIEW,
                        android.net.Uri.parse(
                            "https://getcomics.io/?s=" + java.net.URLEncoder.encode(q, "UTF-8")),
                    )
                    context.startActivity(intent)
                },
                modifier = Modifier.fillMaxWidth().height(50.dp),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text("去 GetComics 下载", fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(24.dp))
        }
    }

    if (showAddToList) {
        var lists by remember { mutableStateOf(ReadingLists.load(context)) }
        AlertDialog(
            onDismissRequest = { showAddToList = false },
            title = { Text("加入书单") },
            text = {
                Column {
                    if (lists.isEmpty()) {
                        Text("还没有书单，先去书单页新建一个", color = Color(0x809A9AA3))
                    } else {
                        lists.forEach { l ->
                            TextButton(
                                onClick = {
                                    val updated = l.copy(items = l.items + issue)
                                    ReadingLists.save(context, updated)
                                    showAddToList = false
                                },
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Text(l.title + " · " + l.items.size + " 期")
                            }
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showAddToList = false }) { Text("取消") }
            },
        )
    }
}

/** 系列页：官网 bifrost 数据 + fandom wiki 补充 */
@Composable
fun SeriesScreen(dest: SeriesNav, stack: SnapshotStateList<Any?>) {
    var issues by remember { mutableStateOf<List<Issue>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var reload by remember { mutableStateOf(0) }
    val nav: (Any) -> Unit = { stack.add(it) }
    val back: () -> Unit = { stack.remove(dest) }

    LaunchedEffect(reload) {
        error = null
        try {
            issues = if (dest.seriesId != null) {
                MarvelApi.seriesIssues(dest.seriesId)
            } else {
                val nums = MarvelApi.fandomSeriesIssueNumbers(dest.fandomName ?: dest.title)
                nums.take(100).mapNotNull { num ->
                    MarvelApi.fandomIssue(dest.fandomName ?: dest.title, num)
                }
            }
        } catch (e: Exception) {
            error = e.message ?: "加载失败"
        }
    }

    Column(Modifier.fillMaxSize()) {
        DetailTopBar(dest.title, back)
        when {
            error != null -> ErrorState(error!!) { reload++ }
            issues == null -> LoadingState()
            else -> LazyColumn(
                contentPadding = PaddingValues(start = 8.dp, end = 8.dp, bottom = 24.dp),
            ) {
                items(issues!!, key = { it.id }) { issue ->
                    IssueRow(issue, nav)
                }
            }
        }
    }
}

/** 系列页里的一行 */
@Composable
fun IssueRow(issue: Issue, nav: (Any) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickableNoRipple { nav(issue) }
            .padding(horizontal = 8.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .width(50.dp)
                .aspectRatio(0.66f)
                .clip(RoundedCornerShape(6.dp))
                .background(Color(0xFF16161A)),
        ) {
            if (issue.coverUrl != null) {
                GlideImage(
                    url = issue.coverUrl,
                    contentDescription = issue.title,
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(
                issue.title,
                fontSize = 14.5.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color(0xFFEDEDF0),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                (if (issue.isWiki) "Wiki 补充 · " else "") +
                    (if (issue.releaseDate.isNotEmpty()) issue.releaseDate else "—"),
                fontSize = 12.sp,
                color = Color(0x559A9AA3),
                maxLines = 1,
            )
        }
    }
}
