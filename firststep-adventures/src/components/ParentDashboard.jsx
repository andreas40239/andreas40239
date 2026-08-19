import { useState } from "react";
import { useProgress } from "../lib/ProgressContext";

const MODULE_LABELS = {
  soundMatch: "Laute erkennen (Buchstaben)",
  counting: "Zählen (Zahlen)",
  addition: "Plus rechnen (Zahlen)",
  subtraction: "Minus rechnen einbeziehen",
};

export default function ParentDashboard({ onExit }) {
  const { progress, updateSettings, resetProgress } = useProgress();
  const { settings } = progress;
  const [confirmingReset, setConfirmingReset] = useState(false);

  const toggleModule = (key) => {
    updateSettings({ modules: { [key]: !settings.modules[key] } });
  };

  return (
    <div className="screen parent-dashboard">
      <button type="button" className="back-button" onClick={onExit} aria-label="Zurück zur App">
        ⬅️
      </button>
      <h2>Eltern-Dashboard</h2>

      <section className="parent-dashboard__section">
        <h3>Fortschritt</h3>
        <p>
          Gemeisterte Buchstaben ({progress.masteredLetters.length}):{" "}
          {progress.masteredLetters.length ? progress.masteredLetters.join(", ") : "noch keine"}
        </p>
        <p>
          Gemeisterte Rechenaufgaben ({progress.masteredFacts.length}):{" "}
          {progress.masteredFacts.length ? progress.masteredFacts.join(", ") : "noch keine"}
        </p>
        <p>Gesammelte Sticker: {progress.stickers.length}</p>
      </section>

      <section className="parent-dashboard__section">
        <h3>Module an/aus</h3>
        {Object.entries(MODULE_LABELS).map(([key, label]) => (
          <label key={key} className="parent-dashboard__toggle">
            <input type="checkbox" checked={settings.modules[key] !== false} onChange={() => toggleModule(key)} />
            {label}
          </label>
        ))}
      </section>

      <section className="parent-dashboard__section">
        <h3>Bildschirmzeit-Begrenzer</h3>
        <label className="parent-dashboard__toggle">
          <input
            type="checkbox"
            checked={settings.screenTimeEnabled}
            onChange={() => updateSettings({ screenTimeEnabled: !settings.screenTimeEnabled })}
          />
          Aktiviert
        </label>
        <label className="parent-dashboard__slider">
          {settings.screenTimeMinutes} Minuten
          <input
            type="range"
            min="5"
            max="60"
            step="5"
            value={settings.screenTimeMinutes}
            onChange={(e) => updateSettings({ screenTimeMinutes: Number(e.target.value) })}
            disabled={!settings.screenTimeEnabled}
          />
        </label>
      </section>

      <section className="parent-dashboard__section">
        <h3>Anzeige</h3>
        <label className="parent-dashboard__toggle">
          <input
            type="checkbox"
            checked={settings.highContrast}
            onChange={() => updateSettings({ highContrast: !settings.highContrast })}
          />
          Kontrastreicher Modus (spart Akku, besser bei hellem Licht)
        </label>
      </section>

      <section className="parent-dashboard__section">
        <h3>Fortschritt zurücksetzen</h3>
        {confirmingReset ? (
          <div className="parent-dashboard__confirm">
            <p>Wirklich allen Fortschritt löschen?</p>
            <button
              type="button"
              className="parent-dashboard__danger"
              onClick={() => {
                resetProgress();
                setConfirmingReset(false);
              }}
            >
              Ja, zurücksetzen
            </button>
            <button type="button" onClick={() => setConfirmingReset(false)}>
              Abbrechen
            </button>
          </div>
        ) : (
          <button type="button" className="parent-dashboard__danger" onClick={() => setConfirmingReset(true)}>
            Zurücksetzen
          </button>
        )}
      </section>
    </div>
  );
}
