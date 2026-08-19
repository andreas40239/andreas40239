import { useEffect, useState } from "react";
import Mascot from "../../components/Mascot";
import Confetti from "../../components/Confetti";
import { speak, vibrate } from "../../lib/speech";
import { useProgress } from "../../lib/ProgressContext";
import { randomCountingRound } from "./mathData";

const NUMBER_WORDS = ["null", "eins", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun", "zehn"];

export default function CountingGame({ onBack }) {
  const { awardSticker } = useProgress();
  const [round, setRound] = useState(randomCountingRound);
  const [tapped, setTapped] = useState(() => new Set());
  const [celebrating, setCelebrating] = useState(false);
  const [roundsWon, setRoundsWon] = useState(0);

  useEffect(() => {
    const t = setTimeout(() => speak("Tippe auf jedes Bild und zähle mit."), 400);
    return () => clearTimeout(t);
  }, [round]);

  const handleTap = (index) => {
    if (celebrating || tapped.has(index)) return;
    const next = new Set(tapped);
    next.add(index);
    setTapped(next);
    vibrate(15);
    speak(NUMBER_WORDS[next.size] ?? String(next.size));

    if (next.size === round.total) {
      setCelebrating(true);
      setTimeout(() => speak(`Genau, ${round.total}! Super gezählt!`), 500);
      const nextWon = roundsWon + 1;
      setRoundsWon(nextWon);
      if (nextWon % 3 === 0) awardSticker("Zählmeister");
      setTimeout(() => {
        setCelebrating(false);
        setTapped(new Set());
        setRound(randomCountingRound());
      }, 2200);
    }
  };

  return (
    <div className="screen game-screen">
      <button type="button" className="back-button" onClick={onBack} aria-label="Zurück">
        ⬅️
      </button>
      <h2 className="game-screen__title">Zählen</h2>

      <div className="game-screen__stage">
        <Mascot mood={celebrating ? "dance" : "idle"} size={80} />
        {celebrating && <Confetti />}
      </div>

      <div className="counting-grid">
        {Array.from({ length: round.total }, (_, i) => (
          <button
            key={i}
            type="button"
            className={`counting-item ${tapped.has(i) ? "counting-item--tapped" : ""}`}
            onClick={() => handleTap(i)}
            disabled={celebrating}
          >
            {round.emoji}
          </button>
        ))}
      </div>

      <p className="game-screen__hint">
        Getippt: {tapped.size} / {round.total}
      </p>
    </div>
  );
}
