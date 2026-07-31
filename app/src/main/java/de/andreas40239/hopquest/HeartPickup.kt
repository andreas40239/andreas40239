package de.andreas40239.hopquest

/** Poolable collectible heart that recharges a life on contact. */
class HeartPickup {
    var active = false
    var x = 0f
    var y = 0f
    var size = 0f

    fun spawn(startX: Float, yPos: Float, s: Float) {
        active = true
        x = startX
        y = yPos
        size = s
    }

    fun right() = x + size
}
