package com.marvellimited.app

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.items as gridItems
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.background
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.launch

/** 搜索页 */
@OptIn(FlowPreview::class)
@Composable
fun SearchScreen(nav: (Any) -> Unit) {
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<String>?>(null) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val queryFlow = remember { MutableStateFlow("") }

    LaunchedEffect(Unit) {
        queryFlow.debounce(350).collect { q ->
            if (q.isBlank()) {
                results = null
                loading = false
            } else {
                loading = true
                error = null
                try {
                    results = MarvelApi.searchSeries(q.trim())
                } catch (e: Exception) {
                    error = e.message
                }
                loading = false
            }
        }
    }

    Column(Modifier.fillMaxSize()) {
        OutlinedTextField(
            value = query,
            onValueChange = {
                query = it
                queryFlow.value = it
            },
            placeholder = { Text("搜索系列，如 Amazing Spider-Man", color = Color(0x559A9AA3)) },
            leadingIcon = { Icon(Icons.Filled.Search, null, tint = Color(0x809A9AA3)) },
            singleLine = true,
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = MaterialTheme.colorScheme.primary,
                unfocusedBorderColor = Color(0x1AFFFFFF),
                focusedContainerColor = Color(0x14FFFFFF),
                unfocusedContainerColor = Color(0x14FFFFFF),
            ),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
        )

        when {
            loading -> LoadingState()
            error != null -> ErrorState(error!!) { queryFlow.value = query }
            results == null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("输入系列名开始搜索", color = Color(0x559A9AA3))
            }
            results!!.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("没有找到相关系列", color = Color(0x559A9AA3))
            }
            else -> LazyColumn(
                contentPadding = PaddingValues(start = 8.dp, end = 8.dp, bottom = 24.dp),
            ) {
                items(results!!, key = { it }) { title ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clickable { nav(SeriesNav(null, title, title)) }
                            .padding(horizontal = 12.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            title,
                            fontSize = 15.sp,
                            color = Color(0xFFEDEDF0),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f),
                        )
                        Text(
                            "Vol",
                            fontSize = 12.sp,
                            color = Color(0x559A9AA3),
                        )
                    }
                }
            }
        }
    }
}

/** 书架页：按系列去重显示收藏的漫画 */
@Composable
fun ShelfScreen(nav: (Any) -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var favs by remember { mutableStateOf<List<Issue>?>(null) }

    LaunchedEffect(Unit) {
        favs = Favorites.load(context)
    }

    Column(Modifier.fillMaxSize()) {
        Text(
            "收藏",
            style = LargeTitle,
            color = Color.White,
            modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 12.dp),
        )
        when {
            favs == null -> LoadingState()
            favs!!.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("📚", fontSize = 40.sp)
                    Spacer(Modifier.height(10.dp))
                    Text("书架还是空的", color = Color(0x809A9AA3))
                    Spacer(Modifier.height(4.dp))
                    Text("在漫画详情页点 ❤️ 就会出现在这里", fontSize = 12.5.sp, color = Color(0x559A9AA3))
                }
            }
            else -> {
                // 按系列分组，每个系列一张卡（用该系列第一期的封面）
                val bySeries = favs!!.groupBy { it.seriesTitle.ifEmpty { it.title } }
                androidx.compose.foundation.lazy.grid.LazyVerticalGrid(
                    columns = androidx.compose.foundation.lazy.grid.GridCells.Adaptive(150.dp),
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
                .background(Color(0xFF16161A))
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
            color = Color(0xFFEDEDF0),
            fontWeight = FontWeight.SemiBold,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 6.dp),
        )
        Text(
            count.toString() + " 期",
            fontSize = 11.5.sp,
            color = Color(0x559A9AA3),
            modifier = Modifier.padding(top = 2.dp),
        )
    }
}
