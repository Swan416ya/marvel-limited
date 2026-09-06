package com.marvellimited.app

import android.content.Context
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

/** 一条书单 */
data class ReadingList(
    val id: String,
    val title: String,
    val items: List<Issue> = emptyList(),
    val createdAt: Long = System.currentTimeMillis(),
)

/** 书单存储：JSON 文件 */
object ReadingLists {
    private val gson = Gson()
    private var cache: MutableList<ReadingList>? = null

    private fun file(ctx: Context) = java.io.File(ctx.filesDir, "reading_lists.json")

    @Synchronized
    fun load(ctx: Context): List<ReadingList> {
        cache?.let { return it }
        val f = file(ctx)
        cache = if (f.exists()) {
            try {
                gson.fromJson<List<ReadingList>>(f.readText(), object : TypeToken<List<ReadingList>>() {}.type)
                    .toMutableList()
            } catch (e: Exception) {
                mutableListOf()
            }
        } else mutableListOf()
        return cache!!
    }

    @Synchronized
    fun save(ctx: Context, list: ReadingList) {
        val all = load(ctx).toMutableList()
        val idx = all.indexOfFirst { it.id == list.id }
        if (idx >= 0) all[idx] = list else all.add(list)
        cache = all
        file(ctx).writeText(gson.toJson(all))
    }

    @Synchronized
    fun delete(ctx: Context, id: String) {
        val all = load(ctx).toMutableList()
        all.removeAll { it.id == id }
        cache = all
        file(ctx).writeText(gson.toJson(all))
    }
}

/** 第三个 tab：书单 */
@Composable
fun ReadingListsScreen(nav: (Any) -> Unit) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var lists by remember { mutableStateOf<List<ReadingList>?>(null) }
    var showCreate by remember { mutableStateOf(false) }
    var newName by remember { mutableStateOf("") }

    LaunchedEffect(Unit) { lists = ReadingLists.load(context) }

    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(start = 20.dp, end = 12.dp, top = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("书单", style = LargeTitle, color = Color.White, modifier = Modifier.weight(1f))
            IconButton(onClick = { showCreate = true; newName = "" }) {
                Icon(Icons.Filled.Add, "新建书单", tint = Color(0xFF9A9AA3))
            }
        }
        Text(
            "把想一口气看完的内容攒到一起，比如“全部内战”",
            fontSize = 13.sp,
            color = Color(0x559A9AA3),
            modifier = Modifier.padding(start = 20.dp, end = 20.dp, bottom = 8.dp),
        )
        when {
            lists == null -> LoadingState()
            lists!!.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("还没有书单，右上角 + 新建一个", color = Color(0x559A9AA3))
            }
            else -> LazyColumn(
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, bottom = 24.dp),
            ) {
                items(lists!!, key = { it.id }) { list ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clickable { nav(list) }
                            .padding(vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                list.title,
                                fontSize = 16.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = Color(0xFFEDEDF0),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            Text(
                                list.items.size.toString() + " 期",
                                fontSize = 12.5.sp,
                                color = Color(0x559A9AA3),
                            )
                        }
                    }
                }
            }
        }
    }

    if (showCreate) {
        AlertDialog(
            onDismissRequest = { showCreate = false },
            title = { Text("新建书单") },
            text = {
                OutlinedTextField(
                    value = newName,
                    onValueChange = { newName = it },
                    placeholder = { Text("比如：全部内战") },
                    singleLine = true,
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    if (newName.isNotBlank()) {
                        ReadingLists.save(context, ReadingList(
                            id = java.util.UUID.randomUUID().toString(),
                            title = newName.trim(),
                        ))
                        lists = ReadingLists.load(context)
                    }
                    showCreate = false
                }) { Text("创建") }
            },
            dismissButton = {
                TextButton(onClick = { showCreate = false }) { Text("取消") }
            },
        )
    }
}

