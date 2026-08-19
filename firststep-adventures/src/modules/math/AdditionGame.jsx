import { useEffect, useState } from "react";
import Mascot from "../../components/Mascot";
import Confetti from "../../components/Confetti";
import { speak, vibrate } from "../../lib/speech";
import { useProgress } from "../../lib/ProgressContext";
import { randomAdditionRound } from "./mathData";

const PRAISE = ["Super gerechnet!", "Klasse gemacht!", "Du bist ein Rechenprofi!"];
const ENCOURAGEMENT = ["Fast! Zähl noch einmal alle Äpfel.", "Kein Problem, versuch es noch einmal."];

export default function AdditionGame({ onBack }) {
  const { progress, masterFact, awardSticker } = useProgress();
  const allowSubtraction = progress.settings.modules.subtraction;
  const [round, setRound] = useState(() => randomAdditionRound({ allowSubtraction }));
  const [celebrating, setCelebrating] = useState(false);
  const [roundsWon, setRoundsWon] = useState(0);

  const speakPrompt = (r = round) => {
    if (r.operation === "addition") {
      speak(`Du hast ${r.a} Äpfel. Ich gebe dir ${r.b} mehr. Wie viele Äpfel hast du jetzt?`);
    } else {
      speak(`Du hast ${r.a} Äpfel. Du gibst ${r.b} weg. Wie viele Äpfel hast du jetzt?`);
    }
  };

  useEffect(() => {
    const t = setTimeout(() => speakPrompt(round), 400);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [round]);

  const handleChoice = (value) => {
    if (celebrating) return;
    if (value === round.result) {
      vibrate([15, 40, 15]);
      speak(PRAISE[Math.floor(Math.random() * PRAISE.length)]);
      setCelebrating(true);
      masterFact(round.factKey);
      const nextWon = roundsWon + 1;
      setRoundsWon(nextWon);
      if (nextWon % 3 === 0) awardSticker("Rechenprofi");
      setTimeout(() => {
        setCelebrating(false);
        setRound(randomAdditionRound({ allowSubtraction }));
      }, 1800);
    } else {
      vibrate(10);
      speak(ENCOURAGEMENT[Math.floor(Math.random() * ENCOURAGEMENT.length)]);
    }
  };

  return (
    <div className="screen game-screen">
      <button type="button" className="back-button" onClick={onBack} aria-label="Zurück">
        ⬅️
      </button>
      <h2 className="game-screen__title">{round.operation === "addition" ? "Plus rechnen" : "Minus rechnen"}</h2>

      <div className="game-screen__stage">
        <Mascot mood={celebrating ? "dance" : "idle"} size={80} />
        {celebrating && <Confetti />}
      </div>

      <div className="math-visual">
        <span className="math-visual__group">{round.emoji.repeat(round.a)}</span>
        <span className="math-visual__operator">{round.operation === "addition" ? "+" : "−"}</span>
        <span className="math-visual__group">{round.emoji.repeat(round.b)}</span>
        <span className="math-visual__operator">=</span>
        <span className="math-visual__question">?</span>
      </div>

      <button type="button" className="replay-button" onClick={() => speakPrompt()}>
        🔊 Nochmal hören
      </button>

      <div className="choice-row">
        {round.choices.map((choice) => (
          <button
            key={choice}
            type="button"
            className="letter-choice"
            onClick={() => handleChoice(choice)}
            disabled={celebrating}
          >
            {choice}
          </button>
        ))}
      </div>
    </div>
  );
}
