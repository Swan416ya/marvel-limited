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
fun EventsScreen(stack: SnapshotStateList<Any>) {
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
            else -> {
                val sorted = events!!.sortedBy { eventYear(it) }
                LazyColumn(contentPadding = PaddingValues(bottom = 24.dp)) {
                    items(sorted, key = { it.id }) { guide ->
                        EventRow(guide, nav)
                    }
                }
            }
        }
    }
}

/** event 按时间排序（描述中出现的最早年份） */
private fun eventYear(guide: Guide): Int {
    val years = Regex("\\b(19|20)\\d{2}\\b").findAll(guide.description).mapNotNull { it.value.toIntOrNull() }.toList()
    return years.minOrNull() ?: 9999
}

/** 事件 logo 映射：guide 标题 -> fandom wiki 页面名 */
object EventLogos {
    private val pages = mapOf(
        "Civil War: The Complete Event" to "Civil War (Event)",
        "Secret Invasion: The Complete Event" to "Secret Invasion (Event)",
        "Infinity: The Complete Event" to "Infinity (Event)",
        "House of M: The Complete Event" to "House of M (Event)",
        "Age of Ultron: The Complete Event" to "Age of Ultron (Event)",
        "World War Hulk: The Complete Event" to "World War Hulk",
        "Empyre: The Complete Event" to "Empyre (Event)",
        "Spider-Verse: The Complete Event" to "Spider-Verse",
        "Age of Apocalypse: The Complete Event" to "Age of Apocalypse (Event)",
        "X-Men: Onslaught—The Complete Event" to "Onslaught (Event)",
        "Sins of Sinister: The Complete Event" to "Sins of Sinister",
        "Age of X-Man: The Complete Event" to "Age of X-Man (Event)",
        "Spider-Geddon: The Complete Event" to "Spider-Geddon",
        "Spider-Island: The Complete Event" to "Spider-Island (Event)",
        "Avengers vs. X-Men: The Complete Event" to "Avengers vs. X-Men (Event)",
        "X-Men: Battle of the Atom Complete Event" to "Battle of the Atom",
    )

    fun forGuide(guideTitle: String): String? = pages[guideTitle]
}

/** 一个大事件行：左侧 event logo + 右侧名字 */
@Composable
fun EventRow(guide: Guide, nav: (Any) -> Unit) {
    var logoUrl by remember(guide.id) { mutableStateOf<String?>(null) }
    LaunchedEffect(guide.id) {
        EventLogos.forGuide(guide.title)?.let { page ->
            logoUrl = MarvelApi.fandomPageImage(page)
        }
    }
    Row(
        Modifier
            .fillMaxWidth()
            .clickableNoRipple { nav(guide) }
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .width(110.dp)
                .aspectRatio(1.6f)
                .clip(RoundedCornerShape(10.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center,
        ) {
            GlideImage(
                url = logoUrl ?: guide.coverUrl,
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
