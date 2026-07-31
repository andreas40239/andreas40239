package de.andreas40239.hopquest

/** Poolable flying obstacle. Sits high enough that a grounded player passes safely
 *  underneath — it only threatens the player mid-jump. */
class FlyingObstacle {
    var active = false
    var x = 0f
    var baseY = 0f
    var width = 0f
    var height = 0f
    var hasHit = false
    var bobPhase = 0f

    fun spawn(startX: Float, y: Float, w: Float, h: Float) {
        active = true
        x = startX
        baseY = y
        width = w
        height = h
        hasHit = false
        bobPhase = 0f
    }

    fun right() = x + width
    fun currentY(bobAmplitude: Float) = baseY + kotlin.math.sin(bobPhase) * bobAmplitude
}
