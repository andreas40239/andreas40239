import { useEffect, useState } from "react";
import SoundMatchGame from "./SoundMatchGame";
import { speak } from "../../lib/speech";
import { useProgress } from "../../lib/ProgressContext";

const GAMES = [
  { id: "soundMatch", label: "Laute erkennen", emoji: "👂", ready: true, moduleKey: "soundMatch" },
  { id: "tracing", label: "Buchstaben schreiben", emoji: "✍️", ready: false },
  { id: "sightWords", label: "Sichtwörter bauen", emoji: "🧩", ready: false },
  { id: "pictureWord", label: "Bild & Wort", emoji: "🖼️", ready: false },
];

export default function LettersHub({ onBack }) {
  const { progress } = useProgress();
  const [activeGame, setActiveGame] = useState(null);

  useEffect(() => {
    if (!activeGame) speak("Buchstaben. Wähle ein Spiel.");
  }, [activeGame]);

  if (activeGame === "soundMatch") {
    return <SoundMatchGame onBack={() => setActiveGame(null)} />;
  }

  return (
    <div className="screen hub-screen">
      <button type="button" className="back-button" onClick={onBack} aria-label="Zurück">
        ⬅️
      </button>
      <h2 className="hub-screen__title">🔤 Buchstaben</h2>
      <div className="hub-screen__grid">
        {GAMES.map((game) => {
          const enabledByParent = !game.moduleKey || progress.settings.modules[game.moduleKey] !== false;
          const playable = game.ready && enabledByParent;
          return (
            <button
              key={game.id}
              type="button"
              className={`game-card ${playable ? "" : "game-card--locked"}`}
              onClick={() => {
                if (!game.ready) {
                  speak("Dieses Spiel kommt bald!");
                  return;
                }
                if (!enabledByParent) {
                  speak("Dieses Spiel ist gerade ausgeschaltet.");
                  return;
                }
                speak(game.label);
                setActiveGame(game.id);
              }}
            >
              <span className="game-card__emoji">{game.emoji}</span>
              <span className="game-card__label">{game.label}</span>
              {!game.ready && <span className="game-card__badge">Bald verfügbar</span>}
              {game.ready && !enabledByParent && <span className="game-card__badge">Ausgeschaltet</span>}
            </button>
          );
        })}
      </div>
    </div>
  );
}
