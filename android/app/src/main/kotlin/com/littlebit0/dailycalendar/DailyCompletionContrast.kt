package com.littlebit0.dailycalendar

import android.graphics.Color
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sqrt

internal object DailyCompletionContrast {
    fun strike(text: Int, background: Int): Int {
        fun luminance(color: Int): Double {
            fun linear(c: Int): Double {
                val v = c / 255.0
                return if (v <= 0.04045) v / 12.92 else ((v + 0.055) / 1.055).pow(2.4)
            }
            return linear(Color.red(color)) * 0.2126 +
                linear(Color.green(color)) * 0.7152 + linear(Color.blue(color)) * 0.0722 + 0.05
        }
        val a = luminance(text)
        val b = luminance(background)
        val middle = sqrt(a * b) - 0.05
        val encoded = if (middle <= 0.0031308) middle * 12.92 else 1.055 * middle.pow(1 / 2.4) - 0.055
        val c = (encoded * 255).roundToInt().coerceIn(0, 255)
        return listOf(0, 255, c, max(0, c - 1), min(255, c + 1))
            .map { Color.rgb(it, it, it) }.maxBy { color ->
                val l = luminance(color)
                min(max(a, l) / min(a, l), max(b, l) / min(b, l))
            }
    }

    fun blend(text: Int, surface: Int, alpha: Double): Int = Color.rgb(
        (Color.red(text) * alpha + Color.red(surface) * (1 - alpha)).roundToInt(),
        (Color.green(text) * alpha + Color.green(surface) * (1 - alpha)).roundToInt(),
        (Color.blue(text) * alpha + Color.blue(surface) * (1 - alpha)).roundToInt(),
    )
}
