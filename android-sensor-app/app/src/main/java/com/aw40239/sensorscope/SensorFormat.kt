package com.aw40239.sensorscope

import android.hardware.Sensor

/**
 * Ordnet Sensortypen eine lesbare Einheit/Formatierung zu.
 * Für unbekannte/seltene Sensortypen wird auf eine generische
 * Rohwert-Auflistung zurückgefallen, damit auch exotische
 * Samsung-eigene Sensoren (z. B. Grip-Sensor) sinnvoll dargestellt werden.
 */
fun formatSensorValues(sensor: Sensor, values: FloatArray): String {
    return when (sensor.type) {
        Sensor.TYPE_ACCELEROMETER,
        Sensor.TYPE_LINEAR_ACCELERATION,
        Sensor.TYPE_GRAVITY ->
            "x=${values[0].fmt()}  y=${values[1].fmt()}  z=${values[2].fmt()} m/s²"

        Sensor.TYPE_GYROSCOPE, Sensor.TYPE_GYROSCOPE_UNCALIBRATED ->
            "x=${values[0].fmt()}  y=${values[1].fmt()}  z=${values[2].fmt()} rad/s"

        Sensor.TYPE_MAGNETIC_FIELD, Sensor.TYPE_MAGNETIC_FIELD_UNCALIBRATED ->
            "x=${values[0].fmt()}  y=${values[1].fmt()}  z=${values[2].fmt()} µT"

        Sensor.TYPE_LIGHT -> "${values[0].fmt()} lx"
        Sensor.TYPE_PROXIMITY -> "${values[0].fmt()} cm (max ${sensor.maximumRange.fmt()} cm)"
        Sensor.TYPE_PRESSURE -> "${values[0].fmt()} hPa"
        Sensor.TYPE_AMBIENT_TEMPERATURE -> "${values[0].fmt()} °C"
        Sensor.TYPE_RELATIVE_HUMIDITY -> "${values[0].fmt()} %"
        Sensor.TYPE_HEART_RATE -> "${values[0].fmt()} bpm"
        Sensor.TYPE_STEP_COUNTER -> "${values[0].toInt()} Schritte seit Boot"
        Sensor.TYPE_STEP_DETECTOR -> "Schritt erkannt"
        Sensor.TYPE_SIGNIFICANT_MOTION -> "Bewegung erkannt"

        Sensor.TYPE_ROTATION_VECTOR,
        Sensor.TYPE_GAME_ROTATION_VECTOR,
        Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR ->
            values.take(3).joinToString(prefix = "[", postfix = "]") { it.fmt() }

        Sensor.TYPE_ORIENTATION ->
            "Azimut=${values[0].fmt()}  Pitch=${values[1].fmt()}  Roll=${values[2].fmt()} °"

        else -> values.joinToString(prefix = "[", postfix = "]") { it.fmt() }
    }
}

fun sensorTypeLabel(sensor: Sensor): String = when (sensor.type) {
    Sensor.TYPE_ACCELEROMETER -> "Beschleunigung"
    Sensor.TYPE_LINEAR_ACCELERATION -> "Lineare Beschleunigung"
    Sensor.TYPE_GRAVITY -> "Schwerkraft"
    Sensor.TYPE_GYROSCOPE -> "Gyroskop"
    Sensor.TYPE_GYROSCOPE_UNCALIBRATED -> "Gyroskop (unkalibriert)"
    Sensor.TYPE_MAGNETIC_FIELD -> "Magnetfeld"
    Sensor.TYPE_MAGNETIC_FIELD_UNCALIBRATED -> "Magnetfeld (unkalibriert)"
    Sensor.TYPE_LIGHT -> "Umgebungslicht"
    Sensor.TYPE_PROXIMITY -> "Näherung"
    Sensor.TYPE_PRESSURE -> "Luftdruck"
    Sensor.TYPE_AMBIENT_TEMPERATURE -> "Umgebungstemperatur"
    Sensor.TYPE_RELATIVE_HUMIDITY -> "Luftfeuchtigkeit"
    Sensor.TYPE_HEART_RATE -> "Herzfrequenz"
    Sensor.TYPE_STEP_COUNTER -> "Schrittzähler"
    Sensor.TYPE_STEP_DETECTOR -> "Schritterkennung"
    Sensor.TYPE_SIGNIFICANT_MOTION -> "Signifikante Bewegung"
    Sensor.TYPE_ROTATION_VECTOR -> "Rotationsvektor"
    Sensor.TYPE_GAME_ROTATION_VECTOR -> "Rotationsvektor (Spiel)"
    Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR -> "Rotationsvektor (geomagnetisch)"
    Sensor.TYPE_ORIENTATION -> "Ausrichtung"
    else -> sensor.name
}

private fun Float.fmt(): String = "%.2f".format(this)
