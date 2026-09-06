package com.marvellimited.app

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.MenuBook
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

/** 主页回顶部事件总线（简单计数器） */
val HomeScrollBus = java.util.concurrent.atomic.AtomicInteger(0)

/** 应用根：底部导航 + 叠加导航栈 + 主题切换 */
@Composable
fun MarvelApp(onThemeChange: (ThemeMode) -> Unit) {
    var tab by remember { mutableStateOf(0) }
    val stack = remember { mutableStateListOf<Any?>() }
    var showSettings by remember { mutableStateOf(false) }

    val nav: (Any) -> Unit = { dest -> stack.add(dest) }

    val pages = listOf(
        "主页" to Icons.Filled.Home,
        "书架" to Icons.Filled.MenuBook,
        "搜索" to Icons.Filled.Search,
    )

    Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Scaffold(
            containerColor = Color.Transparent,
            bottomBar = {
                NavigationBar(
                    containerColor = MaterialTheme.colorScheme.surface,
                    contentColor = MaterialTheme.colorScheme.onSurface,
                    tonalElevation = 0.dp,
                ) {
                    pages.forEachIndexed { i, (label, icon) ->
                        NavigationBarItem(
                            selected = tab == i,
                            onClick = {
                                if (tab == i) {
                                    HomeScrollBus.incrementAndGet()
                                } else {
                                    tab = i
                                }
                            },
                            icon = {
                                Icon(
                                    icon, null,
                                    tint = if (tab == i) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            },
                            label = { Text(label, fontSize = 11.sp) },
                            colors = NavigationBarItemDefaults.colors(
                                indicatorColor = MaterialTheme.colorScheme.surfaceVariant,
                            ),
                        )
                    }
                }
            },
        ) { padding ->
            Box(Modifier.padding(padding)) {
                when (tab) {
                    0 -> HomeScreen(nav, onOpenSettings = { showSettings = true })
                    1 -> ShelfScreen(nav)
                    2 -> SearchScreen(nav)
                }
            }
        }

        stack.forEachIndexed { index, dest ->
            key(index) {
                OverlayHost(dest, index, stack, nav)
            }
        }

        if (showSettings) {
            SettingsSheet(onDismiss = { showSettings = false }, onThemeChange = onThemeChange)
        }
    }
}

/** 叠加层：滑入动画 + 返回键支持 */
@Composable
fun OverlayHost(dest: Any?, index: Int, stack: SnapshotStateList<Any?>, nav: (Any) -> Unit) {
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
            is EventsNav -> EventsScreen(stack)
            is SearchQueryNav -> SearchScreen(nav, initialQuery = dest.query)
        }
    }
}

/** 系列导航目的地 */
data class SeriesNav(val seriesId: String?, val title: String, val fandomName: String? = null)

/** 大事件列表导航 */
data object EventsNav

/** 带初始查询进搜索 */
data class SearchQueryNav(val query: String)

/** 官网首页条目转 Issue */
fun issueFromHomeIssue(h: HomeIssue): Issue = Issue(
    id = h.id,
    title = h.title,
    seriesTitle = Parse.seriesOf(h.title),
    issueNumber = Parse.numberOf(h.title),
    releaseDate = h.releaseDate,
    coverUrl = h.coverUrl,
)

/** 主题设置底部弹层 */
@Composable
fun SettingsSheet(onDismiss: () -> Unit, onThemeChange: (ThemeMode) -> Unit) {
    val mode = LocalThemeMode.current
    androidx.compose.material3.AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("外观") },
        text = {
            Column {
                listOf(
                    "跟随系统" to ThemeMode.SYSTEM,
                    "浅色" to ThemeMode.LIGHT,
                    "深色" to ThemeMode.DARK,
                ).forEach { (label, m) ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clickable { onThemeChange(m) }
                            .padding(vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        RadioButton(selected = mode == m, onClick = { onThemeChange(m) })
                        Text(label, modifier = Modifier.padding(start = 6.dp))
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("完成") }
        },
    )
}
