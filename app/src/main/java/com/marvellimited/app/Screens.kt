package com.marvellimited.app

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
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
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** 顶部返回栏（适配状态栏） */
@Composable
fun DetailTopBar(title: String, onBack: () -> Unit, action: @Composable () -> Unit = {}) {
    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    Column {
        Spacer(Modifier.height(top))
        Row(
            Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.background)
                .padding(horizontal = 4.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回", tint = MaterialTheme.colorScheme.onBackground)
            }
            Text(
                title,
                color = MaterialTheme.colorScheme.onBackground,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            action()
        }
    }
}

/** 指南详情：按官方顺序的 issue 网格 */
@Composable
fun GuideDetailScreen(guide: Guide, stack: SnapshotStateList<Any>) {
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
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
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

/** 指南里的一期 */
@Composable
fun IssueCell(issue: Issue, order: Int, nav: (Any) -> Unit) {
    Column(Modifier.width(100.dp)) {
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(0.66f)
                .clip(RoundedCornerShape(9.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
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
                    .background(Color(0xB3000000), RoundedCornerShape(100))
                    .padding(horizontal = 6.dp, vertical = 1.dp),
            )
        }
        Text(
            issue.title,
            fontSize = 11.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
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
fun IssueDetailScreen(issue: Issue, stack: SnapshotStateList<Any>) {
    val context = LocalContext.current
    val pickFile = rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        if (uri != null) {
            android.widget.Toast.makeText(
                context,
                "已选择文件：读取功能开发中",
                android.widget.Toast.LENGTH_SHORT,
            ).show()
        }
    }
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
                        tint = if (isFav) MarvelRed else MaterialTheme.colorScheme.onBackground,
                    )
                }
            },
        )
        Row(Modifier.padding(horizontal = 20.dp)) {
            Box(
                Modifier
                    .width(160.dp)
                    .aspectRatio(0.66f)
                    .clip(RoundedCornerShape(12.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant),
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
                Text(issue.title, style = Title2, color = MaterialTheme.colorScheme.onSurface)
                if (issue.releaseDate.isNotEmpty()) {
                    Text(
                        issue.releaseDate,
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
                if (issue.creators.isNotEmpty()) {
                    Text(
                        issue.creators.take(5).joinToString(" · "),
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
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
                color = MaterialTheme.colorScheme.onSurfaceVariant,
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
                onClick = {
                    pickFile.launch(arrayOf("application/x-cbz", "application/zip", "application/octet-stream", "image/*"))
                },
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ),
                modifier = Modifier.fillMaxWidth().height(50.dp),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text("导入本地文件 (CBZ/ZIP)", fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(10.dp))
            OutlinedButton(
                onClick = {
                    // 标题 + 年份，去掉括号等干扰字符
                    val year = Regex("\\(\\d{4})\\)").find(issue.title)?.groupValues?.get(1) ?: ""
                    val q = (issue.seriesTitle.ifEmpty { Parse.seriesOf(issue.title) } + " " + year).trim()
                    val url = "https://getcomics.org/?s=" + java.net.URLEncoder.encode(q, "UTF-8").replace("+", "%20")
                    try {
                        context.startActivity(
                            Intent(Intent.ACTION_VIEW, Uri.parse(url)),
                        )
                    } catch (e: Exception) {
                        android.widget.Toast.makeText(context, "没有可打开链接的应用", android.widget.Toast.LENGTH_SHORT).show()
                    }
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
        val lists = ReadingLists.load(context)
        AlertDialog(
            onDismissRequest = { showAddToList = false },
            title = { Text("加入书单") },
            text = {
                Column {
                    if (lists.isEmpty()) {
                        Text("还没有书单，先去书单页新建一个", color = MaterialTheme.colorScheme.onSurfaceVariant)
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

/** 系列页：优先 fandom（可靠），seriesId 保留备用 */
@Composable
fun SeriesScreen(dest: SeriesNav, stack: SnapshotStateList<Any>) {
    var issues by remember { mutableStateOf<List<Issue>?>(null) }
    var seriesHeader by remember { mutableStateOf<Issue?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var reload by remember { mutableStateOf(0) }
    val nav: (Any) -> Unit = { stack.add(it) }
    val back: () -> Unit = { stack.remove(dest) }

    LaunchedEffect(reload) {
        error = null
        try {
            // 双数据源：bifrost（官方目录）优先，fandom wiki 兜底（补下架期数）
            issues = if (dest.seriesId != null) {
                MarvelApi.seriesIssues(dest.seriesId!!)
            } else {
                MarvelApi.seriesIssuesByFandom(dest.title)
            }
            seriesHeader = issues?.firstOrNull { it.coverUrl != null }
        } catch (e: Exception) {
            error = e.message ?: "加载失败"
        }
    }

    Column(Modifier.fillMaxSize()) {
        DetailTopBar(dest.title, back)
        when {
            error != null -> ErrorState(error!!) { reload++ }
            issues == null -> LoadingState()
            else -> {
                // 头部：系列封面横幅 + 名称 + 期数统计
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(180.dp),
                ) {
                    if (seriesHeader?.coverUrl != null) {
                        GlideImage(
                            url = seriesHeader!!.coverUrl,
                            contentDescription = dest.title,
                            modifier = Modifier.fillMaxSize(),
                        )
                        Box(
                            Modifier
                                .fillMaxSize()
                                .background(
                                    Brush.verticalGradient(
                                        0f to Color.Transparent,
                                        1f to MaterialTheme.colorScheme.background,
                                    ),
                                ),
                        )
                    }
                    Column(Modifier.align(Alignment.BottomStart).padding(20.dp, bottom = 12.dp)) {
                        Text(dest.title, style = Title2, color = MaterialTheme.colorScheme.onSurface)
                        Text(
                            issues!!.size.toString() + " 期",
                            fontSize = 13.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                LazyColumn(
                    contentPadding = PaddingValues(start = 8.dp, end = 8.dp, bottom = 24.dp),
                ) {
                    items(issues!!, key = { it.id }) { issue ->
                        IssueRow(issue, nav)
                    }
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
                .background(MaterialTheme.colorScheme.surfaceVariant),
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
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                (if (issue.isWiki) "Wiki · " else "") +
                    (if (issue.releaseDate.isNotEmpty()) issue.releaseDate else "—"),
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
            )
        }
    }
}
