import { useEffect, useState } from "react";
import CountingGame from "./CountingGame";
import AdditionGame from "./AdditionGame";
import { speak } from "../../lib/speech";
import { useProgress } from "../../lib/ProgressContext";

export default function NumbersHub({ onBack }) {
  const { progress } = useProgress();
  const [activeGame, setActiveGame] = useState(null);

  const games = [
    { id: "counting", label: "Zählen", emoji: "🐸", ready: true, moduleKey: "counting" },
    { id: "addition", label: "Plus & Minus rechnen", emoji: "➕", ready: true, moduleKey: "addition" },
    { id: "patterns", label: "Formen & Muster", emoji: "🔺", ready: false },
    { id: "tenFrame", label: "Zehnerfeld", emoji: "🔟", ready: false },
  ];

  useEffect(() => {
    if (!activeGame) speak("Zahlen. Wähle ein Spiel.");
  }, [activeGame]);

  if (activeGame === "counting") return <CountingGame onBack={() => setActiveGame(null)} />;
  if (activeGame === "addition") return <AdditionGame onBack={() => setActiveGame(null)} />;

  return (
    <div className="screen hub-screen">
      <button type="button" className="back-button" onClick={onBack} aria-label="Zurück">
        ⬅️
      </button>
      <h2 className="hub-screen__title">🔢 Zahlen</h2>
      <div className="hub-screen__grid">
        {games.map((game) => {
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
              <span className="game-card__label">
                {game.id === "addition" && !progress.settings.modules.subtraction ? "Plus rechnen" : game.label}
              </span>
              {!game.ready && <span className="game-card__badge">Bald verfügbar</span>}
              {game.ready && !enabledByParent && <span className="game-card__badge">Ausgeschaltet</span>}
            </button>
          );
        })}
      </div>
    </div>
  );
}
