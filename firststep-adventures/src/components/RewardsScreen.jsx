import { useEffect } from "react";
import Mascot from "./Mascot";
import { speak, vibrate } from "../lib/speech";
import { useProgress } from "../lib/ProgressContext";

const HAT_UNLOCKS = [
  { id: "none", label: "Kein Hut", needsStickers: 0 },
  { id: "cap", label: "Mütze", needsStickers: 3 },
  { id: "party", label: "Partyhut", needsStickers: 6 },
  { id: "crown", label: "Krone", needsStickers: 10 },
];

const GLASSES_UNLOCKS = [
  { id: "none", label: "Keine Brille", needsStickers: 0 },
  { id: "cool", label: "Coole Brille", needsStickers: 4 },
  { id: "nerd", label: "Schlaue Brille", needsStickers: 8 },
];

export default function RewardsScreen({ onBack }) {
  const { progress, unlockMascotItem } = useProgress();
  const stickerCount = progress.stickers.length;

  useEffect(() => {
    speak(
      stickerCount === 0
        ? "Du hast noch keine Sticker. Spiele ein Spiel, um welche zu sammeln!"
        : `Du hast ${stickerCount} Sticker gesammelt. Toll gemacht!`
    );
  }, [stickerCount]);

  const pick = (slot, id) => {
    vibrate(15);
    speak("Ausgewählt!");
    unlockMascotItem(slot, id === "none" ? null : id);
  };

  return (
    <div className="screen rewards-screen">
      <button type="button" className="back-button" onClick={onBack} aria-label="Zurück">
        ⬅️
      </button>
      <h2 className="hub-screen__title">🏅 Meine Belohnungen</h2>

      <Mascot mood="idle" size={90} />

      <section className="rewards-screen__section">
        <h3>Sticker-Buch ({stickerCount})</h3>
        {stickerCount === 0 ? (
          <p className="rewards-screen__empty">Noch keine Sticker – spiel los und sammle welche! ✨</p>
        ) : (
          <div className="sticker-grid">
            {progress.stickers.map((sticker) => (
              <div key={sticker.id} className="sticker" title={sticker.label}>
                {sticker.emoji}
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="rewards-screen__section">
        <h3>Hüte für den Fuchs</h3>
        <div className="unlock-row">
          {HAT_UNLOCKS.map((item) => {
            const unlocked = stickerCount >= item.needsStickers;
            return (
              <button
                key={item.id}
                type="button"
                className={`unlock-chip ${unlocked ? "" : "unlock-chip--locked"}`}
                disabled={!unlocked}
                onClick={() => pick("hat", item.id)}
              >
                {unlocked ? item.label : `🔒 ${item.needsStickers} Sticker`}
              </button>
            );
          })}
        </div>
      </section>

      <section className="rewards-screen__section">
        <h3>Brillen für den Fuchs</h3>
        <div className="unlock-row">
          {GLASSES_UNLOCKS.map((item) => {
            const unlocked = stickerCount >= item.needsStickers;
            return (
              <button
                key={item.id}
                type="button"
                className={`unlock-chip ${unlocked ? "" : "unlock-chip--locked"}`}
                disabled={!unlocked}
                onClick={() => pick("glasses", item.id)}
              >
                {unlocked ? item.label : `🔒 ${item.needsStickers} Sticker`}
              </button>
            );
          })}
        </div>
      </section>
    </div>
  );
}
