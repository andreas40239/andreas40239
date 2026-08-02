package de.andreas40239.gpsposition

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.graphics.Paint
import android.os.Bundle
import android.provider.Settings
import android.widget.ImageView
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Ermittelt Position, Fahrtrichtung und Geschwindigkeit ausschliesslich ueber den
 * GPS-Satellitenempfang (LocationManager.GPS_PROVIDER). Es wird keine Netzwerk-
 * Standortbestimmung und kein Google-Play-Services-Client verwendet, damit die
 * App vollstaendig offline (Flugmodus + aktiviertes GPS) funktioniert.
 */
class MainActivity : AppCompatActivity(), LocationListener {

    private lateinit var locationManager: LocationManager

    private lateinit var tvLatitude: TextView
    private lateinit var tvLongitude: TextView
    private lateinit var tvDegree: TextView
    private lateinit var tvCompassLetter: TextView
    private lateinit var tvSpeedValue: TextView
    private lateinit var tvGpsStatus: TextView
    private lateinit var ivNeedle: ImageView

    private val requestPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (granted) {
                startLocationUpdates()
            } else {
                tvGpsStatus.text = getString(R.string.permission_denied)
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        tvLatitude = findViewById(R.id.tvLatitude)
        tvLongitude = findViewById(R.id.tvLongitude)
        tvDegree = findViewById(R.id.tvDegree)
        tvCompassLetter = findViewById(R.id.tvCompassLetter)
        tvSpeedValue = findViewById(R.id.tvSpeedValue)
        tvGpsStatus = findViewById(R.id.tvGpsStatus)
        ivNeedle = findViewById(R.id.ivNeedle)

        val tvWlanStrike: TextView = findViewById(R.id.tvOfflineBadgeStrike)
        tvWlanStrike.paintFlags = tvWlanStrike.paintFlags or Paint.STRIKE_THRU_TEXT_FLAG

        locationManager = getSystemService(LOCATION_SERVICE) as LocationManager
    }

    override fun onResume() {
        super.onResume()
        checkPermissionAndStart()
    }

    override fun onPause() {
        super.onPause()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            == PackageManager.PERMISSION_GRANTED
        ) {
            locationManager.removeUpdates(this)
        }
    }

    private fun checkPermissionAndStart() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            == PackageManager.PERMISSION_GRANTED
        ) {
            startLocationUpdates()
        } else {
            requestPermissionLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun startLocationUpdates() {
        if (!locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            tvGpsStatus.text = getString(R.string.gps_disabled)
            showEnableGpsDialog()
            return
        }

        try {
            locationManager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                MIN_UPDATE_INTERVAL_MS,
                MIN_UPDATE_DISTANCE_M,
                this
            )
            tvGpsStatus.text = getString(R.string.waiting_for_fix)

            locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)?.let {
                onLocationChanged(it)
            }
        } catch (e: SecurityException) {
            tvGpsStatus.text = getString(R.string.permission_denied)
        }
    }

    private fun showEnableGpsDialog() {
        AlertDialog.Builder(this)
            .setTitle(R.string.gps_disabled_title)
            .setMessage(R.string.gps_disabled_message)
            .setPositiveButton(R.string.settings) { _, _ ->
                startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    override fun onLocationChanged(location: Location) {
        tvGpsStatus.text = if (location.hasAccuracy()) {
            getString(R.string.gps_accuracy, location.accuracy.roundToInt())
        } else {
            getString(R.string.waiting_for_fix)
        }

        tvLatitude.text = toDms(location.latitude, isLatitude = true)
        tvLongitude.text = toDms(location.longitude, isLatitude = false)

        if (location.hasBearing() && location.hasSpeed() && location.speed > MIN_SPEED_FOR_BEARING_MS) {
            val bearing = ((location.bearing % 360f) + 360f) % 360f
            tvDegree.text = getString(R.string.degree_value, bearing.roundToInt())
            tvCompassLetter.text = compassAbbrev(bearing)
            ivNeedle.rotation = bearing
            ivNeedle.alpha = 1f
        } else {
            tvDegree.text = getString(R.string.value_placeholder)
            tvCompassLetter.text = ""
            ivNeedle.alpha = 0.25f
        }

        tvSpeedValue.text = if (location.hasSpeed()) {
            (location.speed * 3.6f).roundToInt().toString()
        } else {
            getString(R.string.value_placeholder)
        }
    }

    @Deprecated("Deprecated in Java", ReplaceWith(""))
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {
        // Kein Handlungsbedarf, Status wird ueber onLocationChanged/onProvider* abgebildet.
    }

    override fun onProviderEnabled(provider: String) {
        if (provider == LocationManager.GPS_PROVIDER) {
            tvGpsStatus.text = getString(R.string.waiting_for_fix)
        }
    }

    override fun onProviderDisabled(provider: String) {
        if (provider == LocationManager.GPS_PROVIDER) {
            tvGpsStatus.text = getString(R.string.gps_disabled)
        }
    }

    /** Wandelt Dezimalgrad in das Format Grad° Minute' Sekunde" mit Himmelsrichtung um. */
    private fun toDms(value: Double, isLatitude: Boolean): String {
        val hemisphere = if (isLatitude) {
            if (value >= 0) "N" else "S"
        } else {
            if (value >= 0) "O" else "W"
        }

        val absValue = abs(value)
        val degrees = absValue.toInt()
        val minutesFull = (absValue - degrees) * 60
        val minutes = minutesFull.toInt()
        val seconds = ((minutesFull - minutes) * 60).roundToInt()

        return String.format("%d° %02d' %02d\" %s", degrees, minutes, seconds, hemisphere)
    }

    private fun compassAbbrev(bearing: Float): String {
        val directions = arrayOf("N", "NO", "O", "SO", "S", "SW", "W", "NW")
        val index = ((bearing + 22.5f) / 45f).toInt() % 8
        return directions[index]
    }

    private companion object {
        const val MIN_UPDATE_INTERVAL_MS = 1000L
        const val MIN_UPDATE_DISTANCE_M = 0f
        const val MIN_SPEED_FOR_BEARING_MS = 0.5f
    }
}
