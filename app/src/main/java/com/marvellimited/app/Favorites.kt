package com.marvellimited.app

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken

/** 收藏存储：JSON 文件持久化 */
object Favorites {
    private val gson = Gson()
    private var cache: MutableList<Issue>? = null

    private fun file(ctx: Context) = java.io.File(ctx.filesDir, "favorites.json")

    @Synchronized
    fun load(ctx: Context): List<Issue> {
        cache?.let { return it }
        val f = file(ctx)
        cache = if (f.exists()) {
            try {
                gson.fromJson<List<Issue>>(f.readText(), object : TypeToken<List<Issue>>() {}.type)
                    .toMutableList()
            } catch (e: Exception) {
                mutableListOf()
            }
        } else mutableListOf()
        return cache!!
    }

    @Synchronized
    fun toggle(ctx: Context, issue: Issue): Boolean {
        val list = load(ctx).toMutableList()
        val idx = list.indexOfFirst { it.id == issue.id }
        val added: Boolean
        if (idx >= 0) { list.removeAt(idx); added = false }
        else { list.add(issue); added = true }
        cache = list
        file(ctx).writeText(gson.toJson(list))
        return added
    }

    @Synchronized
    fun has(ctx: Context, id: String): Boolean =
        load(ctx).any { it.id == id }
}
