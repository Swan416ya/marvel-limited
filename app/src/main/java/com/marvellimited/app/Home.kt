package com.marvellimited.app

import androidx.compose.foundation.background
import androidx.compose.foundation.Image
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
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.LightMode
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.RecentActors
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlin.random.Random

/** 主页：白底、居中 logo、banner、快捷入口、本周新刊、guide 流 */
@Composable
fun HomeScreen(nav: (Any) -> Unit, onOpenSettings: () -> Unit) {
    var home by remember { mutableStateOf<HomePageData?>(null) }
    var guides by remember { mutableStateOf<List<Guide>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var reload by remember { mutableStateOf(0) }
    val gridState = rememberLazyGridState()

    // 再点主页 tab 回顶部
    LaunchedEffect(Unit) {
        var last = HomeScrollBus.get()
        while (true) {
            if (HomeScrollBus.get() != last) {
                last = HomeScrollBus.get()
                gridState.animateScrollToItem(0)
            }
            delay(100)
        }
    }

    LaunchedEffect(reload) {
        error = null
        try {
            home = MarvelApi.homePage()
            guides = MarvelApi.guides()
        } catch (e: Exception) {
            error = e.message ?: "加载失败"
        }
    }

    LazyVerticalGrid(
        columns = GridCells.Adaptive(160.dp),
        contentPadding = PaddingValues(bottom = 24.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        state = gridState,
    ) {
        when {
            error != null -> item(span = { GridItemSpan(maxLineSpan) }) {
                ErrorState(error!!) { reload++ }
            }
            home == null || guides == null -> item(span = { GridItemSpan(maxLineSpan) }) {
                LoadingState()
            }
            else -> {
                // 顶部：居中 logo + 设置
                item(span = { GridItemSpan(maxLineSpan) }, key = "logo") {
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(top = 18.dp, start = 16.dp, end = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                            MarvelLogoText()
                        }
                        IconButton(onClick = onOpenSettings) {
                            Icon(
                                if (LocalThemeMode.current == ThemeMode.DARK) Icons.Filled.LightMode
                                else Icons.Filled.DarkMode,
                                contentDescription = "切换主题",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
                // banner：最近的官方 guide（横向滑动，图片做背景）
                item(span = { GridItemSpan(maxLineSpan) }, key = "banner") {
                    GuideBanner(guides!!.take(10), nav)
                }
                // 快捷按钮：随机一本 / 销量最高 / 大事件导读
                item(span = { GridItemSpan(maxLineSpan) }, key = "quick") {
                    QuickActions(nav, home!!, guides!!)
                }
                // 本周新刊（小封面）
                item(span = { GridItemSpan(maxLineSpan) }, key = "newh") {
                    SectionHeader("本周新刊", home!!.newThisWeek.size.toString() + " 本")
                }
                item(span = { GridItemSpan(maxLineSpan) }, key = "newrow") {
                    LazyRow(
                        contentPadding = PaddingValues(horizontal = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        items(home!!.newThisWeek, key = { it.id }) { issue ->
                            Column(Modifier.width(96.dp)) {
                                Box(
                                    Modifier
                                        .fillMaxWidth()
                                        .aspectRatio(0.66f)
                                        .clip(RoundedCornerShape(10.dp))
                                        .background(MaterialTheme.colorScheme.surfaceVariant)
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
                                    fontSize = 10.sp,
                                    lineHeight = 13.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 2,
                                    overflow = TextOverflow.Ellipsis,
                                    modifier = Modifier.padding(top = 4.dp),
                                )
                            }
                        }
                    }
                }
                // 无限 guide 流（每行一个）
                item(span = { GridItemSpan(maxLineSpan) }, key = "guideh") {
                    SectionHeader("阅读指南", guides!!.size.toString() + " 个")
                }
                items(guides!!, key = { "g" + it.id }, span = { GridItemSpan(maxLineSpan) }) { guide ->
                    GuideRowItem(guide, nav)
                }
            }
        }
    }
}

/** 居中的 MARVEL 官方矢量 logo */
@Composable
fun MarvelLogoText(height: androidx.compose.ui.unit.Dp = 22.dp) {
    Image(
        painter = androidx.compose.ui.res.painterResource(id = R.drawable.marvel_logo),
        contentDescription = "Marvel",
        modifier = Modifier.height(height),
    )
}

/** banner：guide 封面横向大卡 */
@Composable
fun GuideBanner(guides: List<Guide>, nav: (Any) -> Unit) {
    LazyRow(
        contentPadding = PaddingValues(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        items(guides, key = { it.id }) { guide ->
            Box(
                Modifier
                    .width(280.dp)
                    .aspectRatio(1.9f)
                    .clip(RoundedCornerShape(18.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .clickableNoRipple { nav(guide) },
            ) {
                GlideImage(
                    url = guide.coverUrl,
                    contentDescription = guide.title,
                    modifier = Modifier.fillMaxSize(),
                )
                Box(
                    Modifier
                        .fillMaxSize()
                        .background(
                            androidx.compose.ui.graphics.Brush.horizontalGradient(
                                0f to Color(0x99000000),
                                1f to Color.Transparent,
                            ),
                        ),
                )
                Column(
                    Modifier
                        .align(Alignment.BottomStart)
                        .padding(14.dp),
                ) {
                    Text(
                        guide.title,
                        color = Color.White,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }
}

/** 三个快捷按钮 */
@Composable
fun QuickActions(nav: (Any) -> Unit, home: HomePageData, guides: List<Guide>) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        listOf(
            "随机一本" to Icons.Filled.Casino,
            "热门系列" to Icons.Filled.LocalFireDepartment,
            "大事件导读" to Icons.Filled.RecentActors,
        ).forEach { (label, icon) ->
            Button(
                onClick = {
                    when (label) {
                        "随机一本" -> {
                            val pool = home.newThisWeek + home.bestSelling
                            if (pool.isNotEmpty()) {
                                nav(pool[Random.nextInt(pool.size)])
                            }
                        }
                        "热门系列" -> nav(PopularSeriesNav)
                        "大事件导读" -> nav(EventsNav)
                    }
                },
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant,
                    contentColor = MaterialTheme.colorScheme.onSurface,
                ),
                modifier = Modifier.weight(1f).height(46.dp),
            ) {
                Icon(icon, null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text(label, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)
            }
        }
    }
}

/** guide 流的一行 */
@Composable
fun GuideRowItem(guide: Guide, nav: (Any) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickableNoRipple { nav(guide) }
            .padding(horizontal = 16.dp, vertical = 7.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .width(64.dp)
                .aspectRatio(0.66f)
                .clip(RoundedCornerShape(8.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant),
        ) {
            GlideImage(
                url = guide.coverUrl,
                contentDescription = guide.title,
                modifier = Modifier.fillMaxSize(),
            )
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(
                guide.title,
                fontSize = 14.5.sp,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            if (guide.description.isNotEmpty()) {
                Text(
                    guide.description,
                    fontSize = 12.sp,
                    lineHeight = 16.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }
    }
}

@Composable
fun SectionHeader(title: String, subtitle: String) {
    Row(
        Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 16.dp, top = 18.dp, bottom = 8.dp),
        verticalAlignment = Alignment.Bottom,
    ) {
        Text(title, style = Title2, color = MaterialTheme.colorScheme.onSurface)
        Spacer(Modifier.width(8.dp))
        Text(subtitle, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
