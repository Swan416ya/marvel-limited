package com.marvellimited.app

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** 书单详情：顺序列表，可移除条目 */
@Composable
fun ReadingListDetailScreen(list: ReadingList, stack: SnapshotStateList<Any?>) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var current by remember { mutableStateOf(list) }
    val nav: (Any) -> Unit = { stack.add(it) }
    val back: () -> Unit = { stack.remove(list) }

    Column(Modifier.fillMaxSize()) {
        DetailTopBar(
            current.title,
            back,
            action = {
                IconButton(onClick = {
                    ReadingLists.delete(context, current.id)
                    stack.remove(list)
                }) {
                    Icon(Icons.Filled.Delete, "删除书单", tint = Color(0x809A9AA3))
                }
            },
        )
        if (current.items.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("书单是空的，去详情页底部加入书单", color = Color(0x559A9AA3))
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(start = 8.dp, end = 8.dp, bottom = 24.dp),
            ) {
                items(current.items, key = { it.id }) { issue ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clickableNoRipple { nav(issue) }
                            .padding(horizontal = 8.dp, vertical = 5.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        IssueRow(issue, nav)
                    }
                }
            }
        }
    }
}
