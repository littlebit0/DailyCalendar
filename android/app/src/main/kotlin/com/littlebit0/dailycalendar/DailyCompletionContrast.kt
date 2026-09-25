package com.littlebit0.dailycalendar

import android.graphics.Color
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** Display-only colours. Stored category colours and identifying accents never change. */
internal object DailyCompletionContrast {
    data class Palette(val foreground: Int, val strike: Int, val background: Int)
    private data class Range(val low: Double, val high: Double)
    private const val titleTarget = 4.55
    private const val strikeTarget = 3.05
    private val linear = DoubleArray(256) { channel ->
        val value = channel / 255.0
        if (value <= .04045) value / 12.92 else ((value + .055) / 1.055).pow(2.4)
    }
    private val cache = object : LinkedHashMap<Pair<Int, Int>, Palette>(512, .75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<Pair<Int, Int>, Palette>) = size > 512
    }

    fun strokeWidth(fontSize: Float, minimumUnit: Float = 1f): Float =
        max(1.25f * minimumUnit, fontSize / 12f)

    @Synchronized
    fun resolve(category: Int, background: Int): Palette {
        val bg = composite(background, Color.WHITE)
        val source = composite(category, bg)
        val key = source to bg
        cache[key]?.let { return it }
        var result = onSurface(source, bg)
        if (result == null) {
            val ranges = listOf(Range(.05, 1.05 / (strikeTarget * strikeTarget)),
                Range(.05 * strikeTarget, 1.05 / titleTarget),
                Range(.05 * titleTarget, 1.05 / strikeTarget),
                Range(.05 * strikeTarget * strikeTarget, 1.05))
            var distance = Double.POSITIVE_INFINITY
            for (range in ranges) for (candidate in coloursInRange(bg, range)) {
                val palette = onSurface(source, candidate) ?: continue
                val delta = distance(bg, candidate)
                if (delta < distance) { distance = delta; result = palette }
            }
        }
        return checkNotNull(result) { "No accessible event palette" }.also { cache[key] = it }
    }

    fun contrast(a: Int, b: Int): Double = max(light(a), light(b)) / min(light(a), light(b))
    private fun light(color: Int) = .2126 * linear[Color.red(color)] +
        .7152 * linear[Color.green(color)] + .0722 * linear[Color.blue(color)] + .05
    private fun contrastRanges(light: Double, ratio: Double) =
        listOf(Range(.05, light / ratio), Range(light * ratio, 1.05))
    private fun intersections(a: List<Range>, b: List<Range>): List<Range> = buildList {
        for (x in a) for (y in b) {
            val low = max(.05, max(x.low, y.low)); val high = min(1.05, min(x.high, y.high))
            if (low <= high) add(Range(low, high))
        }
    }
    private fun onSurface(source: Int, background: Int): Palette? {
        val b = light(background)
        val withLine = buildList {
            if (b >= .05 * strikeTarget) add(Range(.05 * strikeTarget, 1.05))
            if (b <= 1.05 / strikeTarget) add(Range(.05, 1.05 / strikeTarget))
            add(Range(.05, b / (strikeTarget * strikeTarget)))
            add(Range(b * strikeTarget * strikeTarget, 1.05))
        }
        var best: Palette? = null
        var distance = Double.POSITIVE_INFINITY
        for (range in intersections(contrastRanges(b, titleTarget), withLine)) {
            for (ink in coloursInRange(source, range)) {
                val delta = distance(source, ink)
                if (delta >= distance || contrast(ink, background) < 4.5) continue
                val line = line(source, ink, background) ?: continue
                best = Palette(ink, line, background); distance = delta
                if (distance == 0.0) return best
                break
            }
        }
        return best
    }
    private fun line(source: Int, ink: Int, background: Int): Int? {
        val a = light(ink); val b = light(background)
        var best: Int? = null; var score = Double.POSITIVE_INFINITY
        for (range in intersections(contrastRanges(a, strikeTarget), contrastRanges(b, strikeTarget))) {
            val preferred = sqrt(a * b).coerceIn(range.low, range.high)
            for (line in coloursInRange(source, range, preferred)) {
                if (contrast(line, ink) < 3 || contrast(line, background) < 3) continue
                val l = light(line)
                val outside = l < min(a, b) || l > max(a, b)
                val candidateScore = (if (outside) 10 else 0) + abs(ln(l / preferred))
                if (candidateScore < score) { score = candidateScore; best = line }
                break
            }
        }
        return best
    }
    private fun coloursInRange(source: Int, range: Range, preferred: Double? = null): List<Int> {
        val target = (preferred ?: light(source)).coerceIn(range.low, range.high)
        val center = (range.low + range.high) / 2
        return listOf(0.0, .0625, .125, .25, .5, 1.0)
            .map { withLight(source, target + (center - target) * it) }.distinct()
    }
    private fun withLight(source: Int, light: Double): Int {
        if (abs(light(source) - light) < 1e-12) return source
        val white = light > light(source)
        val r = Color.red(source); val g = Color.green(source); val b = Color.blue(source)
        val end = if (white) 255 else 0
        var low = 0.0; var high = 1.0
        fun lightAt(t: Double) = .2126 * linear[(r + (end - r) * t).roundToInt()] +
            .7152 * linear[(g + (end - g) * t).roundToInt()] +
            .0722 * linear[(b + (end - b) * t).roundToInt()] + .05
        repeat(20) {
            val mid = (low + high) / 2
            if ((lightAt(mid) < light) == white) low = mid else high = mid
        }
        return Color.rgb((r + (end - r) * high).roundToInt(),
            (g + (end - g) * high).roundToInt(), (b + (end - b) * high).roundToInt())
    }
    private fun distance(a: Int, b: Int): Double =
        (Color.red(a) / 255.0 - Color.red(b) / 255.0).pow(2) +
        (Color.green(a) / 255.0 - Color.green(b) / 255.0).pow(2) +
        (Color.blue(a) / 255.0 - Color.blue(b) / 255.0).pow(2)

    fun blend(text: Int, surface: Int, alpha: Double): Int = Color.rgb(
        (Color.red(text) * alpha + Color.red(surface) * (1 - alpha)).roundToInt(),
        (Color.green(text) * alpha + Color.green(surface) * (1 - alpha)).roundToInt(),
        (Color.blue(text) * alpha + Color.blue(surface) * (1 - alpha)).roundToInt())

    private fun composite(color: Int, surface: Int): Int = blend(color, surface, Color.alpha(color) / 255.0)
}
