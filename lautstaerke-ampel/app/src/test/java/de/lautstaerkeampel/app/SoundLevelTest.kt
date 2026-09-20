package de.lautstaerkeampel.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.sin

class SoundLevelTest {

    @Test
    fun `stille ergibt 0 dB`() {
        val silence = ShortArray(1024)
        assertEquals(0.0, SoundLevel.rms(silence, silence.size), 1e-9)
        assertEquals(0f, SoundLevel.toDb(0.0, 100f), 1e-6f)
    }

    @Test
    fun `vollausschlag entspricht dem kalibrierungs-offset`() {
        // RMS = 1.0 -> 20 * log10(1) + Offset = Offset
        assertEquals(100f, SoundLevel.toDb(1.0, 100f), 1e-4f)
        assertEquals(94f, SoundLevel.toDb(1.0, 94f), 1e-4f)
    }

    @Test
    fun `halbierter pegel entspricht rund 6 dB weniger`() {
        val loud = SoundLevel.toDb(0.5, 100f)
        val quiet = SoundLevel.toDb(0.25, 100f)
        assertEquals(6.02f, loud - quiet, 0.05f)
    }

    @Test
    fun `lauteres signal ergibt hoeheren dB-Wert`() {
        val quiet = sine(amplitude = 0.05)
        val loud = sine(amplitude = 0.5)
        val quietDb = SoundLevel.toDb(SoundLevel.rms(quiet, quiet.size), 100f)
        val loudDb = SoundLevel.toDb(SoundLevel.rms(loud, loud.size), 100f)
        assertTrue("lauter muss mehr dB ergeben ($loudDb <= $quietDb)", loudDb > quietDb + 15f)
    }

    @Test
    fun `sinus-rms entspricht amplitude durch wurzel 2`() {
        val samples = sine(amplitude = 1.0)
        assertEquals(0.7071, SoundLevel.rms(samples, samples.size), 0.01)
    }

    @Test
    fun `dB-Wert wird nie negativ`() {
        assertEquals(0f, SoundLevel.toDb(1e-9, 100f), 1e-6f)
    }

    @Test
    fun `schwellwerte bestimmen den ampelzustand`() {
        assertEquals(SoundLevel.Level.GREEN, SoundLevel.classify(54.9f, 55f, 65f))
        assertEquals(SoundLevel.Level.YELLOW, SoundLevel.classify(55f, 55f, 65f))
        assertEquals(SoundLevel.Level.YELLOW, SoundLevel.classify(64.9f, 55f, 65f))
        assertEquals(SoundLevel.Level.RED, SoundLevel.classify(65f, 55f, 65f))
        assertEquals(SoundLevel.Level.RED, SoundLevel.classify(120f, 55f, 65f))
    }

    @Test
    fun `geaenderte schwellwerte wirken sofort`() {
        val db = 60f
        assertEquals(SoundLevel.Level.YELLOW, SoundLevel.classify(db, 55f, 65f))
        assertEquals(SoundLevel.Level.RED, SoundLevel.classify(db, 40f, 50f))
        assertEquals(SoundLevel.Level.GREEN, SoundLevel.classify(db, 70f, 80f))
    }

    @Test
    fun `gleitender mittelwert glaettet ausreisser`() {
        val average = MovingAverage(4)
        assertEquals(50f, average.add(50f), 1e-4f)
        assertEquals(50f, average.add(50f), 1e-4f)
        assertEquals(50f, average.add(50f), 1e-4f)
        // Ein einzelner Ausreisser verschiebt den Mittelwert nur um einen Bruchteil.
        val smoothed = average.add(90f)
        assertEquals(60f, smoothed, 1e-4f)
        assertTrue(smoothed < 90f)
    }

    @Test
    fun `gleitender mittelwert folgt einem dauerhaften anstieg`() {
        val average = MovingAverage(4)
        repeat(4) { average.add(40f) }
        var last = 0f
        repeat(8) { last = average.add(80f) }
        assertEquals(80f, last, 1e-4f)
    }

    private fun sine(amplitude: Double, length: Int = 4096): ShortArray {
        val samples = ShortArray(length)
        for (i in 0 until length) {
            samples[i] = (amplitude * 32767 * sin(2 * Math.PI * 440 * i / 44100.0)).toInt().toShort()
        }
        return samples
    }
}
