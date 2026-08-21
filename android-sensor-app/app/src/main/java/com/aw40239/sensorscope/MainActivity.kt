package com.aw40239.sensorscope

import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.aw40239.sensorscope.ui.theme.SensorScopeTheme

class MainActivity : ComponentActivity() {

    private val viewModel: SensorViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            SensorScopeTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    val state by viewModel.uiState.collectAsState()
                    SensorScreen(state)
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SensorScreen(state: SensorUiState) {
    Scaffold(
        topBar = {
            TopAppBar(title = { Text("SensorScope – ${Build.MODEL}") })
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            item { SectionHeader("Temperatur") }
            item { TemperatureCard(state.temperature) }

            item { SectionHeader("Alle Sensoren (${state.readings.size} / ${state.totalSensorCount})") }
            items(state.readings, key = { it.sensorType }) { reading ->
                SensorCard(reading)
            }
        }
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.Bold,
        modifier = Modifier.padding(top = 12.dp, bottom = 4.dp),
    )
}

@Composable
private fun TemperatureCard(temp: TemperatureInfo) {
    Card(modifier = Modifier.fillMaxWidth(), elevation = CardDefaults.cardElevation(2.dp)) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            TempRow("Akku-Temperatur", temp.batteryTempC?.let { "%.1f °C".format(it) } ?: "lädt…")

            if (temp.hasAmbientSensor) {
                TempRow("Umgebungstemperatur", temp.ambientTempC?.let { "%.1f °C".format(it) } ?: "lädt…")
            } else {
                TempRow("Umgebungstemperatur", "kein Sensor im S24 Ultra vorhanden")
            }

            TempRow("Thermal-Status (SoC)", temp.thermalStatusText)
            TempRow(
                "Thermal Headroom (10s Prognose)",
                temp.thermalHeadroom10s?.let { "%.2f (0 = kühl, >1 = Drosselung droht)".format(it) }
                    ?: "nicht unterstützt",
            )

            Text(
                text = "Hinweis: Die exakte Chip-Temperatur (°C) ist für normale Apps aus " +
                    "Sicherheitsgründen nicht auslesbar – Android liefert stattdessen den " +
                    "Thermal-Status/Headroom als Hitze-Indikator.",
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}

@Composable
private fun TempRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(text = label, style = MaterialTheme.typography.bodyMedium)
        Text(text = value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun SensorCard(reading: LiveSensorReading) {
    Card(modifier = Modifier.fillMaxWidth(), elevation = CardDefaults.cardElevation(1.dp)) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text(text = reading.displayName, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold)
            Text(text = reading.valueText, style = MaterialTheme.typography.bodyMedium)
            Text(text = reading.vendor, style = MaterialTheme.typography.bodySmall)
        }
    }
}
