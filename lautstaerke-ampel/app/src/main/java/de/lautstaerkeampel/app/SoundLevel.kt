package de.lautstaerkeampel.app

import kotlin.math.log10
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Reine Rechenlogik der Pegelmessung – bewusst frei von Android-APIs, damit sie
 * per Unit-Test geprüft werden kann.
 */
object SoundLevel {

    /** RMS der PCM-16-Samples, normalisiert auf den Bereich -1..1 (wie in der Web-Version). */
    fun rms(samples: ShortArray, length: Int): Double {
        if (length <= 0) return 0.0
        var sumOfSquares = 0.0
        for (i in 0 until length) {
            val sample = samples[i] / 32768.0
            sumOfSquares += sample * sample
        }
        return sqrt(sumOfSquares / length)
    }

    /** dB-Wert analog zur Web-Version: 20 * log10(RMS) + Kalibrierungs-Offset, nie negativ. */
    fun toDb(rms: Double, calibrationOffset: Float): Float {
        if (rms <= 0.0) return 0f
        val db = (20.0 * log10(rms)).toFloat() + calibrationOffset
        return db.coerceAtLeast(0f)
    }

    /** Ampelzustand für einen Messwert; der Rot-Schwellwert hat Vorrang. */
    fun classify(db: Float, yellowThreshold: Float, redThreshold: Float): Level = when {
        db >= redThreshold -> Level.RED
        db >= yellowThreshold -> Level.YELLOW
        else -> Level.GREEN
    }

    enum class Level { GREEN, YELLOW, RED }
}

/** Gleitender Mittelwert über die letzten [size] Werte – glättet die Anzeige. */
class MovingAverage(private val size: Int) {

    private val values = FloatArray(size)
    private var count = 0
    private var index = 0

    fun add(value: Float): Float {
        values[index] = value
        index = (index + 1) % size
        count = min(count + 1, size)
        var sum = 0f
        for (i in 0 until count) sum += values[i]
        return sum / count
    }

    fun reset() {
        count = 0
        index = 0
    }
}
