package de.lautstaerkeampel.app

import android.content.Context
import android.content.SharedPreferences

/**
 * Persistente Einstellungen (SharedPreferences): Schwellwerte und Kalibrierungs-Offset.
 * Aenderungen wirken sofort, da [AudioMeter] die Werte bei jeder Auswertung frisch liest.
 */
class AmpelSettings(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    var yellowThreshold: Float
        get() = prefs.getFloat(KEY_YELLOW, DEFAULT_YELLOW)
        set(value) = prefs.edit().putFloat(KEY_YELLOW, value).apply()

    var redThreshold: Float
        get() = prefs.getFloat(KEY_RED, DEFAULT_RED)
        set(value) = prefs.edit().putFloat(KEY_RED, value).apply()

    var calibrationOffset: Float
        get() = prefs.getFloat(KEY_OFFSET, DEFAULT_OFFSET)
        set(value) = prefs.edit().putFloat(KEY_OFFSET, value).apply()

    companion object {
        private const val PREFS_NAME = "lautstaerke_ampel"
        private const val KEY_YELLOW = "yellow_db"
        private const val KEY_RED = "red_db"
        private const val KEY_OFFSET = "calibration_offset"

        const val DEFAULT_YELLOW = 55f
        const val DEFAULT_RED = 65f
        const val DEFAULT_OFFSET = 100f
    }
}
