package com.marvellimited.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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

/** 大事件列表：所有带 Complete Event 的 guide，按年份排序 */
@Composable
fun EventsScreen(stack: SnapshotStateList<Any?>) {
    var events by remember { mutableStateOf<List<Guide>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var reload by remember { mutableStateOf(0) }
    val nav: (Any) -> Unit = { stack.add(it) }
    val back: () -> Unit = { stack.removeAt(stack.lastIndex) }

    LaunchedEffect(reload) {
        error = null
        try {
            val all = MarvelApi.guides()
            events = all.filter { it.title.contains("Complete Event", ignoreCase = true) }
        } catch (e: Exception) {
            error = e.message ?: "加载失败"
        }
    }

    Column(Modifier.fillMaxSize()) {
        DetailTopBar("大事件导读", back)
        when {
            error != null -> ErrorState(error!!) { reload++ }
            events == null -> LoadingState()
            else -> LazyColumn(
                contentPadding = PaddingValues(bottom = 24.dp),
            ) {
                items(events!!, key = { it.id }) { guide ->
                    EventRow(guide, nav)
                }
            }
        }
    }
}

/** 一个大事件行：左侧 event 图 + 右侧名字 */
@Composable
fun EventRow(guide: Guide, nav: (Any) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clickableNoRipple { nav(guide) }
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(72.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center,
        ) {
            GlideImage(
                url = guide.coverUrl,
                contentDescription = guide.title,
                modifier = Modifier.fillMaxSize(),
            )
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(
                guide.title,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

