package de.lautstaerkeampel.app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View

/**
 * Horizontale Pegelanzeige mit Markierungen fuer die aktuellen Schwellwerte.
 */
class LevelBarView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#33000000")
    }
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val markerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#B3FFFFFF")
        strokeWidth = dp(3f)
    }
    private val rect = RectF()

    private var level = MIN_DB
    private var yellowThreshold = AmpelSettings.DEFAULT_YELLOW
    private var redThreshold = AmpelSettings.DEFAULT_RED
    private var fillColor = Color.WHITE

    fun setLevel(db: Float) {
        level = db.coerceIn(MIN_DB, MAX_DB)
        invalidate()
    }

    fun setThresholds(yellow: Float, red: Float) {
        yellowThreshold = yellow
        redThreshold = red
        invalidate()
    }

    fun setFillColor(color: Int) {
        fillColor = color
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val radius = height / 2f
        rect.set(0f, 0f, width.toFloat(), height.toFloat())
        canvas.drawRoundRect(rect, radius, radius, trackPaint)

        val fraction = ((level - MIN_DB) / (MAX_DB - MIN_DB)).coerceIn(0f, 1f)
        if (fraction > 0f) {
            fillPaint.color = fillColor
            rect.set(0f, 0f, width * fraction, height.toFloat())
            canvas.drawRoundRect(rect, radius, radius, fillPaint)
        }

        drawMarker(canvas, yellowThreshold)
        drawMarker(canvas, redThreshold)
    }

    private fun drawMarker(canvas: Canvas, db: Float) {
        val fraction = ((db - MIN_DB) / (MAX_DB - MIN_DB))
        if (fraction < 0f || fraction > 1f) return
        val x = width * fraction
        canvas.drawLine(x, 0f, x, height.toFloat(), markerPaint)
    }

    private fun dp(value: Float) = value * resources.displayMetrics.density

    companion object {
        const val MIN_DB = 30f
        const val MAX_DB = 100f
    }
}
