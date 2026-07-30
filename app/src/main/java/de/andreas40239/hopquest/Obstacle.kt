package de.andreas40239.hopquest

/** Simple mutable, poolable obstacle — reused instead of reallocated to avoid GC churn. */
class Obstacle {
    var active = false
    var x = 0f
    var width = 0f
    var height = 0f
    var hasHit = false

    fun spawn(startX: Float, w: Float, h: Float) {
        active = true
        x = startX
        width = w
        height = h
        hasHit = false
    }

    fun right() = x + width
}
