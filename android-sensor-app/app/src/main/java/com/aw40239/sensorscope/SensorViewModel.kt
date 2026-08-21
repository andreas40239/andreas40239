package com.aw40239.sensorscope

import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import androidx.core.content.ContextCompat
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class LiveSensorReading(
    val sensorType: Int,
    val displayName: String,
    val vendor: String,
    val valueText: String,
)

data class TemperatureInfo(
    val batteryTempC: Float? = null,
    val ambientTempC: Float? = null,
    val hasAmbientSensor: Boolean = false,
    val thermalStatusText: String = "unbekannt",
    val thermalHeadroom10s: Float? = null,
)

data class SensorUiState(
    val temperature: TemperatureInfo = TemperatureInfo(),
    val readings: List<LiveSensorReading> = emptyList(),
    val totalSensorCount: Int = 0,
)

class SensorViewModel(application: Application) : AndroidViewModel(application) {

    private val sensorManager =
        application.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val powerManager =
        application.getSystemService(Context.POWER_SERVICE) as PowerManager

    private val latestValues = mutableMapOf<Int, LiveSensorReading>()

    private val _uiState = MutableStateFlow(SensorUiState())
    val uiState: StateFlow<SensorUiState> = _uiState.asStateFlow()

    private val allSensors: List<Sensor> =
        sensorManager.getSensorList(Sensor.TYPE_ALL).sortedBy { it.name }

    private val ambientTempSensor: Sensor? =
        sensorManager.getDefaultSensor(Sensor.TYPE_AMBIENT_TEMPERATURE)

    private val listener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            val sensor = event.sensor
            latestValues[sensor.type] = LiveSensorReading(
                sensorType = sensor.type,
                displayName = sensorTypeLabel(sensor),
                vendor = sensor.vendor ?: "-",
                valueText = formatSensorValues(sensor, event.values),
            )
            if (sensor.type == Sensor.TYPE_AMBIENT_TEMPERATURE) {
                _uiState.update { it.copy(temperature = it.temperature.copy(ambientTempC = event.values[0])) }
            }
            pushReadings()
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    }

    private val batteryReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val tenthsOfDegree = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
                ?: Int.MIN_VALUE
            if (tenthsOfDegree != Int.MIN_VALUE) {
                val celsius = tenthsOfDegree / 10f
                _uiState.update { it.copy(temperature = it.temperature.copy(batteryTempC = celsius)) }
            }
        }
    }

    init {
        _uiState.update {
            it.copy(
                totalSensorCount = allSensors.size,
                temperature = it.temperature.copy(hasAmbientSensor = ambientTempSensor != null),
            )
        }

        allSensors.forEach { sensor ->
            sensorManager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_UI)
        }

        ContextCompat.registerReceiver(
            application,
            batteryReceiver,
            IntentFilter(Intent.ACTION_BATTERY_CHANGED),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            powerManager.addThermalStatusListener { status ->
                _uiState.update {
                    it.copy(temperature = it.temperature.copy(thermalStatusText = thermalStatusLabel(status)))
                }
            }
            _uiState.update {
                it.copy(temperature = it.temperature.copy(thermalStatusText = thermalStatusLabel(powerManager.currentThermalStatus)))
            }
            pollThermalHeadroom()
        }
    }

    private fun pollThermalHeadroom() {
        viewModelScope.launch {
            while (true) {
                // Liefert Float.NaN, wenn das Gerät kein Thermal-Headroom unterstützt.
                val headroom = powerManager.getThermalHeadroom(10)
                _uiState.update {
                    it.copy(
                        temperature = it.temperature.copy(
                            thermalHeadroom10s = if (headroom.isNaN()) null else headroom,
                        )
                    )
                }
                delay(2000)
            }
        }
    }

    private fun pushReadings() {
        _uiState.update { it.copy(readings = latestValues.values.sortedBy { r -> r.displayName }) }
    }

    private fun thermalStatusLabel(status: Int): String = when (status) {
        PowerManager.THERMAL_STATUS_NONE -> "Normal"
        PowerManager.THERMAL_STATUS_LIGHT -> "Leicht erhöht"
        PowerManager.THERMAL_STATUS_MODERATE -> "Moderat"
        PowerManager.THERMAL_STATUS_SEVERE -> "Stark erhöht"
        PowerManager.THERMAL_STATUS_CRITICAL -> "Kritisch"
        PowerManager.THERMAL_STATUS_EMERGENCY -> "Notfall"
        PowerManager.THERMAL_STATUS_SHUTDOWN -> "Abschaltung droht"
        else -> "unbekannt"
    }

    override fun onCleared() {
        super.onCleared()
        sensorManager.unregisterListener(listener)
        getApplication<Application>().unregisterReceiver(batteryReceiver)
    }
}
