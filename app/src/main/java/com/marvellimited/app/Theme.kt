package com.marvellimited.app

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

private val Bg = Color(0xFF0A0A0C)
private val Surface = Color(0xFF16161A)
private val SurfaceHi = Color(0xFF1E1E24)
private val Red = Color(0xFFED1D24)

private val Scheme = darkColorScheme(
    primary = Red,
    onPrimary = Color.White,
    background = Bg,
    onBackground = Color(0xFFEDEDF0),
    surface = Surface,
    onSurface = Color(0xFFEDEDF0),
    surfaceVariant = SurfaceHi,
    onSurfaceVariant = Color(0xFF9A9AA3),
    outline = Color(0xFF2A2A31),
)

/** 大标题：负字距、紧行高（apple-design 排版规范） */
val LargeTitle = TextStyle(
    fontSize = 34.sp,
    fontWeight = FontWeight.Bold,
    letterSpacing = (-0.8).sp,
    lineHeight = 40.sp,
)

val Title2 = TextStyle(
    fontSize = 21.sp,
    fontWeight = FontWeight.Bold,
    letterSpacing = (-0.4).sp,
    lineHeight = 26.sp,
)

@Composable
fun MarvelTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = Scheme,
        typography = MaterialTheme.typography.copy(
            titleLarge = Title2,
        ),
        content = content,
    )
}
