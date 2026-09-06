package com.marvellimited.app

import android.os.Bundle
import android.content.Context
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue

/** 主题设置持久化 */
object ThemePref {
    fun load(ctx: Context): ThemeMode {
        return try {
            val v = ctx.getSharedPreferences("pref", Context.MODE_PRIVATE).getString("theme", "SYSTEM")
            ThemeMode.valueOf(v ?: "SYSTEM")
        } catch (e: Exception) {
            ThemeMode.SYSTEM
        }
    }

    fun save(ctx: Context, mode: ThemeMode) {
        ctx.getSharedPreferences("pref", Context.MODE_PRIVATE).edit()
            .putString("theme", mode.name).apply()
    }
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            var mode by remember {
                mutableStateOf(ThemePref.load(this))
            }
            MarvelTheme(mode = mode) {
                MarvelApp(
                    onThemeChange = { m ->
                        mode = m
                        ThemePref.save(this, m)
                    },
                )
            }
        }
    }
}
