package de.andreas40239.hopquest

import android.graphics.Bitmap

/** Simple mutable, poolable obstacle — reused instead of reallocated to avoid GC churn.
 *  Doubles as a pit hazard (isPit=true): a wider, shallow-hitbox gap you must jump over,
 *  rendered taller than its hitbox using a pre-scaled themed bitmap. */
class Obstacle {
    var active = false
    var x = 0f
    var width = 0f
    var height = 0f
    var hasHit = false
    var isPit = false
    var pitBitmap: Bitmap? = null

    fun spawn(startX: Float, w: Float, h: Float, pit: Boolean = false, bmp: Bitmap? = null) {
        active = true
        x = startX
        width = w
        height = h
        hasHit = false
        isPit = pit
        pitBitmap = bmp
    }

    fun right() = x + width
}
