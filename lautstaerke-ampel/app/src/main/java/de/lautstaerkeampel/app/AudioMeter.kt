package de.lautstaerkeampel.app

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
/**
 * Misst die Umgebungslautstaerke ueber [AudioRecord] und meldet einen geglaetteten
 * dB-Wert an den Aufrufer (immer auf dem Main-Thread).
 *
 * dB-Berechnung analog zur Web-Version: 20 * log10(RMS) + Kalibrierungs-Offset,
 * wobei RMS auf den Bereich -1..1 normalisierte PCM-16-Samples verwendet.
 */
class AudioMeter(
    private val offsetProvider: () -> Float,
    private val onLevel: (Float) -> Unit,
    private val onError: (Throwable) -> Unit
) {

    @Volatile
    private var running = false
    private var thread: Thread? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    val isRunning: Boolean get() = running

    @SuppressLint("MissingPermission")
    fun start() {
        if (running) return
        running = true
        thread = Thread({ recordLoop() }, "AudioMeter").also { it.start() }
    }

    fun stop() {
        running = false
        thread?.join(500)
        thread = null
    }

    @SuppressLint("MissingPermission")
    private fun recordLoop() {
        var record: AudioRecord? = null
        try {
            val minBuffer = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL, ENCODING)
            if (minBuffer <= 0) throw IllegalStateException("Audio-Puffergroesse nicht ermittelbar")

            val bufferSize = maxOf(minBuffer, CHUNK_SIZE * 2)
            record = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL,
                ENCODING,
                bufferSize
            )
            if (record.state != AudioRecord.STATE_INITIALIZED) {
                throw IllegalStateException("Mikrofon konnte nicht initialisiert werden")
            }

            record.startRecording()

            val buffer = ShortArray(CHUNK_SIZE)
            // Gleitender Mittelwert ueber die letzten Fenster, damit die Anzeige nicht springt.
            val average = MovingAverage(SMOOTHING_WINDOW)
            var lastEmit = 0L

            while (running) {
                val read = record.read(buffer, 0, buffer.size)
                if (read <= 0) continue

                // Offset bei jedem Fenster frisch lesen: Einstellungsaenderungen wirken sofort.
                val db = SoundLevel.toDb(SoundLevel.rms(buffer, read), offsetProvider())
                val smoothed = average.add(db)

                val now = System.currentTimeMillis()
                if (now - lastEmit >= EMIT_INTERVAL_MS) {
                    lastEmit = now
                    mainHandler.post { if (running) onLevel(smoothed) }
                }
            }
        } catch (t: Throwable) {
            running = false
            mainHandler.post { onError(t) }
        } finally {
            try {
                if (record?.recordingState == AudioRecord.RECORDSTATE_RECORDING) record.stop()
            } catch (_: Throwable) {
                // Ignorieren: Recorder war bereits gestoppt.
            }
            record?.release()
        }
    }

    companion object {
        private const val SAMPLE_RATE = 44100
        private const val CHANNEL = AudioFormat.CHANNEL_IN_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
        private const val CHUNK_SIZE = 2048
        private const val SMOOTHING_WINDOW = 8
        private const val EMIT_INTERVAL_MS = 100L // 10 Aktualisierungen pro Sekunde
    }
}
