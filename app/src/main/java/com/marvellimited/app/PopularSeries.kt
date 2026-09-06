package com.marvellimited.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** 热门系列页：官网精选系列网格 */
@Composable
fun PopularSeriesScreen(stack: SnapshotStateList<Any>) {
    var series by remember { mutableStateOf<List<FeaturedSeries>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var reload by remember { mutableStateOf(0) }
    val nav: (Any) -> Unit = { stack.add(it) }
    val back: () -> Unit = { stack.removeAt(stack.lastIndex) }

    LaunchedEffect(reload) {
        error = null
        try {
            series = MarvelApi.featuredSeries()
        } catch (e: Exception) {
            error = e.message ?: "加载失败"
        }
    }

    Column(Modifier.fillMaxSize()) {
        DetailTopBar("热门系列", back)
        when {
            error != null -> ErrorState(error!!) { reload++ }
            series == null -> LoadingState()
            else -> LazyVerticalGrid(
                columns = GridCells.Adaptive(110.dp),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 24.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                items(series!!, key = { it.id }) { s ->
                    SeriesCard(s, nav)
                }
            }
        }
    }
}

/** 系列卡：标准漫画封面比例 */
@Composable
fun SeriesCard(s: FeaturedSeries, nav: (Any) -> Unit) {
    Column(Modifier.width(110.dp)) {
        Box(
            Modifier
                .fillMaxWidth()
                .aspectRatio(0.66f)
                .clip(RoundedCornerShape(10.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .clickableNoRipple { nav(SeriesNav(s.id, s.title)) },
        ) {
            GlideImage(
                url = s.coverUrl,
                contentDescription = s.title,
                modifier = Modifier.fillMaxSize(),
            )
        }
        Text(
            s.title,
            fontSize = 12.sp,
            lineHeight = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 5.dp),
        )
        if (s.years.isNotEmpty()) {
            Text(
                s.years,
                fontSize = 10.5.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 1.dp),
            )
        }
    }
}
