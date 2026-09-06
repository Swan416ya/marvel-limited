package com.marvellimited.app

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Search
import androidx.activity.compose.BackHandler
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** 应用根：底部三 tab（首页/收藏/搜索）+ 叠加导航栈 */
@Composable
fun MarvelApp() {
    var tab by remember { mutableStateOf(0) }
    val stack = remember { mutableStateListOf<Any?>() }

    val nav: (Any) -> Unit = { dest -> stack.add(dest) }

    val pages = listOf(
        "主页" to Icons.Filled.Home,
        "书架" to Icons.Filled.Favorite,
        "书单" to Icons.Filled.Search,
    )

    Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Scaffold(
            containerColor = Color.Transparent,
            bottomBar = {
                NavigationBar(
                    containerColor = Color(0xCC0A0A0C),
                    contentColor = Color.White,
                    tonalElevation = 0.dp,
                ) {
                    pages.forEachIndexed { i, (label, icon) ->
                        NavigationBarItem(
                            selected = tab == i,
                            onClick = { tab = i },
                            icon = {
                                Icon(
                                    icon, null,
                                    tint = if (tab == i) MaterialTheme.colorScheme.primary else Color(0x809A9AA3),
                                )
                            },
                            label = { Text(label, fontSize = 11.sp) },
                            colors = NavigationBarItemDefaults.colors(
                                indicatorColor = Color(0x2BED1D24),
                            ),
                        )
                    }
                }
            },
        ) { padding ->
            Box(Modifier.padding(padding)) {
                when (tab) {
                    0 -> HomeScreen(nav)
                    1 -> ShelfScreen(nav)
                    2 -> ReadingListsScreen(nav)
                }
            }
        }

        // 叠加层导航栈（详情页们）
        stack.forEachIndexed { index, dest ->
            key(index) {
                OverlayHost(dest, index, stack)
            }
        }
    }
}

/** 叠加层：滑入动画 + 返回键支持 */
@Composable
fun OverlayHost(dest: Any?, index: Int, stack: SnapshotStateList<Any?>) {
    val visible = remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible.value = true }
    val offsetX by animateFloatAsState(
        targetValue = if (visible.value) 0f else 1f,
        animationSpec = spring(dampingRatio = 1f, stiffness = 380f),
        label = "slide",
    )

    BackHandler(enabled = index >= 0) {
        visible.value = false
        stack.removeAt(index)
    }

    Box(
        Modifier
            .fillMaxSize()
            .graphicsLayer { translationX = offsetX * size.width }
            .background(MaterialTheme.colorScheme.background),
    ) {
        when (dest) {
            is Guide -> GuideDetailScreen(dest, stack)
            is Issue -> IssueDetailScreen(dest, stack)
            is SeriesNav -> SeriesScreen(dest, stack)
            is HomeIssue -> IssueDetailScreen(issueFromHomeIssue(dest), stack)
            is ReadingList -> ReadingListDetailScreen(dest, stack)
        }
    }
}

/** 系列导航目的地 */
data class SeriesNav(val seriesId: String?, val title: String, val fandomName: String? = null)

/** 官网首页条目转 Issue（进入详情页用） */
fun issueFromHomeIssue(h: HomeIssue): Issue = Issue(
    id = h.id,
    title = h.title,
    seriesTitle = Parse.seriesOf(h.title),
    issueNumber = Parse.numberOf(h.title),
    releaseDate = h.releaseDate,
    coverUrl = h.coverUrl,
)

/** 主页：官网式 banner + 栏目 */
@Composable
fun HomeScreen(nav: (Any) -> Unit) {
    var home by remember { mutableStateOf<HomePageData?>(null) }
    var guides by remember { mutableStateOf<List<Guide>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var reload by remember { mutableStateOf(0) }

    LaunchedEffect(reload) {
        error = null
        try {
            home = MarvelApi.homePage()
            guides = MarvelApi.guides()
        } catch (e: Exception) {
            error = e.message ?: "加载失败"
        }
    }
    val listState = androidx.compose.foundation.lazy.grid.rememberLazyGridState()

    LazyVerticalGrid(
        columns = GridCells.Adaptive(150.dp),
        contentPadding = PaddingValues(bottom = 24.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
        modifier = Modifier.fillMaxSize(),
        state = listState,
    ) {
        when {
            error != null -> item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(maxLineSpan) }) {
                ErrorState(error!!) { reload++ }
            }
            home == null || guides == null -> item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(maxLineSpan) }) {
                LoadingState()
            }
            else -> {
                // 大 banner：本周新刊
                item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(maxLineSpan) }, key = "banner") {
                    HomeBanner(home!!.newThisWeek, nav)
                }
                // 指南栏（最近更新的大事件专题）
                item(span = { androidx.compose.foundation.lazy.grid.GridItemSpan(maxLineSpan) }, key = "guides-h") {
                    SectionHeader("大事件指南", guides!!.size.toString() + " 个专题")
                }
                items(guides!!.take(12), key = { "g" + it.id }) { guide ->
                    GuideCard(guide, nav)
                }
            }
        }
    }
}

/** 本周新刊 banner：横向滑动大卡 */
@Composable
fun HomeBanner(issues: List<HomeIssue>, nav: (Any) -> Unit) {
    Column {
        Text(
            "Marvel",
            style = LargeTitle,
            color = Color.White,
            modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 10.dp),
        )
        Text(
            "本周新刊 " + issues.size + " 本 · 滑动查看",
            fontSize = 13.sp,
            color = Color(0x559A9AA3),
            modifier = Modifier.padding(start = 20.dp, end = 20.dp, bottom = 10.dp),
        )
        LazyRow(
            contentPadding = PaddingValues(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            items(issues, key = { it.id }) { issue ->
                Column(Modifier.width(150.dp)) {
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .aspectRatio(0.66f)
                            .clip(RoundedCornerShape(14.dp))
                            .background(Color(0xFF16161A))
                            .clickableNoRipple { nav(issue) },
                    ) {
                        GlideImage(
                            url = issue.coverUrl,
                            contentDescription = issue.title,
                            modifier = Modifier.fillMaxSize(),
                        )
                    }
                    Text(
                        issue.title,
                        fontSize = 11.5.sp,
                        lineHeight = 15.sp,
                        color = Color(0xCC9A9AA3),
                        fontWeight = FontWeight.Medium,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
            }
        }
    }
}

@Composable
fun SectionHeader(title: String, subtitle: String) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(start = 20.dp, end = 20.dp, top = 22.dp, bottom = 10.dp),
        verticalAlignment = Alignment.Bottom,
    ) {
        Text(title, style = Title2, color = Color.White)
        Spacer(Modifier.width(8.dp))
        Text(subtitle, fontSize = 12.sp, color = Color(0x559A9AA3))
    }
}

@Composable
fun GuideCard(guide: Guide, nav: (Any) -> Unit) {
    var pressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.96f else 1f,
        animationSpec = spring(dampingRatio = 1f, stiffness = 800f),
    )
    Box(
        Modifier
            .aspectRatio(0.66f)
            .scale(scale)
            .clip(RoundedCornerShape(14.dp))
            .background(Color(0xFF16161A))
            .pointerInput(guide.id) {
                awaitEachGesture {
                    val down = awaitFirstDown()
                    pressed = true
                    val up = waitForUpOrCancellation()
                    pressed = false
                    if (up != null) nav(guide)
                }
            },
    ) {
        if (guide.coverUrl != null) {
            GlideImage(
                url = guide.coverUrl,
                contentDescription = guide.title,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        }
        Box(
            Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        0.45f to Color.Transparent,
                        1f to Color(0xE6000000),
                    ),
                ),
        )
        Text(
            guide.title,
            color = Color.White,
            fontSize = 13.5.sp,
            lineHeight = 17.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 3,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(12.dp),
        )
    }
}

/** 加载/错误状态 */
@Composable
fun LoadingState() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
    }
}

@Composable
fun ErrorState(msg: String, onRetry: () -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(msg, color = Color(0x809A9AA3))
            Spacer(Modifier.height(14.dp))
            Button(
                onClick = onRetry,
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                ),
            ) {
                Text("重试")
            }
        }
    }
}
