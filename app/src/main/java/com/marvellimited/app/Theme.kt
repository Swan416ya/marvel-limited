package com.marvellimited.app

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/** 应用内主题模式 */
enum class ThemeMode { SYSTEM, LIGHT, DARK }

val LocalThemeMode = staticCompositionLocalOf { ThemeMode.SYSTEM }

/** 浅色：干净白底 + 近黑文字 + 单一强调色（漫威红，仅点缀） */
private val LightScheme = lightColorScheme(
    primary = Color(0xFF1A1A1E),
    onPrimary = Color.White,
    background = Color(0xFFFCFCFD),
    onBackground = Color(0xFF1A1A1E),
    surface = Color.White,
    onSurface = Color(0xFF1A1A1E),
    surfaceVariant = Color(0xFFF2F2F4),
    onSurfaceVariant = Color(0xFF6E6E76),
    outline = Color(0xFFE4E4E8),
)

/** 深色：纯黑底 + 白字 */
private val DarkScheme = darkColorScheme(
    primary = Color.White,
    onPrimary = Color(0xFF111113),
    background = Color(0xFF0C0C0E),
    onBackground = Color(0xFFF2F2F4),
    surface = Color(0xFF151517),
    onSurface = Color(0xFFF2F2F4),
    surfaceVariant = Color(0xFF1E1E22),
    onSurfaceVariant = Color(0xFF9A9AA3),
    outline = Color(0xFF2A2A31),
)

/** 漫威红：只用于极少量点缀（选中态、logo） */
val MarvelRed = Color(0xFFED1D24)

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
fun MarvelTheme(
    mode: ThemeMode = ThemeMode.SYSTEM,
    content: @Composable () -> Unit,
) {
    val dark = when (mode) {
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
        ThemeMode.LIGHT -> false
        ThemeMode.DARK -> true
    }
    androidx.compose.runtime.CompositionLocalProvider(LocalThemeMode provides mode) {
        MaterialTheme(
            colorScheme = if (dark) DarkScheme else LightScheme,
            typography = MaterialTheme.typography.copy(titleLarge = Title2),
            content = content,
        )
    }
}

