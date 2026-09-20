package de.lautstaerkeampel.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.view.WindowManager
import android.widget.EditText
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import de.lautstaerkeampel.app.databinding.ActivityMainBinding
import kotlin.math.roundToInt

/**
 * Einziger Screen der App: Lautstärke messen, Ampelfarbe anzeigen, Schwellwerte einstellen.
 */
class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var settings: AmpelSettings
    private lateinit var meter: AudioMeter

    private var suppressWatchers = false

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (granted) {
                hideError()
                startMeasuring()
            } else {
                showPermissionError()
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        settings = AmpelSettings(this)
        meter = AudioMeter(
            offsetProvider = { settings.calibrationOffset },
            onLevel = ::onLevel,
            onError = { showError(getString(R.string.error_audio)); updateUiForStopped() }
        )

        binding.toggleButton.setOnClickListener { onToggleClicked() }
        binding.settingsToggle.setOnClickListener { toggleSettingsPanel() }
        binding.permissionSettingsButton.setOnClickListener { openAppSettings() }
        binding.resetButton.setOnClickListener { resetDefaults() }

        setupSettingsInputs()
        loadSettingsIntoInputs()
        applyState(State.IDLE)
        binding.levelBar.setThresholds(settings.yellowThreshold, settings.redThreshold)
        binding.levelBar.setLevel(LevelBarView.MIN_DB)
    }

    override fun onStop() {
        super.onStop()
        // Aufnahme nie im Hintergrund weiterlaufen lassen.
        if (meter.isRunning) {
            meter.stop()
            updateUiForStopped()
        }
    }

    // --- Messung ---------------------------------------------------------

    private fun onToggleClicked() {
        if (meter.isRunning) {
            meter.stop()
            updateUiForStopped()
            return
        }

        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

        when {
            granted -> startMeasuring()
            shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO) -> showRationale()
            else -> requestPermission()
        }
    }

    private fun showRationale() {
        AlertDialog.Builder(this)
            .setTitle(R.string.permission_rationale_title)
            .setMessage(R.string.permission_rationale_message)
            .setPositiveButton(R.string.permission_rationale_ok) { _, _ -> requestPermission() }
            .setNegativeButton(R.string.permission_rationale_cancel, null)
            .show()
    }

    private fun requestPermission() {
        // Erklärung des Zwecks vor der Systemabfrage beim allerersten Start.
        if (!hasAskedBefore()) {
            markAsked()
            AlertDialog.Builder(this)
                .setTitle(R.string.permission_rationale_title)
                .setMessage(R.string.permission_rationale_message)
                .setPositiveButton(R.string.permission_rationale_ok) { _, _ ->
                    permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                }
                .setNegativeButton(R.string.permission_rationale_cancel, null)
                .show()
        } else {
            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    private fun hasAskedBefore() =
        getPreferences(MODE_PRIVATE).getBoolean(KEY_ASKED, false)

    private fun markAsked() =
        getPreferences(MODE_PRIVATE).edit().putBoolean(KEY_ASKED, true).apply()

    private fun startMeasuring() {
        hideError()
        meter.start()
        binding.toggleButton.setText(R.string.action_stop)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun updateUiForStopped() {
        binding.toggleButton.setText(R.string.action_start)
        binding.dbText.setText(R.string.db_placeholder)
        binding.levelBar.setLevel(LevelBarView.MIN_DB)
        applyState(State.IDLE)
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun onLevel(db: Float) {
        binding.dbText.text = db.roundToInt().toString()
        binding.levelBar.setLevel(db)

        val state = when (SoundLevel.classify(db, settings.yellowThreshold, settings.redThreshold)) {
            SoundLevel.Level.RED -> State.RED
            SoundLevel.Level.YELLOW -> State.YELLOW
            SoundLevel.Level.GREEN -> State.GREEN
        }
        applyState(state)
    }

    // --- Darstellung -----------------------------------------------------

    private enum class State(val bgColorRes: Int, val statusRes: Int, val lightText: Boolean) {
        IDLE(R.color.state_idle, R.string.status_idle, true),
        GREEN(R.color.state_green, R.string.status_quiet, true),
        YELLOW(R.color.state_yellow, R.string.status_elevated, false),
        RED(R.color.state_red, R.string.status_loud, true)
    }

    private var currentState: State? = null

    private fun applyState(state: State) {
        if (currentState == state) return
        currentState = state

        val background = ContextCompat.getColor(this, state.bgColorRes)
        binding.root.setBackgroundColor(background)
        window.statusBarColor = background
        binding.statusText.setText(state.statusRes)

        val textColor = if (state.lightText) {
            ContextCompat.getColor(this, R.color.on_dark)
        } else {
            ContextCompat.getColor(this, R.color.on_light)
        }
        applyTextColor(textColor)
        binding.levelBar.setFillColor(
            if (state.lightText) Color.WHITE else ContextCompat.getColor(this, R.color.on_light)
        )
    }

    private fun applyTextColor(color: Int) {
        binding.titleText.setTextColor(color)
        binding.dbText.setTextColor(color)
        binding.unitText.setTextColor(color)
        binding.statusText.setTextColor(color)
        binding.scaleText.setTextColor(color)
        binding.errorText.setTextColor(color)
    }

    private fun showError(message: String) {
        binding.errorText.text = message
        binding.errorText.visibility = View.VISIBLE
    }

    private fun showPermissionError() {
        showError(getString(R.string.error_permission_denied))
        binding.permissionSettingsButton.visibility = View.VISIBLE
        updateUiForStopped()
    }

    private fun hideError() {
        binding.errorText.visibility = View.GONE
        binding.permissionSettingsButton.visibility = View.GONE
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", packageName, null)
        }
        startActivity(intent)
    }

    // --- Einstellungen ---------------------------------------------------

    private fun toggleSettingsPanel() {
        val visible = binding.settingsPanel.visibility == View.VISIBLE
        binding.settingsPanel.visibility = if (visible) View.GONE else View.VISIBLE
        binding.settingsToggle.setText(
            if (visible) R.string.action_show_settings else R.string.action_hide_settings
        )
    }

    private fun setupSettingsInputs() {
        binding.yellowInput.onValueChanged { value ->
            settings.yellowThreshold = value
            afterThresholdChange()
        }
        binding.redInput.onValueChanged { value ->
            settings.redThreshold = value
            afterThresholdChange()
        }
        binding.offsetInput.onValueChanged { value ->
            settings.calibrationOffset = value
        }
    }

    /** Änderungen wirken sofort auf eine laufende Messung – kein Neustart nötig. */
    private fun afterThresholdChange() {
        binding.levelBar.setThresholds(settings.yellowThreshold, settings.redThreshold)
        if (settings.redThreshold <= settings.yellowThreshold) {
            showError(getString(R.string.error_invalid_thresholds))
        } else if (binding.errorText.text == getString(R.string.error_invalid_thresholds)) {
            hideError()
        }
        currentState = null // Farbe beim nächsten Messwert neu bewerten
    }

    private fun loadSettingsIntoInputs() {
        suppressWatchers = true
        binding.yellowInput.setText(format(settings.yellowThreshold))
        binding.redInput.setText(format(settings.redThreshold))
        binding.offsetInput.setText(format(settings.calibrationOffset))
        suppressWatchers = false
    }

    private fun resetDefaults() {
        settings.yellowThreshold = AmpelSettings.DEFAULT_YELLOW
        settings.redThreshold = AmpelSettings.DEFAULT_RED
        settings.calibrationOffset = AmpelSettings.DEFAULT_OFFSET
        loadSettingsIntoInputs()
        afterThresholdChange()
    }

    private fun format(value: Float): String =
        if (value == value.roundToInt().toFloat()) value.roundToInt().toString() else value.toString()

    private fun EditText.onValueChanged(onValue: (Float) -> Unit) {
        addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit
            override fun afterTextChanged(s: Editable?) {
                if (suppressWatchers) return
                val value = s?.toString()?.replace(',', '.')?.toFloatOrNull() ?: return
                onValue(value)
            }
        })
    }

    companion object {
        private const val KEY_ASKED = "permission_asked"
    }
}
