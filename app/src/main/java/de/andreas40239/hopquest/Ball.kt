package de.andreas40239.hopquest

/** Poolable boss projectile — must be jumped over, like a small ground obstacle. */
class Ball {
    var active = false
    var x = 0f
    var size = 0f
    var hasHit = false

    fun spawn(startX: Float, s: Float) {
        active = true
        x = startX
        size = s
        hasHit = false
    }

    fun right() = x + size
}
